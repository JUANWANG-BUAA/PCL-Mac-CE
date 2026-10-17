//
//  FileVerificationCacheTests.swift
//  PCLMacCE.Tests
//

import Foundation
import Testing
import Core

struct FileVerificationCacheTests {
    @Test func skipsUnchangedAndRechecksChangedFiles() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "file-verify-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file: URL = directory.appending(path: "a.bin")
        try Data("hello".utf8).write(to: file)
        let cacheURL: URL = directory.appending(path: "cache.json")

        let cache: FileVerificationCache = .init(fileURL: cacheURL)
        cache.load()
        // 未记录过的文件不视为已验证
        #expect(!cache.isVerified(file))
        cache.markVerified(file)
        #expect(cache.isVerified(file))
        cache.flush()

        // 模拟重启：重新加载后仍然命中
        let reloaded: FileVerificationCache = .init(fileURL: cacheURL)
        reloaded.load()
        #expect(reloaded.isVerified(file))

        // 文件被修改（mtime 变化）后缓存失效
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(5)],
            ofItemAtPath: file.path
        )
        #expect(!reloaded.isVerified(file))

        // 文件删除后失效；加载阶段会清理不存在文件的条目
        try FileManager.default.removeItem(at: file)
        #expect(!reloaded.isVerified(file))
        reloaded.markVerified(directory.appending(path: "missing.bin")) // 不应产生记录
        reloaded.flush()
        let pruned: FileVerificationCache = .init(fileURL: cacheURL)
        pruned.load()
        #expect(!pruned.isVerified(file))
    }

    @Test func checkCachedSkipsHashForCachedFile() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "file-verify-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let file: URL = directory.appending(path: "item.bin")
        try Data("content".utf8).write(to: file)
        let cache: FileVerificationCache = .init(fileURL: directory.appending(path: "cache.json"))

        let item: DownloadItem = .init(url: .init(string: "https://example.com/a.bin")!, destination: file, sha1: "deadbeef")
        // 无缓存记录时执行真实哈希：错误校验和应当失败
        #expect(try !FileUtils.checkCached(item, using: cache))
        // 缓存记录后：即使校验和错误也按“文件未变更”跳过（生产语义）
        try Data("whatever".utf8).write(to: file)
        cache.markVerified(file)
        #expect(try FileUtils.checkCached(item, using: cache))
        // 无校验和的项始终视为通过
        let noChecksum: DownloadItem = .init(url: item.url, destination: file, checksums: nil)
        #expect(try FileUtils.checkCached(noChecksum, using: cache))
    }
}
