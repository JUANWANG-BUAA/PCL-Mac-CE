//
//  Account.swift
//  PCLMacCE
//

import Foundation

public protocol Account: Codable {
    var profile: PlayerProfile { get }
    var id: UUID { get }
    var accessToken: String { get }
    func refresh() async throws
    func shouldRefresh() async throws -> Bool
    /// 把令牌写入安全存储；无令牌的账号（离线账号）为空实现。
    ///
    /// 注意：这三个方法必须是协议要求而非仅扩展默认实现——否则通过 `Account`
    /// 存在类型调用时会静态派发到扩展的空实现，具体类型的实现永远不会执行。
    func persistSecrets(to store: AccountTokenStore) throws
    /// 从安全存储恢复令牌；返回是否发生了明文→安全存储的迁移。
    @discardableResult
    func restoreSecrets(from store: AccountTokenStore) throws -> Bool
    /// 删除安全存储中的令牌（账号被移除时调用）。
    func removeSecrets(from store: AccountTokenStore)
}

public enum AccountType: String, Codable {
    case offline, microsoft, yggdrasil
}

public class AccountWrapper: Codable {
    public let type: AccountType
    public let account: Account

    public init(_ account: Account) {
        self.type = account.type
        self.account = account
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case account
    }

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(AccountType.self, forKey: .type)
        switch type {
        case .offline:
            self.account = try container.decode(OfflineAccount.self, forKey: .account)
        case .microsoft:
            self.account = try container.decode(MicrosoftAccount.self, forKey: .account)
        case .yggdrasil:
            self.account = try container.decode(YggdrasilAccount.self, forKey: .account)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(account, forKey: .account)
    }
}

public extension Account {
    var type: AccountType {
        switch self {
        case is OfflineAccount:
            .offline
        case is MicrosoftAccount:
            .microsoft
        case is YggdrasilAccount:
            .yggdrasil
        default:
            fatalError() // unreachable
        }
    }
}
