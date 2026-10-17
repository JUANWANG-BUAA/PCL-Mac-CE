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
}
