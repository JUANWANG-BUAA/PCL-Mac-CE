//
//  EasyTierManager.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/1/15.
//

import Foundation
import SwiftScaffolding
import Core
import ZIPFoundation

class EasyTierManager {
    public static let shared: EasyTierManager = .init()

    private let coreURL: URL = URLConstants.easyTierURL.appending(path: "easytier-core")
    private let cliURL: URL = URLConstants.easyTierURL.appending(path: "easytier-cli")
    private let logURL: URL = URLConstants.logsDirectoryURL.appending(path: "easytier.log")

    private let architecture: String
    /// gitee 镜像源下载项。
    ///
    /// ⚠️ 该搬运仓库已下线（404），保留为首选以兼容其恢复；下载失败时自动回退到官方 GitHub Release。
    private let mirrorDownloadItems: [ComponentType: DownloadItem]
    /// 官方 GitHub Release 压缩包（内含 `easytier-macos-<arch>/` 目录下的裸二进制）。
    private let officialArchiveURL: URL

    private var isEasyTierInstalled: Bool?
    private var easyTierInstances: [EasyTier] = []

    private init() {
        self.architecture = Architecture.systemArchitecture() == .arm64 ? "aarch64" : "x86_64"
        self.mirrorDownloadItems = [
            .cli: .init(
                url: APIEndpoints.EasyTier.giteeMirror(component: "cli", architecture: architecture),
                destination: cliURL,
                sha1: architecture == "aarch64" ? "6fced91a4aeb4c9d1776704a6d00438331408056" : "4dd10266baa8b70b64a953da78632e2d0d581ca9"
            ),
            .core: .init(
                url: APIEndpoints.EasyTier.giteeMirror(component: "core", architecture: architecture),
                destination: coreURL,
                sha1: architecture == "aarch64" ? "bcc229e65d2652e538efd59ea88e21a7e6ff2375" : "3185b21c0f3085e313d89fa32a32b7c1013ff1de"
            )
        ]
        self.officialArchiveURL = APIEndpoints.EasyTier.officialRelease(architecture: architecture)
    }

    public func makeEasyTier(peers: [String]) -> EasyTier {
        easyTierInstances.removeAll { $0.process == nil }
        let options: [EasyTier.Option] = [
            .p2pOnly,
            .enableKcpProxy, .latencyFirst, .multiThread, .compression(algorithm: "zstd")
        ] + peers.map(EasyTier.Option.peer(address:))

        let instance: EasyTier = .init(coreURL: coreURL, cliURL: cliURL, logURL: logURL, options: options)
        easyTierInstances.append(instance)
        return instance
    }

    public func terminateAll() {
        easyTierInstances.forEach { $0.terminate() }
    }

    /// 判断是否已经安装 EasyTier。
    public func isInstalled(refresh: Bool = false) -> Bool {
        if let isEasyTierInstalled, !refresh {
            return isEasyTierInstalled
        }
        let installed: Bool = autoreleasepool { checkSingle(type: .cli) && checkSingle(type: .core) }
        isEasyTierInstalled = installed
        return installed
    }

    /// 如果没有安装 EasyTier，提示用户安装。
    /// - Returns: 是否未安装 EasyTier。
    public func hintInstall() -> Bool {
        if isInstalled() { return false }
        log("用户未安装 EasyTier")
        MessageBoxManager.shared.showText(
            title: "错误",
            content: "你需要安装 EasyTier 才能使用这个功能！",
            level: .error,
            .yes(label: "安装", type: .highlight),
            .no()
        ) { result in
            if result == 1 {
                let task: MyTask = self.makeInstallTask()
                TaskManager.shared.execute(task: task)
                AppRouter.shared.append(.tasks)
            }
        }
        return true
    }

    /// 删除 EasyTier。
    public func delete() {
        if !isInstalled() {
            hint("你还没有安装 EasyTier！", type: .critical)
            return
        }
        do {
            for type in ComponentType.allCases {
                try FileManager.default.removeItem(at: destination(for: type))
                try? FileManager.default.removeItem(at: officialSourceMarker(for: type))
            }
            hint("删除成功！", type: .finish)
        } catch {
            hint("删除 EasyTier 失败：\(error.localizedDescription)", type: .critical)
        }
        _ = isInstalled(refresh: true)
    }

    /// 创建一个安装任务。
    public func makeInstallTask() -> MyTask<EmptyModel> {
        return .init(
            name: "安装 EasyTier",
            .init(0, "下载 EasyTier") { task, _ in
                do {
                    try await self.downloadFromMirror(progressHandler: task.setProgress(_:))
                } catch {
                    warn("镜像源下载 EasyTier 失败（\(error.localizedDescription)），正在回退到官方 GitHub Release")
                    try await self.downloadFromOfficialArchive(progressHandler: task.setProgress(_:))
                }
                for type in ComponentType.allCases {
                    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: self.destination(for: type).path)
                }
            },
            .init(1, "__completion", display: false) { _, _ in
                EasyTierManager.shared.isEasyTierInstalled = true
                if await AppRouter.shared.last == .tasks {
                    await MainActor.run {
                        AppRouter.shared.removeLast()
                    }
                }
            }
        )
    }

    public enum ComponentType: CaseIterable {
        case cli, core
    }

    // MARK: - 下载源

    /// 从 gitee 镜像源并发下载两个裸二进制。
    private func downloadFromMirror(progressHandler: (@MainActor (Double) -> Void)?) async throws {
        // ConcurrentProgressHandler 为 @MainActor 隔离，在主线程创建并开始计算；
        // 进度闭包仅做 UI 赋值，担保跨隔离传递安全
        nonisolated(unsafe) let totalHandler = progressHandler
        let progress: ConcurrentProgressHandler = await MainActor.run {
            let progress = ConcurrentProgressHandler(totalHandler: totalHandler ?? { _ in })
            progress.startCalculate()
            return progress
        }
        let handlers: [ProgressHandlerBox] = await MainActor.run {
            ComponentType.allCases.map { _ in ProgressHandlerBox(handler: progress.handler(withMultiplier: 0.5)) }
        }
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for (type, box) in zip(ComponentType.allCases, handlers) {
                    group.addTask {
                        try await FileDownloader.shared.download(self.mirrorDownloadItems[type]!, progressHandler: box.handler)
                    }
                }
                for try await _ in group { }
            }
        } catch {
            await MainActor.run { progress.stopCalculate() }
            throw error
        }
        await MainActor.run { progress.stopCalculate() }
    }

    /// 从官方 GitHub Release 压缩包下载并提取两个裸二进制。
    private func downloadFromOfficialArchive(progressHandler: (@MainActor (Double) -> Void)?) async throws {
        let archiveURL: URL = URLConstants.tempURL.appending(path: "easytier-macos-\(architecture).zip")
        defer { try? FileManager.default.removeItem(at: archiveURL) }

        let item: DownloadItem = .init(url: officialArchiveURL, destination: archiveURL, checksums: nil)
        try await FileDownloader.shared.download(item, progressHandler: progressHandler)

        let extractURL: URL = URLConstants.tempURL.appending(path: "easytier-extract-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: extractURL) }
        try FileManager.default.unzipItem(at: archiveURL, to: extractURL)

        // 压缩包内为 easytier-macos-<arch>/easytier-{core,cli}
        let rootURL: URL = extractURL.appending(path: "easytier-macos-\(architecture)")
        for type in ComponentType.allCases {
            let source: URL = rootURL.appending(path: type == .cli ? "easytier-cli" : "easytier-core")
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw SimpleError("官方安装包格式错误：找不到 \(source.lastPathComponent)。")
            }
            let destination: URL = self.destination(for: type)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: source, to: destination)
            // 标记来源为官方包：官方产物与镜像源的哈希不保证一致，后续只做可执行检查。
            try Data("official".utf8).write(to: officialSourceMarker(for: type))
            log("已从官方 GitHub Release 提取 \(destination.lastPathComponent)")
        }
    }

    // MARK: - 安装状态检查

    private func destination(for type: ComponentType) -> URL {
        type == .cli ? cliURL : coreURL
    }

    /// 官方包来源标记文件。
    private func officialSourceMarker(for type: ComponentType) -> URL {
        destination(for: type).appendingPathExtension("official-source")
    }

    private func checkSingle(type: ComponentType) -> Bool {
        let destination: URL = self.destination(for: type)
        guard FileUtils.isExecutable(at: destination) else { return false }
        // 官方包产物跳过镜像源哈希校验
        if FileManager.default.fileExists(atPath: officialSourceMarker(for: type).path) {
            return true
        }
        return (try? FileUtils.check(mirrorDownloadItems[type]!)) == true
    }
}

/// 进度闭包仅做 UI 赋值；闭包类型本身非 Sendable，装箱担保跨隔离传递安全。
private struct ProgressHandlerBox: @unchecked Sendable {
    let handler: @MainActor (Double) -> Void
}
