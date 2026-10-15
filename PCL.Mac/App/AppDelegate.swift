//
//  AppDelegate.swift
//  PCL.Mac
//

import Foundation
import AppKit
import Core
import SwiftScaffolding
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    /// 保存配置并忽略失败（用于关键数据变更后的立即落盘）。
    static func saveConfigQuietly() {
        do {
            try LauncherConfig.save()
        } catch {
            err("保存配置失败：\(error.localizedDescription)")
        }
    }

    private var window: AppWindow!
    private lazy var shouldInit: Bool = ProcessInfo.processInfo.environment["PCL_MAC_TESTING"] == nil && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    private var keyMonitor: Any?

    private var instanceManager: InstanceManager!
    private var cancellables: Set<AnyCancellable> = []

    private func executeTask(_ name: String, silent: Bool = false, _ start: @escaping () throws -> Void) {
        do {
            try start()
            if !silent {
                log("\(name)成功")
            }
        } catch {
            err("\(name)失败：\(error.localizedDescription)")
        }
    }

    private func executeAsyncTask(_ name: String, silent: Bool = false, _ start: @escaping () async throws -> Void) {
        Task {
            do {
                try await start()
                if !silent {
                    log("\(name)成功")
                }
            } catch {
                err("\(name)失败：\(error.localizedDescription)")
            }
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 原上游版本（PCL.Mac.Refactor）的数据目录一次性迁移，必须在建目录与加载配置前执行
        URLConstants.migrateLegacyApplicationSupport()
        do {
            try URLConstants.createDirectories()
        } catch {
            let alert = NSAlert()
            alert.messageText = "PCL.Mac 启动失败：创建数据目录失败。"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical

            // 原上游仓库已关闭，不再提供"反馈"跳转；错误详情见日志
            _ = alert.addButton(withTitle: "退出")

            _ = alert.runModal()
            exit(1)
        }
        LogManager.shared.enableLogging()
        log("正在启动 PCL.Mac \(Metadata.appVersion)")

        debug("系统信息：macOS \(ProcessInfo.processInfo.operatingSystemVersionString) \(Architecture.systemArchitecture())")

        _ = Secrets.shared

        DownloadSourceManager.shared = .init(policy: LauncherConfig.shared.downloadSourcePolicy, curseforgeApiKey: Secrets.shared.curseforgeApiKey)

        FlagsManager.shared = .init(enabledFlags: LauncherConfig.shared.enabledFlags)

        JavaManager.shared = .init(customJavaRuntimes: LauncherConfig.shared.customJavaRuntimes)

        executeAsyncTask("刷新地区信息", silent: true) {
            await DownloadSourceManager.shared.refreshRegion()
        }

        executeTask("开启 SwiftScaffolding 日志", silent: true) {
            try SwiftScaffolding.Logger.enableLogging(url: URLConstants.logsDirectoryURL.appending(path: "swift-scaffolding.log"))
        }
        executeTask("清理临时文件") {
            for url in try FileManager.default.contentsOfDirectory(at: URLConstants.tempURL, includingPropertiesForKeys: nil) {
                try FileManager.default.removeItem(at: url)
            }
        }

        do {
            let cacheURL = URLConstants.cacheURL.appending(path: "version_manifest.json")
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                executeTask("从缓存中加载版本列表") {
                    let cachedData = try Data(contentsOf: URLConstants.cacheURL.appending(path: "version_manifest.json"))
                    let manifest = try JSONDecoder.shared.decode(VersionManifest.self, from: cachedData)
                    VersionManifest.shared = manifest
                }
            }
        }
        executeAsyncTask("拉取最新版本列表") {
            try await VersionManifest.load(revalidate: true)
        }

        if shouldInit {
            _ = LauncherConfig.shared
            _ = JavaManager.shared
            executeTask("加载字体") {
                let fontURL: URL = URLConstants.resourcesURL.appending(path: "PCL.ttf")
                var error: Unmanaged<CFError>?
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
                if let error = error?.takeUnretainedValue() { throw error }
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !shouldInit { return }
        log("App 启动完成")
        ResourceCache.shared = .init(cacheDirectory: URLConstants.cacheURL)

        let instanceManager = InstanceManager(
            repositories: LauncherConfig.shared.minecraftRepositories.reduce(into: [:], { $0[$1.id] = $1 }),
            currentRepositoryId: LauncherConfig.shared.currentRepositoryId
        )
        self.instanceManager = instanceManager
        instanceManager.$currentRepositoryId
            .receive(on: DispatchQueue.main)
            .sink { value in
                LauncherConfig.shared.currentRepositoryId = value
                Self.saveConfigQuietly()
            }
            .store(in: &cancellables)
        instanceManager.$repositories
            .receive(on: DispatchQueue.main)
            .sink { value in
                LauncherConfig.shared.minecraftRepositories = Array(value.values)
                Self.saveConfigQuietly()
            }
            .store(in: &cancellables)

        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        self.window = AppWindow(instanceManager: instanceManager)
        self.window.makeKeyAndOrderFront(nil)
        log("成功创建窗口")
        addEscapeMonitor()

        if let loadError = LauncherConfig.loadError {
            MessageBoxManager.shared.showText(
                title: "加载配置文件失败",
                content: "很抱歉，PCL.Mac 无法加载启动器配置文件……\n原因可能是文件损坏、代码破坏性变更，或者权限问题。\nPCL.Mac 创建了一个备份文件（\(LauncherConfig.backupURL.path)）以免配置丢失。\n\n错误信息：\(loadError.localizedDescription)",
                level: .error
            )
        }

        if !LauncherConfig.shared.hasEnteredLauncher {
            MessageBoxManager.shared.showText(
                title: "欢迎使用 PCL.Mac！",
                content: "PCL.Mac 是 Plain Craft Launcher 的非官方衍生版，使用 SwiftUI 框架完全重构了 PCL 以支持 macOS。\n"
                    + "本启动器还处于开发阶段，有许多功能尚未完成，Bug 可能也比较多……\n\n"
                    + "本版本现由 JUANWANG（github.com/JUANWANG-BUAA）独立维护并持续开发；原项目已停止公开开发。",
                level: .info,
                .init(id: 2, label: "开始使用", type: .highlight)
            ) { _ in
                LauncherConfig.shared.hasEnteredLauncher = true
            }
        }
        UpdateService.shared.runInteractiveUpdateFlow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        executeTask("保存资源缓存") {
            try ResourceCache.shared.save()
        }
        executeTask("保存当前仓库") {
            try self.instanceManager.currentRepository.saveAllInstances()
        }
        executeTask("保存启动器配置") {
            LauncherConfig.shared.enabledFlags = FlagsManager.shared.enabledFlags
            try LauncherConfig.save()
        }
    }

    private func addEscapeMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // 弹窗打开时：回车触发主按钮，ESC 触发取消按钮
            if MessageBoxManager.shared.currentMessageBox != nil {
                switch event.keyCode {
                case 36, 76: // Return / Enter（小键盘）
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .messageBoxConfirm, object: nil)
                    }
                    return nil
                case 53: // Escape
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .messageBoxCancel, object: nil)
                    }
                    return nil
                default:
                    return event
                }
            }
            if event.keyCode == 53 {
                // 有下拉弹层打开时：Esc 只关闭弹层，不触发页面返回
                if SelectPopupRegistry.presentedCount > 0 {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .selectPopupCloseAll, object: nil)
                    }
                    return nil
                }
                DispatchQueue.main.async {
                    guard AppRouter.shared.isSubPage else { return }
                    AppRouter.shared.removeLast()
                }
            } else {
                return event
            }
            return nil
        }
    }
}
