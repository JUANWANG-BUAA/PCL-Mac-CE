//
//  FileVerificationCacheTests.swift
//  PCLMacCE.Tests
//

import Foundation
import Testing
import Core
import CryptoKit

struct FileVerificationCacheTests {
    @Test func skipsUnchangedAndRechecksChangedFiles() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "file-verify-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file: URL = directory.appending(path: "a.bin")
        try Data("hello".utf8).write(to: file)
        let cacheURL: URL = directory.appending(path: "cache.json")
        let checksums: [String: String] = ["sha1": try FileUtils.sha1(of: file)]

        let cache: FileVerificationCache = .init(fileURL: cacheURL)
        cache.load()
        // 未记录过的文件不视为已验证
        #expect(!cache.isVerified(file, checksums: checksums))
        cache.markVerified(file, checksums: checksums)
        #expect(cache.isVerified(file, checksums: checksums))
        cache.flush()

        // 模拟重启：重新加载后仍然命中
        let reloaded: FileVerificationCache = .init(fileURL: cacheURL)
        reloaded.load()
        #expect(reloaded.isVerified(file, checksums: checksums))

        // 文件被修改（mtime 变化）后缓存失效
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(5)],
            ofItemAtPath: file.path
        )
        #expect(!reloaded.isVerified(file, checksums: checksums))

        // 文件删除后失效；加载阶段会清理不存在文件的条目
        try FileManager.default.removeItem(at: file)
        #expect(!reloaded.isVerified(file, checksums: checksums))
        reloaded.markVerified(directory.appending(path: "missing.bin"), checksums: checksums) // 不应产生记录
        reloaded.flush()
        let pruned: FileVerificationCache = .init(fileURL: cacheURL)
        pruned.load()
        #expect(!pruned.isVerified(file, checksums: checksums))
    }

    @Test func checkCachedSkipsHashForCachedFile() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "file-verify-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file: URL = directory.appending(path: "item.bin")
        try Data("content".utf8).write(to: file)
        let cache: FileVerificationCache = .init(fileURL: directory.appending(path: "cache.json"))

        let url: URL = try #require(URL(string: "https://example.com/a.bin"))
        let correctHash: String = try FileUtils.sha1(of: file)
        let item: DownloadItem = .init(url: url, destination: file, sha1: correctHash)
        #expect(try FileUtils.checkCached(item, using: cache))

        // 相同文件元数据不能让另一组错误校验和命中旧缓存。
        let wrongItem: DownloadItem = .init(url: url, destination: file, sha1: "deadbeef")
        #expect(try !FileUtils.checkCached(wrongItem, using: cache))

        // 无校验和的项始终视为通过
        let noChecksum: DownloadItem = .init(url: url, destination: file, checksums: nil)
        #expect(try FileUtils.checkCached(noChecksum, using: cache))
    }

    @Test func validatesMultipleChecksumsInOnePassAndSupportsMD5() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "file-verify-multihash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file: URL = directory.appending(path: "item.bin")
        try Data("content".utf8).write(to: file)
        let checksums: [String: String] = [
            "MD5": try FileUtils.hash(of: file, using: Insecure.MD5.self).uppercased(),
            "sha1": try FileUtils.sha1(of: file),
            "sha256": try FileUtils.sha256(of: file)
        ]
        #expect(try FileUtils.checkFile(at: file, with: checksums))
        #expect(try !FileUtils.checkFile(at: file, with: ["unknown": "value"]))
    }
}
