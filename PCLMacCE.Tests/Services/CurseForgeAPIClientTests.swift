//
//  CurseForgeAPIClientTests.swift
//  PCLMacCE
//

import Foundation
import Core
import Testing

struct CurseForgeAPIClientTests {
    private func realKey() -> String? {
        guard ProcessInfo.processInfo.environment["GITHUB_ENV"] == nil else { return nil }
        guard let key = ProcessInfo.processInfo.environment["PCLMAC_CURSE_FORGE_API_KEY"], !key.isEmpty else {
            print("未提供 PCLMAC_CURSE_FORGE_API_KEY，跳过 CurseForge 在线测试")
            return nil
        }
        return key
    }

    /// 需要真实 API Key 的在线测试：未配置环境变量时跳过，避免依赖用户配置。
    /// 运行方式：
    /// `TEST_RUNNER_PCLMAC_CURSE_FORGE_API_KEY=<key> xcodebuild test ...`
    @Test func searchAndFilesWithRealKey() async throws {
        guard let key = realKey() else { return }
        let client: CurseForgeAPIClient = .init(apiKey: key)

        // 搜索：验证小写 403 时自动回退大写路径仍能拿到结果
        let result = try await client.search(type: .mod, "JEI", forVersion: nil, pageIndex: 0, pageSize: 5)
        #expect(!result.mods.isEmpty)
        #expect(result.mods.contains { $0.name.localizedCaseInsensitiveContains("Just Enough Items") })

        // 详情与文件列表（整合包依赖解析依赖这两个接口）
        let jei = try await client.mod(id: 238222)
        #expect(jei?.name != nil)
        let files = try await client.files(modId: 238222)
        #expect(!files.isEmpty)
    }

    /// 真实验证：必需依赖 ID、批量工程元数据和目标版本文件查询可串联工作。
    @Test func requiredDependencyMetadataAndFilesWithRealKey() async throws {
        guard let key = realKey() else { return }
        let client: CurseForgeAPIClient = .init(apiKey: key)

        // Waystones 当前依赖 Balm；动态选取服务端返回的首个带必需依赖文件。
        let root = try await client.mod(id: 245755)
        #expect(root?.name.localizedCaseInsensitiveContains("Waystones") == true)
        let rootFiles = try await client.files(modId: 245755)
        guard let rootFile = rootFiles.first(where: {
            !$0.requiredDependencyModIds.isEmpty && !$0.minecraftVersions.isEmpty
        }) else {
            Issue.record("Waystones 未返回带游戏版本的必需依赖文件")
            return
        }

        let requiredIDs = Array(Set(rootFile.requiredDependencyModIds)).sorted()
        let dependencyProjects = try await client.mods(ids: requiredIDs)
        #expect(Set(dependencyProjects.map(\.id)) == Set(requiredIDs))

        let gameVersion = try #require(rootFile.minecraftVersions.first)
        for dependencyID in requiredIDs {
            let files = try await client.files(
                modId: Int(dependencyID),
                gameVersion: gameVersion,
                loader: rootFile.loaders.first
            )
            #expect(files.contains {
                $0.isCompatible(withGameVersion: gameVersion, loader: rootFile.loaders.first)
            })
        }
    }
}
