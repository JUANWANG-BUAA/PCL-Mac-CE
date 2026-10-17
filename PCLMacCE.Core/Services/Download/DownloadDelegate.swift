//
//  DownloadDelegate.swift
//  PCLMacCE
//

import Foundation

struct DownloadPartMetadata: Codable {
    let source: String
    var entityTag: String?
    var lastModified: String?
}

public class DownloadDelegate: NSObject, URLSessionDataDelegate {
    public static let shared: DownloadDelegate = .init()
    public static let queue: OperationQueue = {
        let queue: OperationQueue = OperationQueue()
        queue.name = "PCLMacCE.DownloadDelegate"
        // Delegate callbacks write ordered chunks to disk; keep them serialized.
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    public let delegateQueue: OperationQueue

    public class DownloadContext {
        public let destination: URL
        /// 已下载的分段文件（`<目标路径>.download`），中断后保留以供 Range 续传。
        public let partURL: URL
        fileprivate let sourceMarkerURL: URL
        fileprivate let sourceURL: String
        /// 本次请求续传的起始偏移；为 0 表示从零开始。
        public let resumeOffset: Int64
        public let progressHandler: (@MainActor (Double) -> Void)?
        fileprivate var continuation: CheckedContinuation<Void, Error>?
        fileprivate var fileHandle: FileHandle?
        fileprivate var expectedTotalBytes: Int64?
        fileprivate var expectedResponseBytes: Int64?
        fileprivate var progressOffset: Int64 = 0
        fileprivate var receivedBytes: Int64 = 0
        fileprivate var pendingData: Data = .init()
        fileprivate var lastProgressDate: Date = .distantPast

        fileprivate init(
            destination: URL,
            sourceMarkerURL: URL,
            sourceURL: String,
            resumeOffset: Int64,
            progressHandler: (@MainActor (Double) -> Void)?
        ) {
            self.destination = destination
            self.partURL = destination.appendingPathExtension("download")
            self.sourceMarkerURL = sourceMarkerURL
            self.sourceURL = sourceURL
            self.resumeOffset = resumeOffset
            self.progressHandler = progressHandler
        }
    }

    private var contexts: [Int: DownloadContext] = [:]

    public func start(
        _ task: URLSessionDataTask,
        destination: URL,
        sourceMarkerURL: URL,
        sourceURL: String,
        resumeOffset: Int64 = 0,
        progressHandler: (@MainActor (Double) -> Void)?
    ) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                delegateQueue.addOperation {
                    let context: DownloadContext = .init(
                        destination: destination,
                        sourceMarkerURL: sourceMarkerURL,
                        sourceURL: sourceURL,
                        resumeOffset: resumeOffset,
                        progressHandler: progressHandler
                    )
                    context.continuation = continuation
                    self.contexts[task.taskIdentifier] = context
                    task.resume()
                }
            }
        } onCancel: {
            // 分段内容已经直接落盘，取消后保留文件即可继续通过 Range 下载。
            task.cancel()
        }
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let context = contexts[dataTask.taskIdentifier] else {
            completionHandler(.cancel)
            return
        }
        guard let response = response as? HTTPURLResponse else {
            resume(
                task: dataTask,
                with: .failure(ResponseError(.invalidType, url: dataTask.originalRequest?.url, response: response))
            )
            completionHandler(.cancel)
            return
        }

        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 416, context.resumeOffset > 0 {
                try? FileManager.default.removeItem(at: context.partURL)
                resume(task: dataTask, with: .failure(DownloadError.resumeRejected))
            } else {
                resume(task: dataTask, with: .failure(DownloadError.badStatusCode(code: response.statusCode)))
            }
            completionHandler(.cancel)
            return
        }

        do {
            let effectiveOffset: Int64
            if response.statusCode == 206 {
                guard let contentRange = Self.contentRange(response),
                      contentRange.start == context.resumeOffset else {
                    let rangeStart: Int64? = Self.contentRange(response)?.start
                    warn("Content-Range 起点不匹配：请求偏移 \(context.resumeOffset)，响应起点 \(rangeStart.map(String.init) ?? "缺失")")
                    throw context.resumeOffset > 0 ? DownloadError.resumeRejected : DownloadError.invalidContentRange
                }
                try Self.validateResumeValidator(response, for: context)
                effectiveOffset = context.resumeOffset
                context.expectedResponseBytes = contentRange.end - contentRange.start + 1
                context.expectedTotalBytes = contentRange.total
            } else {
                // 服務器忽略 Range 並返回完整文件時，丟棄舊分段，從頭接收。
                effectiveOffset = 0
                let contentLength: Int64? = response.expectedContentLength >= 0 ? response.expectedContentLength : nil
                context.expectedResponseBytes = contentLength
                context.expectedTotalBytes = contentLength
            }

            try Self.updatePartMetadata(response, for: context)
            context.progressOffset = effectiveOffset
            try Self.openPartFile(for: context, effectiveOffset: effectiveOffset)
            completionHandler(.allow)
        } catch {
            resume(task: dataTask, with: .failure(error))
            completionHandler(.cancel)
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let context = contexts[dataTask.taskIdentifier], context.fileHandle != nil else { return }
        context.pendingData.append(data)
        context.receivedBytes += Int64(data.count)
        DownloadSpeedManager.shared.addBytes(Int64(data.count))
        do {
            if context.pendingData.count >= 256 * 1024 {
                try flushPendingData(for: context)
            }
        } catch {
            resume(task: dataTask, with: .failure(error))
            dataTask.cancel()
            return
        }

        let now: Date = .now
        guard now.timeIntervalSince(context.lastProgressDate) >= 0.1 else { return }
        context.lastProgressDate = now
        if let total = context.expectedTotalBytes, total > 0 {
            let progress: Double = Double(context.progressOffset + context.receivedBytes) / Double(total)
            updateProgress(for: dataTask, with: min(max(progress, 0), 0.999))
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let context = contexts[task.taskIdentifier] else { return }
        if let error {
            resume(task: task, with: .failure(error))
            return
        }

        do {
            try flushPendingData(for: context)
            try context.fileHandle?.close()
            context.fileHandle = nil
            guard context.expectedResponseBytes == nil || context.receivedBytes == context.expectedResponseBytes,
                  context.expectedTotalBytes == nil
                    || context.progressOffset + context.receivedBytes == context.expectedTotalBytes else {
                throw URLError(.networkConnectionLost)
            }
            if FileManager.default.fileExists(atPath: context.destination.path) {
                try FileManager.default.removeItem(at: context.destination)
            }
            try FileManager.default.moveItem(at: context.partURL, to: context.destination)
            updateProgress(for: task, with: 1)
            resume(task: task, with: .success(()))
        } catch {
            resume(task: task, with: .failure(error))
        }
    }

    private func resume(task: URLSessionTask, with value: Result<Void, Error>) {
        guard let context = contexts.removeValue(forKey: task.taskIdentifier) else { return }
        var result: Result<Void, Error> = value
        do {
            try flushPendingData(for: context)
            try context.fileHandle?.close()
        } catch {
            result = .failure(error)
            try? context.fileHandle?.close()
        }
        context.fileHandle = nil
        context.continuation?.resume(with: result)
        context.continuation = nil
    }

    private func flushPendingData(for context: DownloadContext) throws {
        guard !context.pendingData.isEmpty else { return }
        guard let handle = context.fileHandle else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: context.partURL.path])
        }
        try handle.write(contentsOf: context.pendingData)
        context.pendingData.removeAll(keepingCapacity: true)
    }

    private func updateProgress(for task: URLSessionTask, with progress: Double) {
        guard let progressHandler = contexts[task.taskIdentifier]?.progressHandler else { return }
        DispatchQueue.main.async {
            progressHandler(progress)
        }
    }

    private static func openPartFile(for context: DownloadContext, effectiveOffset: Int64) throws {
        let fileManager = FileManager.default
        if effectiveOffset > 0 {
            guard let attributes = try? fileManager.attributesOfItem(atPath: context.partURL.path),
                  let size = attributes[.size] as? Int64,
                  size == effectiveOffset else {
                throw DownloadError.resumeRejected
            }
            let handle: FileHandle = try .init(forWritingTo: context.partURL)
            try handle.seekToEnd()
            context.fileHandle = handle
            return
        }

        if fileManager.fileExists(atPath: context.partURL.path) {
            try fileManager.removeItem(at: context.partURL)
        }
        guard fileManager.createFile(atPath: context.partURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: context.partURL.path])
        }
        context.fileHandle = try .init(forWritingTo: context.partURL)
    }

    private static func contentRange(_ response: HTTPURLResponse) -> (start: Int64, end: Int64, total: Int64?)? {
        guard let value = response.value(forHTTPHeaderField: "Content-Range"),
              let rangeAndUnit = value.split(separator: " ").last,
              let components = Self.split(rangeAndUnit, separator: "/", count: 2),
              let bounds = Self.split(components[0], separator: "-", count: 2),
              let start = Int64(bounds[0]),
              let end = Int64(bounds[1]),
              start <= end else {
            return nil
        }
        let totalValue: Substring = components[1]
        let parsedTotal: Int64? = totalValue == "*" ? nil : Int64(totalValue)
        guard totalValue == "*" || parsedTotal != nil else {
            return nil
        }
        if let parsedTotal, end >= parsedTotal {
            return nil
        }
        return (start, end, parsedTotal)
    }

    private static func split(_ value: Substring, separator: Character, count: Int) -> [Substring]? {
        let components: [Substring] = value.split(separator: separator, omittingEmptySubsequences: false)
        guard components.count == count, components.allSatisfy({ !$0.isEmpty }) else {
            return nil
        }
        return components
    }

    private static func validateResumeValidator(_ response: HTTPURLResponse, for context: DownloadContext) throws {
        guard context.resumeOffset > 0,
              let data = try? Data(contentsOf: context.sourceMarkerURL),
              let metadata = try? JSONDecoder().decode(DownloadPartMetadata.self, from: data) else {
            return
        }
        let responseEntityTag: String? = response.value(forHTTPHeaderField: "ETag")
        let responseLastModified: String? = response.value(forHTTPHeaderField: "Last-Modified")
        if let previous = metadata.entityTag, let current = responseEntityTag, previous != current {
            throw DownloadError.resumeRejected
        }
        if let previous = metadata.lastModified, let current = responseLastModified, previous != current {
            throw DownloadError.resumeRejected
        }
    }

    private static func updatePartMetadata(_ response: HTTPURLResponse, for context: DownloadContext) throws {
        let oldData: Data? = try? Data(contentsOf: context.sourceMarkerURL)
        let oldMetadata: DownloadPartMetadata? = oldData.flatMap {
            try? JSONDecoder().decode(DownloadPartMetadata.self, from: $0)
        }
        let metadata: DownloadPartMetadata = .init(
            source: context.sourceURL,
            entityTag: response.value(forHTTPHeaderField: "ETag") ?? oldMetadata?.entityTag,
            lastModified: response.value(forHTTPHeaderField: "Last-Modified") ?? oldMetadata?.lastModified
        )
        let data: Data = try JSONEncoder().encode(metadata)
        try data.write(to: context.sourceMarkerURL, options: .atomic)
    }

    public override convenience init() {
        self.init(delegateQueue: Self.queue)
    }

    public init(delegateQueue: OperationQueue) {
        self.delegateQueue = delegateQueue
        super.init()
    }
}
