//
//  Secrets.swift
//  PCLMacCE
//

import Foundation
import Core

struct Secrets {
    public static let shared: Secrets = .init()

    public let curseforgeApiKey: String?
    public let microsoftClientID: String?

    /// 用户本地覆盖文件：与安装包内的模板分离，避免把真实凭据写进仓库。
    /// 位于 `~/Library/Application Support/PCLMacCE/Secrets.local.properties`，权限 600。
    public static var localSecretsURL: URL {
        URLConstants.applicationSupportURL.appending(path: "Secrets.local.properties")
    }

    private init() {
        // 优先级：环境变量 → 本地覆盖文件 → 安装包内模板
        let bundled: [String: String]? = Self.loadBundledSecrets()
        let local: [String: String]? = Self.loadLocalSecrets()

        curseforgeApiKey = Self.secret(key: "CURSE_FORGE_API_KEY", local: local, bundled: bundled)
        microsoftClientID = Self.secret(key: "MS_CLIENT_ID", local: local, bundled: bundled, warnIfMissing: false)
    }

    private static func loadBundledSecrets() -> [String: String]? {
        do {
            return try PropertiesLoader.load(at: URLConstants.resourcesURL.appending(path: "Secrets.properties"))
        } catch {
            err("加载 Secrets.properties 失败：\(error.localizedDescription)")
            return nil
        }
    }

    private static func loadLocalSecrets() -> [String: String]? {
        let url = localSecretsURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try PropertiesLoader.load(at: url)
        } catch {
            err("加载本地 Secrets 覆盖文件失败：\(error.localizedDescription)")
            return nil
        }
    }

    private static func secret(
        key: String,
        local: [String: String]?,
        bundled: [String: String]?,
        warnIfMissing: Bool = true
    ) -> String? {
        let value = (ProcessInfo.processInfo.environment["PCLMAC_\(key)"] ?? local?[key] ?? bundled?[key])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let value, !value.isEmpty {
            return value
        }
        if warnIfMissing {
            warn("缺少 Secret 项 \(key)（可在 \(localSecretsURL.path) 配置）")
        }
        return nil
    }
}
