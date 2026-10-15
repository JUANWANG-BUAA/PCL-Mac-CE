//
//  UpdateService.swift
//  PCLMacCE
//

import SwiftUI
import Core

class UpdateService {
    public static let shared: UpdateService = .init()

    private let semaphore: AsyncSemaphore = .init(value: 1)

    public func runInteractiveUpdateFlow(manually: Bool = false) {
        if LauncherConfig.shared.ignoreLauncherUpdates && !manually {
            log("启动器更新被忽略，取消更新检查")
            return
        }
        guard isUpdateSourceAvailable(manually: manually) else { return }
        Task {
            await semaphore.wait()
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

            let result = await MessageBoxManager.shared.showTextAsync(
                title: "PCLMacCE 有更新可用",
                content: "发现新版本：\(version.name)\n更新摘要：\(version.summary)\n\n是否下载并安装更新？",
                level: .info,
                buttons: version.updateLogLinks.enumerated().map { index, link in
                    return .init(id: index + 10, label: link.name, type: .normal) {
                        NSWorkspace.shared.open(link.url)
                    }
                } + [.init(id: 2, label: "不再提示", type: .normal), .no(), .yes(label: "下载并安装（\(formatSize(version.downloads.size))）", type: .highlight)]
            )

            if result == 2 {
                LauncherConfig.shared.ignoreLauncherUpdates = true
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
                let useMirror = await LocaleUtils.isInChinaMainland(strict: false)
                try await UpdateManager.shared.installUpdate(version, useMirror: useMirror)
            } catch {
                err("更新启动器失败：\(error.localizedDescription)")
                hint("更新失败：\(error.localizedDescription)", type: .critical)
            }
        }
    }

    /// 更新源是否可用（原上游源已随站点关闭失效）：
    /// 不可用时跳过整个流程、不发起请求；手动检查时明确告知。
    private func isUpdateSourceAvailable(manually: Bool) -> Bool {
        guard UpdateManager.isSourceConfigured else {
            log("更新源未配置，跳过更新检查")
            if manually {
                hint("启动器更新服务暂未配置（更新源迁移中）", type: .info)
            }
            return false
        }
        return true
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
