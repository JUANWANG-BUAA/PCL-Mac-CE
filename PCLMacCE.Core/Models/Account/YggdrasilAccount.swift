//
//  YggdrasilAccount.swift
//  PCLMacCE
//

import Foundation

public class YggdrasilAccount: Account {
    public let id: UUID
    public private(set) var profile: PlayerProfile
    public let authServer: String
    public let authServerURL: URL
    public private(set) var cachedMetadata: String?

    private lazy var service: YggdrasilService = .init(authServerURL: authServerURL)
    public private(set) var accessToken: String
    private var clientToken: String

    private enum CodingKeys: String, CodingKey {
        case id, profile, authServer, authServerURL, cachedMetadata, accessToken, clientToken
    }

    public init(
        profile: PlayerProfile,
        authServer: String,
        authServerURL: URL,
        accessToken: String,
        clientToken: String
    ) {
        self.id = .init()
        self.profile = profile
        self.authServer = authServer
        self.authServerURL = authServerURL
        self.accessToken = accessToken
        self.clientToken = clientToken
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? .init()
        self.profile = try container.decode(PlayerProfile.self, forKey: .profile)
        self.authServer = try container.decode(String.self, forKey: .authServer)
        self.authServerURL = try container.decode(URL.self, forKey: .authServerURL)
        self.cachedMetadata = try container.decodeIfPresent(String.self, forKey: .cachedMetadata)
        // 令牌保存在安全存储中；JSON 缺失时先置空，由配置层在解码后恢复
        self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken) ?? ""
        self.clientToken = try container.decodeIfPresent(String.self, forKey: .clientToken) ?? ""
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(profile, forKey: .profile)
        try container.encode(authServer, forKey: .authServer)
        try container.encode(authServerURL, forKey: .authServerURL)
        try container.encodeIfPresent(cachedMetadata, forKey: .cachedMetadata)
        // 不把令牌写入 JSON：验证服务器的令牌只能存放在 Keychain
    }

    private var accessTokenKey: String { "yggdrasil.\(id.uuidString).accessToken" }
    private var clientTokenKey: String { "yggdrasil.\(id.uuidString).clientToken" }

    public func refresh() async throws {
        let response = try await service.refresh(accessToken, clientToken: clientToken, profile: profile)
        self.accessToken = response.accessToken
        if let profile = response.selectedProfile {
            let fullProfile: PlayerProfile = try await service.fullProfile(for: profile.id)
            self.profile = fullProfile
        }
    }

    public func shouldRefresh() async throws -> Bool {
        return try await service.validateToken(accessToken, clientToken: clientToken) == false
    }

    public func fetchMetadata() async throws -> String {
        let metadata = try await service.fetchMetadata().encoded
        self.cachedMetadata = metadata
        return metadata
    }

    public func persistSecrets(to store: AccountTokenStore) throws {
        try store.saveSecret(accessToken, for: accessTokenKey)
        try store.saveSecret(clientToken, for: clientTokenKey)
    }

    @discardableResult
    public func restoreSecrets(from store: AccountTokenStore) throws -> Bool {
        let storedAccessToken: String? = try store.readSecret(for: accessTokenKey)
        let storedClientToken: String? = try store.readSecret(for: clientTokenKey)
        var migrated: Bool = false
        if let storedAccessToken {
            accessToken = storedAccessToken
        } else if !accessToken.isEmpty {
            // 旧版本把令牌明文写在 config.json 中：迁移进安全存储
            try store.saveSecret(accessToken, for: accessTokenKey)
            migrated = true
        }
        if let storedClientToken {
            clientToken = storedClientToken
        } else if !clientToken.isEmpty {
            try store.saveSecret(clientToken, for: clientTokenKey)
            migrated = true
        }
        return migrated
    }

    public func removeSecrets(from store: AccountTokenStore) {
        do {
            try store.deleteSecret(for: accessTokenKey)
            try store.deleteSecret(for: clientTokenKey)
        } catch {
            err("删除账号令牌失败：\(error.localizedDescription)")
        }
    }
}
