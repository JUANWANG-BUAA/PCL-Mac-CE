//
//  MicrosoftAccount.swift
//  PCLMacCE
//

import Foundation

public class MicrosoftAccount: Account {
    public private(set) var profile: PlayerProfile
    public private(set) var accessToken: String
    private var refreshToken: String
    private var lastRefresh: Date
    public let id: UUID

    private enum CodingKeys: String, CodingKey {
        case profile, accessToken, refreshToken, lastRefresh, id
    }

    public init(profile: PlayerProfile, accessToken: String, refreshToken: String) {
        self.profile = profile
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.lastRefresh = .now
        self.id = .init()
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.profile = try container.decode(PlayerProfile.self, forKey: .profile)
        // 令牌保存在安全存储中；JSON 缺失时先置空，由配置层在解码后恢复
        self.accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken) ?? ""
        self.refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken) ?? ""
        self.lastRefresh = try container.decodeIfPresent(Date.self, forKey: .lastRefresh) ?? .now
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? .init()
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile, forKey: .profile)
        // 不把令牌写入 JSON：微软 OAuth refresh token 可接管账号，只能存放在 Keychain
        try container.encode(lastRefresh, forKey: .lastRefresh)
        try container.encode(id, forKey: .id)
    }

    private var accessTokenKey: String { "microsoft.\(id.uuidString).accessToken" }
    private var refreshTokenKey: String { "microsoft.\(id.uuidString).refreshToken" }

    public func refresh() async throws {
        let service: MicrosoftAuthService = .init()
        let response = try await service.refresh(token: refreshToken)
        self.profile = response.profile
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        lastRefresh = .now
    }

    public func shouldRefresh() -> Bool {
        return Date.now.timeIntervalSince(lastRefresh) >= 86400
    }

    /// 记录一次失败的刷新尝试：将 lastRefresh 重置，使冷却 24 小时后再试，
    /// 避免刷新令牌失效后每次启动都弹窗骚扰（见 docs-book ADR-004）。
    public func markRefreshFailed() {
        lastRefresh = .now
    }

    public func persistSecrets(to store: AccountTokenStore) throws {
        try store.saveSecret(accessToken, for: accessTokenKey)
        try store.saveSecret(refreshToken, for: refreshTokenKey)
    }

    @discardableResult
    public func restoreSecrets(from store: AccountTokenStore) throws -> Bool {
        let storedAccessToken: String? = try store.readSecret(for: accessTokenKey)
        let storedRefreshToken: String? = try store.readSecret(for: refreshTokenKey)
        var migrated: Bool = false
        if let storedAccessToken {
            accessToken = storedAccessToken
        } else if !accessToken.isEmpty {
            // 旧版本把令牌明文写在 config.json 中：迁移进安全存储
            try store.saveSecret(accessToken, for: accessTokenKey)
            migrated = true
        }
        if let storedRefreshToken {
            refreshToken = storedRefreshToken
        } else if !refreshToken.isEmpty {
            try store.saveSecret(refreshToken, for: refreshTokenKey)
            migrated = true
        }
        return migrated
    }

    public func removeSecrets(from store: AccountTokenStore) {
        do {
            try store.deleteSecret(for: accessTokenKey)
            try store.deleteSecret(for: refreshTokenKey)
        } catch {
            err("删除账号令牌失败：\(error.localizedDescription)")
        }
    }
}
