//
//  FileDownloader.swift
//  PCLMacCE
//

import Foundation

public class FileDownloader {
    private struct BatchOptions {
        let skipped: Int
        let total: Int
        let preferMirror: Bool?
        let maxConcurrency: Int?
        let progressHandler: (@MainActor (Double) -> Void)?
    }

    public static let shared: FileDownloader = {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: DownloadDelegate.shared, delegateQueue: DownloadDelegate.queue)
        let downloader: FileDownloader = .init(session: session, delegate: .shared)
        downloader.verificationCache.load()
        return downloader
    }()

    /// 文件校验缓存：命中（size+mtime 未变）时跳过整文件哈希，显著加快启动前的资源补全。
    public let verificationCache: FileVerificationCache = .init(
        fileURL: URLConstants.cacheURL.appending(path: "file-verification.json")
    )

    private let session: URLSession
    private let delegate: DownloadDelegate
    private let sourceManager: DownloadSourceManager
    private let maxRetryCount: Int = 3
    private static let destinationLocks: DownloadDestinationLockPool = .init()

    public init(
        session: URLSession,
        sourceManager: DownloadSourceManager = .shared,
        delegate: DownloadDelegate = .shared
    ) {
        self.session = session
        self.sourceManager = sourceManager
        self.delegate = delegate
    }

    /// 下载单个文件。
    /// - Parameters:
    ///   - file: 下载项。
    ///   - preferMirror: 是否优先使用镜像源，为 `nil` 时由全局策略决定。
    ///   - progressHandler: 进度回调。
    ///   - checkDestination: 是否检查目标文件已存在且校验通过。
    public func download(
        _ file: DownloadItem,
        preferMirror: Bool? = nil,
        progressHandler: (@MainActor (Double) -> Void)? = nil,
        checkDestination: Bool = true
    ) async throws {
        do {
            try await withDestinationLock(file.destination) {
                try await downloadUnlocked(
                    file,
                    preferMirror: preferMirror,
                    progressHandler: progressHandler,
                    checkDestination: checkDestination
                )
            }
        } catch {
            await flushVerificationCache()
            throw error
        }
        await flushVerificationCache()
    }

    private func downloadUnlocked(
        _ file: DownloadItem,
        preferMirror: Bool?,
        progressHandler: (@MainActor (Double) -> Void)?,
        checkDestination: Bool
    ) async throws {
        try Task.checkCancellation()
        if checkDestination && FileManager.default.fileExists(atPath: file.destination.path) {
            let isValid: Bool = try await checkCachedOffMainActor(file)
            try Task.checkCancellation()
            if isValid {
                debug("文件 \(file.destination.lastPathComponent) 已存在且校验通过，跳过下载")
                await progressHandler?(1)
                return
            } else {
                warn("文件 \(file.destination.lastPathComponent) 已存在但校验未通过")
                try FileManager.default.removeItem(at: file.destination)
            }
        }

        try FileManager.default.createDirectory(at: file.destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let candidates = file.urls.flatMap { sourceManager.orderedCandidates(for: $0, preferMirror: preferMirror) }
        guard !candidates.isEmpty else {
            err("\(file.destination.lastPathComponent) 的候选列表为空")
            throw DownloadError.unknownError
        }

        var lastError: Error?
        for candidate in candidates {
            for retryCount in 0...maxRetryCount {
                try Task.checkCancellation()
                do {
                    try await attemptDownload(file, from: candidate, progressHandler: progressHandler)
                    return
                } catch {
                    if error.isCancellationError { throw error }
                    if case DownloadError.resumeRejected = error {
                        try? FileManager.default.removeItem(at: file.destination.appendingPathExtension("download"))
                        try? FileManager.default.removeItem(
                            at: file.destination.appendingPathExtension("download").appendingPathExtension("source")
                        )
                        lastError = error
                        if retryCount < maxRetryCount { continue }
                        break
                    }
                    // 磁盘满、权限等本地错误：换源和重试都没有意义，直接失败
                    if isNonRetryableLocalError(error) {
                        throw error
                    }
                    lastError = error
                    if shouldSkipCandidate(after: error) {
                        warn("\(candidate.url.lastPathComponent) 下载失败（\(error.localizedDescription)），尝试下一个候选")
                        break
                    }
                    if retryCount < maxRetryCount {
                        let delay: Double = backoffSeconds(for: error, retryCount: retryCount)
                        warn("下载 \(candidate.url.lastPathComponent) 失败: \(error.localizedDescription)，重试 (\(retryCount + 1)/\(maxRetryCount))")
                        try await Task.sleep(seconds: delay)
                    }
                }
            }
            log("候选 \(candidate.url) 已耗尽重试次数，尝试下一个候选")
        }

        throw lastError ?? DownloadError.unknownError
    }

    /// 对单个候选执行一次下载尝试（含断点续传、校验与可执行权限设置）。
    private func attemptDownload(
        _ file: DownloadItem,
        from candidate: DownloadCandidate,
        progressHandler: (@MainActor (Double) -> Void)?
    ) async throws {
        await progressHandler?(0)
        try Task.checkCancellation()

        let partURL: URL = file.destination.appendingPathExtension("download")
        let sourceMarkerURL: URL = partURL.appendingPathExtension("source")
        let candidateURL: String = candidate.url.absoluteString
        var resumeOffset: Int64 = 0
        let savedMetadata: DownloadPartMetadata? = (try? Data(contentsOf: sourceMarkerURL)).flatMap {
            try? JSONDecoder().decode(DownloadPartMetadata.self, from: $0)
        }
        if let attributes = try? FileManager.default.attributesOfItem(atPath: partURL.path),
           let existingBytes = attributes[.size] as? Int64, existingBytes > 0 {
            if savedMetadata?.source == candidateURL {
                resumeOffset = existingBytes
                log("检测到未完成的分段文件，从 \(existingBytes) 字节处断点续传")
            } else {
                // 不同镜像的内容可能不一致，换源后旧分段不可信
                try? FileManager.default.removeItem(at: partURL)
            }
        }
        let partMetadata: DownloadPartMetadata = .init(
            source: candidateURL,
            entityTag: resumeOffset > 0 ? savedMetadata?.entityTag : nil,
            lastModified: resumeOffset > 0 ? savedMetadata?.lastModified : nil
        )
        try JSONEncoder().encode(partMetadata).write(to: sourceMarkerURL, options: .atomic)

        var request = URLRequest(url: candidate.url)
        request.setValue("PCL-Mac/\(Metadata.appVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if resumeOffset > 0 {
            request.setValue("bytes=\(resumeOffset)-", forHTTPHeaderField: "Range")
            if let entityTag = partMetadata.entityTag, !entityTag.hasPrefix("W/") {
                request.setValue(entityTag, forHTTPHeaderField: "If-Range")
            } else if let lastModified = partMetadata.lastModified {
                request.setValue(lastModified, forHTTPHeaderField: "If-Range")
            }
        }
        for (key, value) in candidate.headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }

        log("下载 \(candidate.url) → \(file.destination)")
        let task = session.dataTask(with: request)
        try await delegate.start(
            task,
            destination: file.destination,
            sourceMarkerURL: sourceMarkerURL,
            sourceURL: candidateURL,
            resumeOffset: resumeOffset,
            progressHandler: progressHandler
        )
        try? FileManager.default.removeItem(at: sourceMarkerURL)
        try Task.checkCancellation()

        // 校验
        if let checksums = file.checksums, !checksums.isEmpty {
            guard try await checkCachedOffMainActor(file) else {
                // 校验失败时连同分段文件一起清理，避免损坏的分段被再次续传
                try? FileManager.default.removeItem(at: file.destination)
                try? FileManager.default.removeItem(at: partURL)
                throw DownloadError.checksumMismatch
            }
        }
        if file.executable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.destination.path)
        }
    }

    /// 该错误是否应直接放弃当前候选（换源）而不再重试：
    /// 校验失败与状态码错误通常与镜像源有关，重试同一候选无意义。
    private func shouldSkipCandidate(after error: Error) -> Bool {
        if case DownloadError.checksumMismatch = error { return true }
        if case DownloadError.invalidContentRange = error { return true }
        if case DownloadError.badStatusCode(let code) = error {
            // 429 是限流：等待后重试同一候选通常可以恢复
            return code != 429
        }
        return false
    }

    private func checkCachedOffMainActor(_ file: DownloadItem) async throws -> Bool {
        let cache: FileVerificationCache = verificationCache
        return try await runOnUtilityExecutor {
            try FileUtils.checkCached(file, using: cache)
        }
    }

    private func runOnUtilityExecutor<Value: Sendable>(
        _ operation: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        let task: Task<Value, Error> = Task.detached(priority: .utility, operation: operation)
        return try await withTaskCancellationHandler {
            let value: Value = try await task.value
            try Task.checkCancellation()
            return value
        } onCancel: {
            task.cancel()
        }
    }

    private func flushVerificationCache() async {
        let cache: FileVerificationCache = verificationCache
        await Task.detached(priority: .utility) {
            cache.flush()
        }.value
    }

    /// 同一候选的重试退避间隔；限流使用更长的等待时间。
    private func backoffSeconds(for error: Error, retryCount: Int) -> Double {
        if case DownloadError.badStatusCode(429) = error {
            return Double(retryCount + 1) * 3
        }
        return Double(retryCount + 1) * 0.5
    }

    /// 磁盘满、无权限等本地错误：任何重试都不会成功，应立即反馈给用户。
    private func isNonRetryableLocalError(_ error: Error) -> Bool {
        let nsError: NSError = error as NSError
        guard nsError.domain == NSCocoaErrorDomain else { return false }
        switch nsError.code {
        case CocoaError.fileWriteNoPermission.rawValue,
             CocoaError.fileReadNoPermission.rawValue,
             CocoaError.fileNoSuchFile.rawValue,
             CocoaError.fileWriteFileExists.rawValue,
             640: // NSFileWriteVolumeFull（磁盘满）没有独立的 case
            return true
        default:
            return false
        }
    }

    /// 批量下载文件。
    /// - Parameters:
    ///   - files: 下载项列表。
    ///   - preferMirror: 是否优先使用镜像源，为 `nil` 时由全局策略决定。
    ///   - maxConcurrency: 最大并发数，为 `nil` 时使用当前下载源推荐并发数。
    ///   - progressHandler: 进度回调。
    public func download(
        files: [DownloadItem],
        preferMirror: Bool? = nil,
        maxConcurrency: Int? = nil,
        progressHandler: (@MainActor (Double) -> Void)? = nil
    ) async throws {
        let total = files.count
        let items: [DownloadItem]
        let skipped: Int
        do {
            (items, skipped) = try await prepareBatch(files)
        } catch {
            await flushVerificationCache()
            throw error
        }

        if items.isEmpty {
            await progressHandler?(1.0)
            await flushVerificationCache()
            return
        }

        do {
            try await downloadPreparedItems(items, options: .init(
                skipped: skipped,
                total: total,
                preferMirror: preferMirror,
                maxConcurrency: maxConcurrency,
                progressHandler: progressHandler
            ))
        } catch {
            await flushVerificationCache()
            throw error
        }
        await flushVerificationCache()
    }

    private func downloadPreparedItems(
        _ items: [DownloadItem],
        options: BatchOptions
    ) async throws {
        let progressHandler = await ConcurrentProgressHandler(
            initial: Double(options.skipped) / Double(options.total),
            totalHandler: options.progressHandler ?? { _ in }
        )
        let multiplier = 1.0 / Double(options.total)
        await progressHandler.startCalculate()

        do {
            let concurrency = min(64, max(1, options.maxConcurrency ?? sourceManager.effectiveConcurrency))
            try await withThrowingTaskGroup(of: Void.self) { group in
                var remaining = items.makeIterator()
                for _ in 0..<min(concurrency, items.count) {
                    guard let item = remaining.next() else { break }
                    group.addTask {
                        let handler = await progressHandler.handler(withMultiplier: multiplier)
                        try await self.withDestinationLock(item.destination) {
                            try await self.downloadUnlocked(
                                item,
                                preferMirror: options.preferMirror,
                                progressHandler: handler,
                                checkDestination: true
                            )
                        }
                    }
                }

                while try await group.next() != nil {
                    try Task.checkCancellation()
                    if let item = remaining.next() {
                        group.addTask {
                            let handler = await progressHandler.handler(withMultiplier: multiplier)
                            try await self.withDestinationLock(item.destination) {
                                try await self.downloadUnlocked(
                                    item,
                                    preferMirror: options.preferMirror,
                                    progressHandler: handler,
                                    checkDestination: true
                                )
                            }
                        }
                    }
                }
            }
            try Task.checkCancellation()
            await progressHandler.stopCalculate()
        } catch {
            await progressHandler.cancelCalculate()
            throw error
        }
    }

    public func download(url: URL, destination: URL, sha1: String? = nil, preferMirror: Bool? = nil, progressHandler: (@MainActor (Double) -> Void)? = nil) async throws {
        try await download(.init(url: url, destination: destination, sha1: sha1), preferMirror: preferMirror, progressHandler: progressHandler)
    }

    /// 清理超过指定时长未更新的下载分段文件（`.download` 及其来源标记）。
    /// 断点续传的分段会一直保留到下次成功下载；失败的下载留下的分段靠本方法回收。
    public static func cleanupStalePartFiles(olderThan maxAge: TimeInterval, in roots: [URL]) {
        let cutoff: Date = .now.addingTimeInterval(-maxAge)
        let fileManager = FileManager.default
        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
            ) else { continue }
            for case let url as URL in enumerator {
                let path: String = url.lastPathComponent
                guard path.hasSuffix(".download") || path.hasSuffix(".source") else { continue }
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                      values.isRegularFile == true,
                      let modified = values.contentModificationDate, modified < cutoff else { continue }
                do {
                    try fileManager.removeItem(at: url)
                    log("清理过期下载分段 \(url.lastPathComponent)")
                } catch {
                    warn("清理过期下载分段失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func withDestinationLock(_ destination: URL, operation: () async throws -> Void) async throws {
        let key: String = destination.standardizedFileURL.path
        try await Self.destinationLocks.acquire(key)
        do {
            try await operation()
            await Self.destinationLocks.release(key)
        } catch {
            await Self.destinationLocks.release(key)
            throw error
        }
    }

    private func prepareBatch(_ files: [DownloadItem]) async throws -> ([DownloadItem], Int) {
        let cache: FileVerificationCache = verificationCache
        return try await runOnUtilityExecutor {
            var distinctItems: [DownloadItem] = []
            distinctItems.reserveCapacity(files.count)
            var byDestination: [String: DownloadItem] = [:]
            var skippedCount = 0

            for file in files {
                try Task.checkCancellation()
                let destination: String = file.destination.standardizedFileURL.path
                if let previous = byDestination[destination] {
                    guard previous == file else { throw DownloadError.destinationConflict }
                    skippedCount += 1
                    continue
                }
                byDestination[destination] = file
                if FileManager.default.fileExists(atPath: destination),
                   try FileUtils.checkCached(file, using: cache) {
                    skippedCount += 1
                    continue
                }
                distinctItems.append(file)
            }
            return (distinctItems, skippedCount)
        }
    }
}

/// 串行化相同目标路径的校验、删除、续传和最终替换，避免并发安装互相覆盖。
private actor DownloadDestinationLockPool {
    private struct Entry {
        let semaphore: AsyncSemaphore
        var users: Int
    }

    private var entries: [String: Entry] = [:]

    func acquire(_ key: String) async throws {
        var entry: Entry = entries[key] ?? .init(semaphore: .init(value: 1), users: 0)
        entry.users += 1
        entries[key] = entry
        do {
            try await entry.semaphore.wait()
        } catch {
            removeUser(for: key)
            throw error
        }
    }

    func release(_ key: String) async {
        guard let entry = entries[key] else { return }
        await entry.semaphore.signal()
        removeUser(for: key)
    }

    private func removeUser(for key: String) {
        guard var entry = entries[key] else { return }
        entry.users -= 1
        if entry.users == 0 {
            entries.removeValue(forKey: key)
        } else {
            entries[key] = entry
        }
    }
}
