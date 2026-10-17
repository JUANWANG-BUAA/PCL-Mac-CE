//
//  LauncherConfig.swift
//  PCLMacCE
//

import Foundation
import Core

class LauncherConfig: Codable {
    public static let shared: LauncherConfig = {
        let url = URLConstants.configURL

        if !FileManager.default.fileExists(atPath: url.path) {
            let config: LauncherConfig = .init()
            log("配置文件不存在，正在创建")
            do {
                try save(config, to: url)
            } catch {
                err("保存配置文件失败：\(error.localizedDescription)")
            }
            return config
        }
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder.shared.decode(LauncherConfig.self, from: data)
            if config.migratedLegacyTokens {
                // 旧版明文凭据已进入安全存储，立即重写一次配置把 JSON 中的凭据清除掉
                do {
                    try save(config, to: url)
                } catch {
                    err("清除配置文件中的明文凭据失败：\(error.localizedDescription)")
                }
            }
            return config
        } catch {
            err("加载配置文件失败：\(error.localizedDescription)")
            do {
                // 原备份不能先删除：读取或写入失败时仍保留上一次可恢复的副本。
                let originalData = try Data(contentsOf: url)
                try originalData.write(to: backupURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
                log("备份配置文件成功：\(backupURL.path)")
            } catch {
                err("备份配置文件失败：\(error.localizedDescription)")
                // 未保全原始文件时禁止后续自动保存，避免覆盖唯一的损坏配置。
                saveBlockedReason = error
            }
            loadError = error
            let config = LauncherConfig()
            if saveBlockedReason == nil {
                do {
                    try save(config, to: url)
                } catch {
                    err("重建配置文件失败：\(error.localizedDescription)")
                }
            }
            return config
        }
    }()

    public static let backupURL: URL = URLConstants.applicationSupportURL.appending(path: "config.bak.json")
    public private(set) static var loadError: Error?
    /// 原配置备份失败时阻止任何自动保存，保留原文件供人工恢复。
    public private(set) static var saveBlockedReason: Error?
    /// 账号令牌的安全存储；测试可注入内存实现。
    public static var tokenStore: AccountTokenStore = KeychainTokenStore()
    /// 本次加载是否发生了明文令牌→安全存储的迁移（用于加载后立即重写配置清除凭据）。
    public private(set) var migratedLegacyTokens: Bool = false

    public var minecraftRepositories: [MinecraftRepository] = []
    public var currentRepositoryId: UUID?
    public var currentInstance: String?
    public var accounts: [Account] = []
    public var currentAccountId: UUID?
    public var hasMicrosoftAccount: Bool = false
    public var launchCount: Int = 0
    public var hasEnteredLauncher: Bool = false
    public var ignoreLauncherUpdates: Bool = false
    public var downloadSourcePolicy: DownloadSourcePolicy = .officialFirst
    public var homepageType: HomepageType = .empty
    public var enabledFlags: Set<FeatureFlag>?
    public var customJavaRuntimes: [URL] = []
    public var theme: AppTheme = .classic

    public init() {}

    public required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.minecraftRepositories = try container.decodeIfPresent([MinecraftRepository].self, forKey: .minecraftRepositories) ?? []
        self.currentRepositoryId = try container.decodeIfPresent(UUID.self, forKey: .currentRepositoryId)

        self.currentInstance = try container.decodeIfPresent(String.self, forKey: .currentInstance)
        self.accounts = (try container.decodeIfPresent([AccountWrapper].self, forKey: .accounts) ?? []).map(\.account)
        if !accounts.isEmpty {
            if let currentAccountId = try container.decodeIfPresent(UUID.self, forKey: .currentAccountId),
               accounts.contains(where: { $0.id == currentAccountId }) {
                self.currentAccountId = currentAccountId
            } else {
                self.currentAccountId = accounts[0].id
            }
        }
        self.hasMicrosoftAccount = try container.decodeIfPresent(Bool.self, forKey: .hasMicrosoftAccount) ?? false
        self.launchCount = try container.decodeIfPresent(Int.self, forKey: .launchCount) ?? 0
        self.hasEnteredLauncher = try container.decodeIfPresent(Bool.self, forKey: .hasEnteredLauncher) ?? false
        self.ignoreLauncherUpdates = try container.decodeIfPresent(Bool.self, forKey: .ignoreLauncherUpdates) ?? false
        self.downloadSourcePolicy = try container.decodeIfPresent(DownloadSourcePolicy.self, forKey: .downloadSourcePolicy) ?? .officialFirst
        self.homepageType = try container.decodeIfPresent(HomepageType.self, forKey: .homepageType) ?? .empty
        self.enabledFlags = try container.decodeIfPresent(Set<FeatureFlag>.self, forKey: .enabledFlags)
        self.customJavaRuntimes = try container.decodeIfPresent([URL].self, forKey: .customJavaRuntimes) ?? []
        self.theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .classic

        // 账号令牌从安全存储恢复；旧版本写在 JSON 里的明文凭据在此时迁移
        for account in self.accounts {
            do {
                migratedLegacyTokens = (try account.restoreSecrets(from: LauncherConfig.tokenStore)) || migratedLegacyTokens
            } catch {
                err("从安全存储恢复账号令牌失败：\(error.localizedDescription)")
            }
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minecraftRepositories, forKey: .minecraftRepositories)
        try container.encode(currentRepositoryId, forKey: .currentRepositoryId)
        try container.encode(currentInstance, forKey: .currentInstance)
        try container.encode(accounts.map(AccountWrapper.init(_:)), forKey: .accounts)
        try container.encode(currentAccountId, forKey: .currentAccountId)
        try container.encode(hasMicrosoftAccount, forKey: .hasMicrosoftAccount)
        try container.encode(launchCount, forKey: .launchCount)
        try container.encode(hasEnteredLauncher, forKey: .hasEnteredLauncher)
        try container.encode(ignoreLauncherUpdates, forKey: .ignoreLauncherUpdates)
        try container.encode(downloadSourcePolicy, forKey: .downloadSourcePolicy)
        try container.encode(homepageType, forKey: .homepageType)
        try container.encodeIfPresent(enabledFlags, forKey: .enabledFlags)
        try container.encode(customJavaRuntimes, forKey: .customJavaRuntimes)
        try container.encode(theme, forKey: .theme)
    }

    public static func save(_ config: LauncherConfig = .shared, to url: URL = URLConstants.configURL) throws {
        // 令牌先进安全存储，JSON 里不再包含任何凭据
        for account in config.accounts {
            try account.persistSecrets(to: tokenStore)
        }
        let data = try JSONEncoder.shared.encode(config)
        if let saveBlockedReason, url == URLConstants.configURL {
            throw SimpleError("原配置文件未能备份，已停止自动保存以防覆盖：\(saveBlockedReason.localizedDescription)")
        }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private enum CodingKeys: String, CodingKey {
        case minecraftRepositories
        case currentRepositoryId
        case currentInstance
        case accounts
        case currentAccountId
        case hasMicrosoftAccount
        case launchCount
        case hasEnteredLauncher
        case ignoreLauncherUpdates
        case downloadSourcePolicy
        case homepageType
        case enabledFlags
        case customJavaRuntimes
        case theme
    }

    enum HomepageType: String, Codable, CustomStringConvertible {
        case empty, demo

        var description: String {
            switch self {
            case .empty: "空白"
            case .demo: "[内置] 控件预览"
            }
        }
    }
}
