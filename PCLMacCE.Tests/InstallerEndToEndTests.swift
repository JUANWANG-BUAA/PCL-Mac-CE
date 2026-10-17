//
//  InstallerEndToEndTests.swift
//  PCLMacCE.Tests
//
//  真实网络下的安装链路验收（手动/发布前执行）：
//  版本清单 → 客户端清单解析 → 库文件下载 → sha1 校验 → 校验缓存命中。
//  CI 默认离线执行时通过环境变量跳过。
//

import Testing
import Foundation
import Core

struct InstallerEndToEndTests {
    @Test func installerPipelineWithRealUpstream() async throws {
        if ProcessInfo.processInfo.environment["GITHUB_ENV"] != nil
            || ProcessInfo.processInfo.environment["PCL_MAC_SKIP_ONLINE_TESTS"] != nil {
            print("跳过在线安装链路验收")
            return
        }
        let manifest: VersionManifest = try await VersionManifest.load(revalidate: false)
        #expect(!manifest.versions.isEmpty)
        guard let version = manifest.version(for: "1.21.10") ?? manifest.versions.first(where: { $0.type == .release }) else {
            Issue.record("版本清单中没有可用的正式版")
            return
        }

        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "installer-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 1. 客户端清单
        let manifestURL: URL = directory.appending(path: "\(version.id).json")
        try await FileDownloader.shared.download(url: version.url, destination: manifestURL)
        let client: ClientManifest = try JSONDecoder.shared.decode(
            ClientManifest.self, from: Data(contentsOf: manifestURL)
        )
        #expect(client.mainClass != nil)
        #expect(!client.libraries.isEmpty)

        // 2. 库文件下载 + 校验（取前 3 个普通库，控制网络开销）
        let artifacts = Array(client.libraries.compactMap(\.artifact).prefix(3))
        let items: [DownloadItem] = artifacts.map { artifact in
            DownloadItem(
                url: URL(string: "https://libraries.minecraft.net/\(artifact.path)")!,
                destination: directory.appending(path: artifact.path),
                sha1: artifact.sha1
            )
        }
        try await FileDownloader.shared.download(files: items) { _ in }
        for item in items {
            #expect(FileManager.default.fileExists(atPath: item.destination.path))
        }

        // 3. 校验缓存：二次调用应命中（文件未变更，不再整文件哈希）
        let start = Date()
        try await FileDownloader.shared.download(files: items) { _ in }
        let elapsed = Date().timeIntervalSince(start)
        // 仅作记录：缓存命中通常在数十毫秒内
        print("二次校验耗时：\(String(format: "%.1f", elapsed * 1000)) ms（命中校验缓存）")
    }
}
