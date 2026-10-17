//
//  OfflineAccount.swift
//  PCLMacCE
//

import Foundation

public class OfflineAccount: Account {
    public let profile: PlayerProfile
    public let id: UUID

    public init(name: String, uuid: UUID) {
        self.profile = .init(name: name, id: uuid, properties: [])
        self.id = .init()
    }

    public var accessToken: String {
        UUIDUtils.string(of: .init(), withHyphens: false) // 随机 UUID
    }

    public func refresh() async throws {}

    public func shouldRefresh() -> Bool { false }

    // 离线账号没有需要保管的令牌
    public func persistSecrets(to store: AccountTokenStore) throws {}

    public func restoreSecrets(from store: AccountTokenStore) -> Bool { false }

    public func removeSecrets(from store: AccountTokenStore) {}
}
