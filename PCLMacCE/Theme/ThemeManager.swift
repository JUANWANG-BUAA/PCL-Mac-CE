//
//  ThemeManager.swift
//  PCLMacCE
//

import SwiftUI
import AppKit
import Core

/// 主题管理器：持有当前主题并提供切换与持久化。
///
/// 切换流程：更新 `theme`（触发观察者）→ 写入 `LauncherConfig` → 立即落盘。
/// `RootView` 观察本对象，并在主题变化时以 `.id(theme)` 重建视图树，
/// 使 `Color.colorN` 等静态色板的读取全部刷新。
class ThemeManager: ObservableObject {
    static let shared: ThemeManager = .init()

    @Published private(set) var theme: AppTheme

    private init() {
        self.theme = LauncherConfig.shared.theme
    }

    /// 切换到指定主题并立即持久化。
    func switchTo(_ theme: AppTheme) {
        guard theme != self.theme else { return }
        self.theme = theme
        LauncherConfig.shared.theme = theme
        applyAppearance()
        do {
            try LauncherConfig.save()
        } catch {
            err("保存主题设置失败：\(error.localizedDescription)")
        }
    }

    /// 按主题应用全局外观：Liquid Glass 跟随系统深浅色（解锁深色模式）；
    /// 经典主题固定浅色——其色板按浅色设计，且包含跟随系统外观的 AppKit 控件，需要全局锁定。
    func applyAppearance() {
        NSApplication.shared.appearance = theme.isNativeStyle ? nil : NSAppearance(named: .aqua)
    }
}
