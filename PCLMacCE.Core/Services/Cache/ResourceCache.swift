//
//  ResourceCache.swift
//  PCLMacCE
//

import Foundation

public class ResourceCache {
    public static var shared: ResourceCache!

    private let cacheFileURL: URL
    private let fileHashCacheURL: URL
    private let iconCacheDirectory: URL
    private var cacheMap: [String: Resource]
    private var fileHashMap: [String: FileHashRecord]
    private let cacheLock = NSLock()

    private struct FileHashRecord: Codable, Equatable {
        let fileSize: Int64
        let modificationTime: Double
        let resourceIdentifier: String?
        let sha1: String

        func matches(_ state: FileState) -> Bool {
            return fileSize == state.fileSize
                && modificationTime == state.modificationTime
                && resourceIdentifier == state.resourceIdentifier
        }
    }

    private struct FileState: Equatable {
        let fileSize: Int64
        let modificationTime: Double
        let resourceIdentifier: String?
    }

    public init(cacheDirectory: URL) {
        self.cacheFileURL = cacheDirectory.appending(path: "resource_cache.json")
        self.fileHashCacheURL = cacheDirectory.appending(path: "resource_file_hashes.json")
        self.iconCacheDirectory = cacheDirectory.appending(path: "resource_icon")

        if FileManager.default.fileExists(atPath: cacheFileURL.path) {
            do {
                let data = try Data(contentsOf: cacheFileURL)
                self.cacheMap = try JSONDecoder.shared.decode([String: Resource].self, from: data)
            } catch {
                err("缓存文件加载失败：\(error.localizedDescription)")
                try? FileManager.default.removeItem(at: cacheFileURL)
                self.cacheMap = [:]
            }
        } else {
            self.cacheMap = [:]
        }

        if let data = try? Data(contentsOf: fileHashCacheURL),
           let decoded = try? JSONDecoder.shared.decode([String: FileHashRecord].self, from: data) {
            self.fileHashMap = decoded.filter { FileManager.default.fileExists(atPath: $0.key) }
        } else {
            self.fileHashMap = [:]
        }
    }

    public func resource(forHash hash: String) -> Resource? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cacheMap[hash]
    }

    public func store(_ resource: Resource, forHash hash: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        cacheMap[hash] = resource
    }

    /// 按文件号、大小和修改时间复用 SHA-1，避免每次扫描都读取完整文件。
    /// 系统属性完全未变的原位篡改无法检测；该缓存只用于资源展示索引，不用于下载完整性校验。
    public func sha1(for fileURL: URL, compute: () throws -> String) throws -> String {
        let path: String = fileURL.standardizedFileURL.path
        guard let initialState = Self.fileState(at: fileURL) else {
            return try compute()
        }

        cacheLock.lock()
        let cachedRecord: FileHashRecord? = fileHashMap[path]
        cacheLock.unlock()
        if let cachedRecord, cachedRecord.matches(initialState) {
            return cachedRecord.sha1
        }

        let sha1: String = try compute()
        guard let finalState = Self.fileState(at: fileURL), finalState == initialState else {
            return sha1
        }

        let record: FileHashRecord = .init(
            fileSize: finalState.fileSize,
            modificationTime: finalState.modificationTime,
            resourceIdentifier: finalState.resourceIdentifier,
            sha1: sha1
        )
        cacheLock.lock()
        fileHashMap[path] = record
        cacheLock.unlock()
        return sha1
    }

    public func icon(forHash globalHash: String) throws -> Data? {
        let url = url(of: globalHash)
        if FileManager.default.fileExists(atPath: url.path) {
            return try Data(contentsOf: url)
        }
        return nil
    }

    public func store(_ iconData: Data, relativePath: String, fileHash: String) throws -> String {
        let globalHash = globalHash(of: relativePath, with: fileHash)
        let url = url(of: globalHash)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try iconData.write(to: url, options: .atomic)
        return globalHash
    }

    public func save() throws {
        try FileManager.default.createDirectory(at: cacheFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        cacheLock.lock()
        let snapshot = cacheMap
        let fileHashSnapshot = fileHashMap
        cacheLock.unlock()
        let data = try JSONEncoder.shared.encode(snapshot)
        try data.write(to: cacheFileURL, options: .atomic)
        let fileHashData: Data = try JSONEncoder.shared.encode(fileHashSnapshot)
        try fileHashData.write(to: fileHashCacheURL, options: .atomic)
    }

    private func url(of globalHash: String) -> URL {
        return iconCacheDirectory.appending(path: "\(globalHash.prefix(2))/\(globalHash)")
    }

    private func globalHash(of path: String, with fileHash: String) -> String {
        return (fileHash + path).sha1
    }

    private static func fileState(at url: URL) -> FileState? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int64,
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return .init(
            fileSize: fileSize,
            modificationTime: modificationDate.timeIntervalSince1970,
            resourceIdentifier: attributes[.systemFileNumber].map { String(describing: $0) }
        )
    }
}
