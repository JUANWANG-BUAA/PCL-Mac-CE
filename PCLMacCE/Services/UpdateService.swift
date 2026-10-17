//
//  UpdateService.swift
//  PCLMacCE
//

import SwiftUI
import Core

class UpdateService {
    public static let shared: UpdateService = .init()

    private let semaphore: AsyncSemaphore = .init(value: 1)

    /// 检查并执行更新流程。
    /// - Parameter manually: 是否为用户手动触发；手动触发始终走确认对话框，且不受"不再提示"限制。
    public func runInteractiveUpdateFlow(manually: Bool = false) {
        if LauncherConfig.shared.ignoreLauncherUpdates && !manually {
            log("启动器更新被忽略，取消更新检查")
            return
        }
        Task {
            do {
                try await semaphore.wait()
            } catch {
                return
            }
            defer { Task { await semaphore.signal() } }
            if manually {
                hint("正在检查更新……")
            }
            let version: UpdateModel.Version?
            do {
                version = try await UpdateManager.shared.checkUpdates()
            } catch {
                err("检查更新失败：\(error.localizedDescription)")
                if manually {
                    hint("检查更新失败：\(error.localizedDescription)", type: .critical)
                }
                return
            }
            guard let version else {
                if manually {
                    hint("当前使用的是最新版本，无需更新！", type: .finish)
                }
                return
            }

            if LauncherConfig.shared.autoInstallLauncherUpdates && !manually {
                await runAutoUpdateFlow(version: version)
            } else {
                await promptInstallUpdateDialog(version: version, manually: manually)
            }
        }
    }

    /// 自动更新：后台静默下载并校验，之后仅提示重启，由用户决定应用时机。
    private func runAutoUpdateFlow(version: UpdateModel.Version) async {
        do {
            hint("发现新版本 \(version.name)，正在自动下载更新……")
            let prepared: UpdateManager.PreparedUpdate = try await UpdateManager.shared.prepareUpdate(version)
            await promptRestart(for: prepared)
        } catch {
            err("自动下载更新失败：\(error.localizedDescription)")
            hint("自动更新失败：\(error.localizedDescription)", type: .critical)
        }
    }

    /// 手动/未开启自动更新时的确认对话框流程。
    private func promptInstallUpdateDialog(version: UpdateModel.Version, manually: Bool) async {
        let result = await MessageBoxManager.shared.showTextAsync(
            title: "PCLMacCE 有更新可用",
            content: "发现新版本：\(version.name)\n更新摘要：\(version.summary)\n\n是否下载并安装更新？",
            level: .info,
            buttons: [.init(id: 10, label: "查看 Release", type: .normal) {
                NSWorkspace.shared.open(version.releaseURL)
            }, .init(id: 2, label: "不再提示", type: .normal), .no(),
            .yes(label: "下载并安装（\(formatSize(version.size))）", type: .highlight)]
        )

        if result == 2 {
            LauncherConfig.shared.ignoreLauncherUpdates = true
            AppDelegate.saveConfigQuietly()
            return
        }

        if result != 1 {
            if !manually {
                hint("你也可以在设置中手动更新！")
            }
            return
        }

        hint("正在下载并安装更新，完成后 PCLMacCE 会自动重启……")
        do {
            try await UpdateManager.shared.installUpdate(version)
        } catch {
            err("更新启动器失败：\(error.localizedDescription)")
            hint("更新失败：\(error.localizedDescription)", type: .critical)
        }
    }

    /// 更新已下载校验完成后，询问用户是否立即重启应用。
    private func promptRestart(for prepared: UpdateManager.PreparedUpdate) async {
        let hasRunningTasks: Bool = await MainActor.run {
            !TaskManager.shared.tasks.isEmpty
        }
        // 立即替换会中断正在执行的下载/安装任务：本次不打扰，下次启动再提醒
        if hasRunningTasks {
            hint("新版本 \(prepared.version.name) 已就绪；当前有任务正在执行，将在下次启动时再次提醒更新。")
            prepared.discard()
            return
        }
        let gameRunning: Bool = await MainActor.run {
            MinecraftLaunchManager.shared.isRunning
        }
        let result = await MessageBoxManager.shared.showTextAsync(
            title: "更新已就绪",
            content: "新版本 \(prepared.version.name) 已下载并完成验证。\n\n"
                + (gameRunning ? "游戏仍在运行：重启启动器不会影响正在运行的游戏。\n\n" : "")
                + "是否立即重启启动器以完成更新？",
            level: .info,
            .no(label: "稍后"),
            .yes(label: "立即重启", type: .highlight)
        )
        if result == 1 {
            do {
                try await prepared.apply()
            } catch {
                err("应用更新失败：\(error.localizedDescription)")
                hint("应用更新失败：\(error.localizedDescription)", type: .critical)
            }
        } else {
            prepared.discard()
            hint("已保留当前版本，下次启动后会再次检查更新。")
        }
    }

    private func formatSize(_ size: Int) -> String {
        let units: [String] = ["B", "KB", "MB", "GB", "TB"]
        var value: Double = .init(size)
        var unitIndex: Int = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        let formatted: String = .init(format: value < 10 && unitIndex > 0 ? "%.1f" : "%.0f", value)
        return "\(formatted) \(units[unitIndex])"
    }
}
