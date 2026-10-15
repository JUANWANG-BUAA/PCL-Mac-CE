//
//  Sidebar.swift
//  PCLMacCE
//

import SwiftUI

/// 侧栏视图标记协议。
///
/// 宽度不在此声明：所有侧栏宽度统一由 `AppSidebarView.sidebarWidth(for:)` 映射
/// （顶栏绘制"侧栏延伸到顶"的背景也读取同一映射，保证单一事实来源、避免两处不同步）。
protocol Sidebar: View {}

struct EmptySidebar: Sidebar {
    var body: some View {
        EmptyView()
    }
}
