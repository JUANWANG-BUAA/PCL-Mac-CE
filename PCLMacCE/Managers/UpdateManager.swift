//
//  UpdateManager.swift
//  PCLMacCE
//

import Foundation
import AppKit
import Core
import ZIPFoundation

class UpdateManager {
    /// 更新源是否已配置。
    ///
    /// ⚠️ 原更新源随上游关闭（`cylorine.studio` 已下线）。本项目的新更新源
    /// 确定并部署后：把地址登记到 `shared` 的初始化参数，并把此开关改为 `true`。
    public static let isSourceConfigured: Bool = false

    /// 单例；未配置更新源时不携带地址（自更新链路停用，见 `isSourceConfigured`）。
    public static let shared: UpdateManager = .init(nil)

    private let updateMetadataURL: URL?

    private init(_ updateMetadataURL: URL?) {
        self.updateMetadataURL = updateMetadataURL
    }

    public func checkUpdates() async throws -> UpdateModel.Version? {
        if Metadata.debugMode || Metadata.bundleVersion == 0 { return nil }
        guard let updateMetadataURL else {
            throw SimpleError("更新源迁移中，暂无法检查更新。")
        }
        let model: UpdateModel = try await HTTPClient.shared.get(updateMetadataURL, revalidate: true).decode(UpdateModel.self)
        return Metadata.bundleVersion >= model.latestVersion.bundleVersion ? nil : model.latestVersion
    }

    public func installUpdate(_ version: UpdateModel.Version, useMirror: Bool = true) async throws {
        let destination: URL = URLConstants.tempURL.appending(path: "launcher-update-\(version.bundleVersion)")
        let downloadItem: DownloadItem = .init(
            url: useMirror ? version.downloads.mirror : version.downloads.github,
            destination: destination,
            sha1: version.downloads.sha1
        )
        defer { try? FileManager.default.removeItem(at: destination) }
        try await FileDownloader.shared.download(downloadItem)
        try FileManager.default.unzipItem(at: destination, to: destination.deletingLastPathComponent())
        let newBundle: URL = URLConstants.tempURL.appending(path: "PCLMacCE.app")
        if !FileManager.default.fileExists(atPath: newBundle.path) {
            throw SimpleError("更新包格式错误，请手动安装更新。")
        }
        _ = try FileManager.default.replaceItemAt(
            Bundle.main.bundleURL,
            withItemAt: newBundle,
            backupItemName: "PCLMacCE.app.backup",
            options: [.usingNewMetadataOnly]
        )

        log("App Bundle 替换完成，正在重启")
        // 使用 /usr/bin/open 延迟开启新进程，确保同时只有一个进程存在
        let process: Process = .init()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        try process.run()
        await NSApplication.shared.terminate(nil)
    }
}
