//
//  ThemeManager.swift
//  PCL.Mac
//

import SwiftUI
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
        do {
            try LauncherConfig.save()
        } catch {
            err("保存主题设置失败：\(error.localizedDescription)")
        }
    }
}
