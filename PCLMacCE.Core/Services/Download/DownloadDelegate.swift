//
//  DownloadDelegate.swift
//  PCLMacCE
//

import Foundation

public class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    public static let shared: DownloadDelegate = .init()
    public static let queue: OperationQueue = {
        let queue: OperationQueue = OperationQueue()
        queue.name = "PCLMacCE.DownloadDelegate"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    public class DownloadContext {
        public let destination: URL
        /// 分段文件（`<目标路径>.download`）：断点续传的已下载部分。
        public let partURL: URL
        /// 本次请求续传的起始偏移；为 0 表示从零开始完整下载。
        public let resumeOffset: Int64
        public let progressHandler: (@MainActor (Double) -> Void)?
        public var continuation: CheckedContinuation<Void, Error>?

        fileprivate init(
            destination: URL,
            resumeOffset: Int64,
            progressHandler: (@MainActor (Double) -> Void)?
        ) {
            self.destination = destination
            self.partURL = destination.appendingPathExtension("download")
            self.resumeOffset = resumeOffset
            self.progressHandler = progressHandler
        }
    }

    private var contexts: [Int: DownloadContext] = [:]

    public func start(
        _ task: URLSessionDownloadTask,
        destination: URL,
        resumeOffset: Int64 = 0,
        progressHandler: (@MainActor (Double) -> Void)?
    ) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Self.queue.addOperation {
                    let context: DownloadContext = .init(
                        destination: destination,
                        resumeOffset: resumeOffset,
                        progressHandler: progressHandler
                    )
                    context.continuation = continuation
                    self.contexts[task.taskIdentifier] = context
                    task.resume()
                }
            }
        } onCancel: {
            // 直接取消即可：已完成的分段文件保留在磁盘上，供下次续传
            task.cancel()
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let context: DownloadContext = contexts[downloadTask.taskIdentifier] else {
            return
        }

        guard let response = downloadTask.response.flatMap({ $0 as? HTTPURLResponse }) else {
            resume(
                task: downloadTask,
                with: .failure(ResponseError(.invalidType, url: downloadTask.originalRequest?.url, response: downloadTask.response))
            )
            return
        }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 416 {
                // 分段文件与服务器内容不一致（如镜像已更新）：作废分段，从头下载
                try? FileManager.default.removeItem(at: context.partURL)
            }
            if let url = downloadTask.originalRequest?.url {
                if let currentURL = downloadTask.currentRequest?.url, currentURL != url {
                    warn("\(currentURL) (\(url)) 返回了 \(response.statusCode)")
                } else {
                    warn("\(url) 返回了 \(response.statusCode)")
                }
            }
            resume(task: downloadTask, with: .failure(DownloadError.badStatusCode(code: response.statusCode)))
            return
        }
        do {
            if response.statusCode == 206 {
                // 服务器支持断点续传：把本次响应内容追加到分段文件末尾
                try Self.appendContents(of: location, to: context.partURL)
                try FileManager.default.moveItem(at: context.partURL, to: context.destination)
            } else {
                // 服务器不支持 Range（返回 200 完整内容）：直接替换目标，废弃旧分段
                if FileManager.default.fileExists(atPath: context.partURL.path) {
                    try FileManager.default.removeItem(at: context.partURL)
                }
                try FileManager.default.moveItem(at: location, to: context.destination)
            }
        } catch {
            resume(task: downloadTask, with: .failure(error))
            return
        }
        updateProgress(for: downloadTask, with: 1)
        resume(task: downloadTask, with: .success(()))
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        resume(task: task, with: .failure(error ?? DownloadError.unknownError))
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        DispatchQueue.main.async {
            DownloadSpeedManager.shared.addBytes(bytesWritten)
        }
        if let context = contexts[downloadTask.taskIdentifier], totalBytesExpectedToWrite > 0 {
            // 206 响应的 total 是“剩余量”，叠加起始偏移才是整体进度
            let offset: Int64 = context.resumeOffset
            let progress: Double = Double(offset + totalBytesWritten) / Double(offset + totalBytesExpectedToWrite)
            updateProgress(for: downloadTask, with: progress)
        }
    }

    private func resume(task: URLSessionTask, with value: Result<Void, Error>) {
        if let context = contexts[task.taskIdentifier] {
            context.continuation?.resume(with: value)
            context.continuation = nil
            contexts.removeValue(forKey: task.taskIdentifier)
        }
    }

    private func updateProgress(for task: URLSessionTask, with progress: Double) {
        if let context = contexts[task.taskIdentifier], let progressHandler = context.progressHandler {
            DispatchQueue.main.async {
                progressHandler(progress)
            }
        }
    }

    /// 以 4MB 为块把一个文件的内容追加到另一个文件末尾，避免大文件整体读入内存。
    private static func appendContents(of source: URL, to destination: URL) throws {
        let input: FileHandle = try .init(forReadingFrom: source)
        defer { try? input.close() }
        if !FileManager.default.createFile(atPath: destination.path, contents: nil) {
            throw CocoaError(.fileWriteUnknown, userInfo: [
                NSFilePathErrorKey: destination.path
            ])
        }
        let output: FileHandle = try .init(forWritingTo: destination)
        defer { try? output.close() }
        while try autoreleasepool(invoking: {
            guard let chunk: Data = try input.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty else {
                return false
            }
            try output.write(contentsOf: chunk)
            return true
        }) { }
    }

    private override init() {
        super.init()
    }
}
