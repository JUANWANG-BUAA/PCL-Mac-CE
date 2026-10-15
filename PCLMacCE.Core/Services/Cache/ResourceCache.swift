//
//  ResourceCache.swift
//  PCLMacCE
//

import Foundation

public class ResourceCache {
    public static var shared: ResourceCache!

    private let cacheFileURL: URL
    private let iconCacheDirectory: URL
    private var cacheMap: [String: Resource]
    private let cacheLock = NSLock()

    public init(cacheDirectory: URL) {
        self.cacheFileURL = cacheDirectory.appending(path: "resource_cache.json")
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
        cacheLock.unlock()
        let data = try JSONEncoder.shared.encode(snapshot)
        try data.write(to: cacheFileURL, options: .atomic)
    }

    private func url(of globalHash: String) -> URL {
        return iconCacheDirectory.appending(path: "\(globalHash.prefix(2))/\(globalHash)")
    }

    private func globalHash(of path: String, with fileHash: String) -> String {
        return (fileHash + path).sha1
    }
}
