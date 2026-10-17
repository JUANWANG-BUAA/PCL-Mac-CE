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
            // Keychain 不可用期间落盘的应急令牌在此恢复并重试迁移
            config.restoreEmergencyTokens(at: url)
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
    public var autoInstallLauncherUpdates: Bool = true
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
        self.autoInstallLauncherUpdates = try container.decodeIfPresent(Bool.self, forKey: .autoInstallLauncherUpdates) ?? true
        self.downloadSourcePolicy = try container.decodeIfPresent(DownloadSourcePolicy.self, forKey: .downloadSourcePolicy) ?? .officialFirst
        self.homepageType = try container.decodeIfPresent(HomepageType.self, forKey: .homepageType) ?? .empty
        self.enabledFlags = try container.decodeIfPresent(Set<FeatureFlag>.self, forKey: .enabledFlags)
        self.customJavaRuntimes = try container.decodeIfPresent([URL].self, forKey: .customJavaRuntimes) ?? []
        self.theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .classic

        // Keychain 优先恢复；旧版本写在 JSON 里的明文凭据在此时迁移。
        // 应急文件的恢复需要知道来源路径，由静态工厂在解码后调用 restoreEmergencyTokens(at:)
        restoreTokensFromKeychain()
    }

    /// 从 Keychain 恢复账号令牌；JSON 中的旧版明文凭据在此迁移进安全存储。
    private func restoreTokensFromKeychain() {
        for account in accounts {
            do {
                migratedLegacyTokens = (try account.restoreSecrets(from: LauncherConfig.tokenStore)) || migratedLegacyTokens
            } catch {
                err("从安全存储恢复账号令牌失败：\(error.localizedDescription)")
            }
        }
    }

    /// 从配置文件旁边的应急令牌文件恢复令牌（Keychain 不可用期间落盘的内容），
    /// 并尝试回写 Keychain；回写成功会触发配置重写以清理明文/应急文件。
    func restoreEmergencyTokens(at configURL: URL) {
        guard let emergencyStore = Self.loadEmergencyTokenStore(at: Self.emergencyTokensURL(for: configURL)) else {
            return
        }
        for account in accounts {
            _ = try? account.restoreSecrets(from: emergencyStore)
        }
        restoreTokensFromKeychain()
    }

    /// 应急令牌文件路径：与配置文件同目录（`config.json` → `config.tokens.json`）。
    /// 按配置文件派生而非全局固定路径，避免向其他路径保存配置时误删真实应急文件。
    public static func emergencyTokensURL(for configURL: URL) -> URL {
        return configURL.deletingLastPathComponent()
            .appending(path: configURL.deletingPathExtension().lastPathComponent + ".tokens.json")
    }

    /// 读取应急令牌文件；不存在或损坏时返回 `nil`（损坏的文件会被移除以免反复报错）。
    private static func loadEmergencyTokenStore(at emergencyURL: URL) -> InMemoryTokenStore? {
        guard FileManager.default.fileExists(atPath: emergencyURL.path) else { return nil }
        do {
            let data: Data = try Data(contentsOf: emergencyURL)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
                throw SimpleError("应急令牌文件格式错误。")
            }
            let store: InMemoryTokenStore = .init()
            for (key, value) in dict {
                store.saveSecret(value, for: key)
            }
            return store
        } catch {
            err("读取应急令牌文件失败：\(error.localizedDescription)")
            try? FileManager.default.removeItem(at: emergencyURL)
            return nil
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
        try container.encode(autoInstallLauncherUpdates, forKey: .autoInstallLauncherUpdates)
        try container.encode(downloadSourcePolicy, forKey: .downloadSourcePolicy)
        try container.encode(homepageType, forKey: .homepageType)
        try container.encodeIfPresent(enabledFlags, forKey: .enabledFlags)
        try container.encode(customJavaRuntimes, forKey: .customJavaRuntimes)
        try container.encode(theme, forKey: .theme)
    }

    public static func save(_ config: LauncherConfig = .shared, to url: URL = URLConstants.configURL) throws {
        // 令牌优先写入 Keychain；Keychain 不可用时落到权限 600 的应急文件，
        // 保证配置保存不被阻断、令牌不丢失，下次启动会自动重试迁移
        let emergencyURL: URL = emergencyTokensURL(for: url)
        let stagedSecrets: InMemoryTokenStore = .init()
        var keychainFailed: Bool = false
        for account in config.accounts {
            do {
                try account.persistSecrets(to: tokenStore)
            } catch {
                keychainFailed = true
                err("写入账号令牌到安全存储失败：\(error.localizedDescription)")
            }
            try? account.persistSecrets(to: stagedSecrets)
        }
        if keychainFailed {
            do {
                let data: Data = try JSONSerialization.data(
                    withJSONObject: stagedSecrets.snapshot(),
                    options: [.prettyPrinted, .sortedKeys]
                )
                try data.write(to: emergencyURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: emergencyURL.path)
                warn("Keychain 暂不可用，账号令牌已保存到应急文件（\(emergencyURL.lastPathComponent)，权限 600）")
            } catch {
                err("写入应急令牌文件失败：\(error.localizedDescription)")
                throw SimpleError("账号令牌无法保存：Keychain 与应急文件均写入失败。")
            }
        } else if FileManager.default.fileExists(atPath: emergencyURL.path) {
            // Keychain 已恢复：清理应急文件
            try? FileManager.default.removeItem(at: emergencyURL)
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
        case autoInstallLauncherUpdates
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
