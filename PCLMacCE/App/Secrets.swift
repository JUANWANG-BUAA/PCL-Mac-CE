//
//  Secrets.swift
//  PCLMacCE
//

import Foundation
import Core

final class Secrets {
    public static let shared: Secrets = .init()

    public private(set) var curseforgeApiKey: String?
    public private(set) var microsoftClientID: String?

    /// 用户本地覆盖文件：与安装包内的模板分离，避免把真实凭据写进仓库。
    /// 位于 `~/Library/Application Support/PCLMacCE/Secrets.local.properties`，权限 600。
    public static var localSecretsURL: URL {
        URLConstants.applicationSupportURL.appending(path: "Secrets.local.properties")
    }

    init() {
        reload()
    }

    /// 重新从环境变量、本地覆盖与安装包模板读取全部密钥。
    /// 用户修改 Key 后调用，使 `CurseForgeAPIClient.apiKeyProvider` 立即读到新值。
    func reload() {
        // 优先级：环境变量 → 本地覆盖文件 → 安装包内模板
        let bundled: [String: String]? = Self.loadBundledSecrets()
        let local: [String: String]? = Self.loadLocalSecrets()

        curseforgeApiKey = Self.secret(key: "CURSE_FORGE_API_KEY", local: local, bundled: bundled)
        microsoftClientID = Self.secret(key: "MS_CLIENT_ID", local: local, bundled: bundled, warnIfMissing: false)
        log("CurseForge API Key 状态：\(curseforgeApiKey == nil ? "未配置" : "已配置")")
    }

    /// 保存 CurseForge API Key 到本地覆盖文件；传入空值时移除该配置。
    /// 仅修改本地文件，不触碰安装包内的模板，也不会进入 Git。
    static func saveCurseForgeAPIKey(_ key: String?) throws {
        let trimmed: String = (key ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let url: URL = localSecretsURL
        var lines: [String] = []
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        }
        // 移除已有的同名配置行（保留注释与其他键）
        lines.removeAll { $0.hasPrefix("CURSE_FORGE_API_KEY=") }
        if !trimmed.isEmpty {
            lines.append("CURSE_FORGE_API_KEY=\(trimmed)")
        }
        let content: String = lines.joined(separator: "\n")
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // 没有其他内容时删除文件，避免留下空文件
            try? FileManager.default.removeItem(at: url)
        } else {
            try content.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
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
            warn("缺少 Secret 项 \(key)（可在设置页或 \(localSecretsURL.path) 配置）")
        }
        return nil
    }
}
