//
//  ResourceHashCacheTests.swift
//  PCLMacCE.Tests
//

import Core
import Foundation
import Testing

struct ResourceHashCacheTests {
    @Test func unchangedFileReusesPersistedHashAndChangedFileRehashes() throws {
        let root: URL = FileManager.default.temporaryDirectory.appending(path: "resource-hash-cache-\(UUID().uuidString)")
        let cacheDirectory: URL = root.appending(path: "cache")
        let fileURL: URL = root.appending(path: "mods/example.jar")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("initial".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: root) }

        var computations: Int = 0
        let firstCache: ResourceCache = .init(cacheDirectory: cacheDirectory)
        let firstHash: String = try firstCache.sha1(for: fileURL) {
            computations += 1
            return "sha1-initial"
        }
        let repeatedHash: String = try firstCache.sha1(for: fileURL) {
            computations += 1
            return "unexpected-rehash"
        }
        #expect(firstHash == "sha1-initial")
        #expect(repeatedHash == firstHash)
        #expect(computations == 1)

        try firstCache.save()
        let reloadedCache: ResourceCache = .init(cacheDirectory: cacheDirectory)
        let persistedHash: String = try reloadedCache.sha1(for: fileURL) {
            computations += 1
            return "unexpected-rehash-after-reload"
        }
        #expect(persistedHash == firstHash)
        #expect(computations == 1)

        try Data("changed-file-with-different-size".utf8).write(to: fileURL)
        let changedHash: String = try reloadedCache.sha1(for: fileURL) {
            computations += 1
            return "sha1-changed"
        }
        #expect(changedHash == "sha1-changed")
        #expect(computations == 2)
    }
}
