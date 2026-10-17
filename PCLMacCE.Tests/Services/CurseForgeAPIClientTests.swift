//
//  CurseForgeAPIClientTests.swift
//  PCLMacCE
//

import Foundation
import Core
import Testing

struct CurseForgeAPIClientTests {
    /// 需要真实 API Key 的在线测试：未配置环境变量时跳过，避免依赖用户配置。
    /// 运行方式：
    /// `TEST_RUNNER_PCLMAC_CURSE_FORGE_API_KEY=<key> xcodebuild test ...`
    @Test func searchAndFilesWithRealKey() async throws {
        if ProcessInfo.processInfo.environment["GITHUB_ENV"] != nil {
            print("跳过 CurseForge 在线测试")
            return
        }
        guard let key = ProcessInfo.processInfo.environment["PCLMAC_CURSE_FORGE_API_KEY"], !key.isEmpty else {
            print("未提供 PCLMAC_CURSE_FORGE_API_KEY，跳过 CurseForge 在线测试")
            return
        }
        let client: CurseForgeAPIClient = .init(apiKey: key)

        // 搜索：验证小写 403 时自动回退大写路径仍能拿到结果
        let result = try await client.search(type: .mod, "JEI", forVersion: nil, pageIndex: 0, pageSize: 5)
        #expect(!result.mods.isEmpty)
        #expect(result.mods.contains { $0.name.localizedCaseInsensitiveContains("Just Enough Items") })
        for mod in result.mods.prefix(3) {
            print("\(mod.name) | \(mod.id) | \(mod.downloadCount ?? 0)")
        }

        // 详情与文件列表（整合包依赖解析依赖这两个接口）
        let jei = try await client.mod(id: 238222)
        #expect(jei?.name != nil)
        let files = try await client.files(modId: 238222)
        #expect(!files.isEmpty)
    }
}
