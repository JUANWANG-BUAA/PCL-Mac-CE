//
//  URLConstants.swift
//  PCLMacCE
//

import Foundation

public struct URLConstants {
    public static let contentsURL: URL = Bundle.main.bundleURL.appending(path: "Contents")
    public static let resourcesURL: URL = contentsURL.appending(path: "Resources")

    /// 测试进程（`PCL_MAC_TESTING=1`，由 xctestplan 注入）与生产环境隔离：
    /// 使用独立的数据目录，避免测试轮转生产日志、写入生产 Temp 与缓存。
    private static let isTesting: Bool = ProcessInfo.processInfo.environment["PCL_MAC_TESTING"] == "1"

    /// 历史数据目录（按时间倒序：上游仓库名与更名前的过渡名），首次运行新版时迁移到 `applicationSupportURL`。
    private static let legacyApplicationSupportURLs: [URL] = [
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/PCL.Mac"),
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/PCL.Mac.Refactor")
    ]

    public static let applicationSupportURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: isTesting ? "Library/Application Support/PCLMacCE/TestHome" : "Library/Application Support/PCLMacCE")
    public static let logsDirectoryURL: URL = applicationSupportURL.appending(path: "Logs")
    public static let configURL: URL = applicationSupportURL.appending(path: "config.json")
    public static let cacheURL: URL = applicationSupportURL.appending(path: "Caches")
    public static let tempURL: URL = applicationSupportURL.appending(path: "Temp")
    /// 普通下载（无实例上下文）的资源存放目录。
    public static let downloadCacheURL: URL = applicationSupportURL.appending(path: "DownloadCache")
    public static let authlibInjectorURL: URL = applicationSupportURL.appending(path: "authlib-injector.jar")

    public static func createDirectories() throws {
        let fileManager: FileManager = .default
        try fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: downloadCacheURL, withIntermediateDirectories: true)
    }

    /// 一次性迁移：历史数据目录（`PCL.Mac` / `PCL.Mac.Refactor`）→ 现目录（`PCLMacCE`）。
    ///
    /// 必须在 `createDirectories()` 与首次访问 `LauncherConfig` 之前调用（否则新目录先建、
    /// 迁移条件失效）。仅在新目录不存在时执行原子改名；多个历史目录并存时按最近者优先。
    public static func migrateLegacyApplicationSupport() {
        guard !isTesting else { return }
        let fileManager: FileManager = .default
        guard !fileManager.fileExists(atPath: applicationSupportURL.path) else { return }
        guard let legacyURL: URL = legacyApplicationSupportURLs.first(where: { fileManager.fileExists(atPath: $0.path) }) else { return }
        do {
            try fileManager.moveItem(at: legacyURL, to: applicationSupportURL)
            log("已迁移历史数据目录：\(legacyURL.path) → \(applicationSupportURL.path)")
        } catch {
            err("迁移历史数据目录失败（继续使用新目录全新初始化）：\(error.localizedDescription)")
        }
    }
}
