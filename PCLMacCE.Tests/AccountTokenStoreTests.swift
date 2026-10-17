//
//  AccountTokenStoreTests.swift
//  PCLMacCE.Tests
//

import Foundation
import Testing
@testable import PCLMacCE
import Core

struct AccountTokenStoreTests {
    @Test func keychainSaveReadDelete() throws {
        let store: KeychainTokenStore = .init(service: "PCLMacCE.Tests.\(UUID().uuidString)")
        let key: String = "test.secret.\(UUID().uuidString)"

        #expect(try store.readSecret(for: key) == nil)
        try store.saveSecret("第一版", for: key)
        #expect(try store.readSecret(for: key) == "第一版")
        try store.saveSecret("覆盖更新", for: key)
        #expect(try store.readSecret(for: key) == "覆盖更新")
        try store.deleteSecret(for: key)
        #expect(try store.readSecret(for: key) == nil)
    }

    @Test func microsoftAccountTokensStayOutOfJSON() throws {
        let store: InMemoryTokenStore = .init()
        let profile: PlayerProfile = .init(name: "Steve", id: .init(), properties: [])
        let account: MicrosoftAccount = .init(profile: profile, accessToken: "secret-access", refreshToken: "secret-refresh")
        try account.persistSecrets(to: store)

        let data: Data = try JSONEncoder.shared.encode(AccountWrapper(account))
        let json: String = String(data: data, encoding: .utf8) ?? ""
        #expect(!json.contains("secret-access"))
        #expect(!json.contains("secret-refresh"))
        #expect(!json.contains("accessToken"))
        #expect(!json.contains("refreshToken"))

        // 解码后令牌为空，需要从安全存储恢复
        let decoded = try JSONDecoder.shared.decode(AccountWrapper.self, from: data).account as? MicrosoftAccount
        #expect(decoded != nil)
        guard let decoded else { return }
        #expect(decoded.accessToken.isEmpty)
        #expect(try decoded.restoreSecrets(from: store) == false)
        #expect(decoded.accessToken == "secret-access")
    }

    @Test func legacyPlaintextTokensMigrateToStore() throws {
        let store: InMemoryTokenStore = .init()
        let profile: PlayerProfile = .init(name: "Alex", id: .init(), properties: [])
        let account: MicrosoftAccount = .init(profile: profile, accessToken: "legacy-access", refreshToken: "legacy-refresh")
        // 模拟旧版本：JSON 解码出的账号自带明文令牌，安全存储为空
        #expect(try account.restoreSecrets(from: store) == true)
        #expect(try store.readSecret(for: "microsoft.\(account.id.uuidString).accessToken") == "legacy-access")
        #expect(try store.readSecret(for: "microsoft.\(account.id.uuidString).refreshToken") == "legacy-refresh")
    }

    @Test func yggdrasilAccountRoundtrip() throws {
        let store: InMemoryTokenStore = .init()
        let profile: PlayerProfile = .init(name: "Notch", id: .init(), properties: [])
        let account: YggdrasilAccount = .init(
            profile: profile,
            authServer: "示例验证服务器",
            authServerURL: .init(string: "https://example.com/api/yggdrasil")!,
            accessToken: "ygg-access",
            clientToken: "ygg-client"
        )
        try account.persistSecrets(to: store)

        let data: Data = try JSONEncoder.shared.encode(AccountWrapper(account))
        let json: String = String(data: data, encoding: .utf8) ?? ""
        #expect(!json.contains("ygg-access"))
        #expect(!json.contains("ygg-client"))

        let decoded = try JSONDecoder.shared.decode(AccountWrapper.self, from: data).account as? YggdrasilAccount
        #expect(decoded != nil)
        guard let decoded else { return }
        #expect(decoded.authServer == account.authServer)
        #expect(decoded.accessToken.isEmpty)
        _ = try decoded.restoreSecrets(from: store)
        #expect(decoded.accessToken == "ygg-access")
        decoded.removeSecrets(from: store)
        #expect(try store.readSecret(for: "yggdrasil.\(decoded.id.uuidString).accessToken") == nil)
    }

    /// Keychain 不可用时令牌落到应急文件，重启后可恢复；Keychain 恢复后应急文件被清理。
    @Test func emergencyFilePreservesTokensWhenKeychainUnavailable() throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "config-emergency-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        // 应急文件路径由配置文件路径派生（config.json → config.tokens.json），与其他测试天然隔离
        let url: URL = directory.appending(path: "config.json")
        let emergencyURL: URL = LauncherConfig.emergencyTokensURL(for: url)
        let originalStore: AccountTokenStore = LauncherConfig.tokenStore
        defer {
            LauncherConfig.tokenStore = originalStore
        }
        LauncherConfig.tokenStore = FailingTokenStore()

        let profile: PlayerProfile = .init(name: "Steve", id: .init(), properties: [])
        let account: MicrosoftAccount = .init(profile: profile, accessToken: "emergency-access", refreshToken: "emergency-refresh")
        let config: LauncherConfig = .init()
        config.accounts = [account]
        try LauncherConfig.save(config, to: url)

        let json: String = try String(data: Data(contentsOf: url), encoding: .utf8) ?? ""
        #expect(!json.contains("emergency-access"))
        let emergency: String = try String(data: Data(contentsOf: emergencyURL), encoding: .utf8) ?? ""
        #expect(emergency.contains("emergency-access"))
        #expect(emergency.contains("emergency-refresh"))

        // 模拟重启：Keychain 仍然不可用，令牌应从应急文件恢复
        let reloaded: LauncherConfig = try JSONDecoder.shared.decode(LauncherConfig.self, from: Data(contentsOf: url))
        reloaded.restoreEmergencyTokens(at: url)
        let restored = reloaded.accounts.first as? MicrosoftAccount
        #expect(restored != nil)
        guard let restored else { return }
        #expect(restored.accessToken == "emergency-access")

        // Keychain 恢复后保存：令牌进入存储，应急文件被清理
        let recoveredStore: InMemoryTokenStore = .init()
        LauncherConfig.tokenStore = recoveredStore
        try LauncherConfig.save(reloaded, to: url)
        #expect(!FileManager.default.fileExists(atPath: emergencyURL.path))
        #expect(try recoveredStore.readSecret(for: "microsoft.\(restored.id.uuidString).accessToken") == "emergency-access")
    }
}

/// 模拟 Keychain 完全不可用的存储。
private final class FailingTokenStore: AccountTokenStore {
    func saveSecret(_ value: String, for key: String) throws {
        throw SimpleError("Keychain 不可用")
    }

    func readSecret(for key: String) throws -> String? {
        throw SimpleError("Keychain 不可用")
    }

    func deleteSecret(for key: String) throws {
        throw SimpleError("Keychain 不可用")
    }
}
