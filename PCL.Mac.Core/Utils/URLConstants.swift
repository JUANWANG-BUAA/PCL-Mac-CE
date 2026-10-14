//
//  URLConstants.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/8.
//

import Foundation

public struct URLConstants {
    public static let contentsURL: URL = Bundle.main.bundleURL.appending(path: "Contents")
    public static let resourcesURL: URL = contentsURL.appending(path: "Resources")

    /// 测试进程（`PCL_MAC_TESTING=1`，由 xctestplan 注入）与生产环境隔离：
    /// 使用独立的数据目录，避免测试轮转生产日志、写入生产 Temp 与缓存。
    private static let isTesting: Bool = ProcessInfo.processInfo.environment["PCL_MAC_TESTING"] == "1"

    public static let applicationSupportURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: isTesting ? "Library/Application Support/PCL.Mac.Refactor/TestHome" : "Library/Application Support/PCL.Mac.Refactor")
    public static let logsDirectoryURL: URL = applicationSupportURL.appending(path: "Logs")
    public static let configURL: URL = applicationSupportURL.appending(path: "config.json")
    public static let cacheURL: URL = applicationSupportURL.appending(path: "Caches")
    public static let tempURL: URL = applicationSupportURL.appending(path: "Temp")
    /// 普通下载（无实例上下文）的资源存放目录。
    public static let downloadCacheURL: URL = applicationSupportURL.appending(path: "DownloadCache")
    public static let authlibInjectorURL: URL = applicationSupportURL.appending(path: "authlib-injector.jar")
    public static let easyTierURL: URL = applicationSupportURL.appending(path: "EasyTier")

    public static func createDirectories() throws {
        let fileManager: FileManager = .default
        try fileManager.createDirectory(at: applicationSupportURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: downloadCacheURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: easyTierURL, withIntermediateDirectories: true)
    }
}
