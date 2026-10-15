//
//  MicrosoftAccount.swift
//  PCL.Mac
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
}
