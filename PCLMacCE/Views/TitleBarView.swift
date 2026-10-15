//
//  TitleBarView.swift
//  PCLMacCE
//

import SwiftUI
import Core

/// 原生风格顶栏导航按钮的尺寸（选中胶囊按同一套常量计算滑动位置）。
private enum NavigationButtonMetrics {
    static let width: CGFloat = 88
    static let height: CGFloat = 30
    static let spacing: CGFloat = 2
    static let padding: CGFloat = 4
}

struct TitleBarView: View {
    @ObservedObject private var router: AppRouter = .shared
    @ObservedObject private var flagsManager: FlagsManager = .shared
    /// 侧栏宽度（含切页动画中间值）：与侧栏玻璃共享同一数值，保证分界线始终贴合玻璃边缘。
    @ObservedObject private var layoutState: SidebarLayoutState = .shared

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        ZStack(alignment: .leading) {
            if !isNative {
                Rectangle()
                    .fill(.blue)
            } else {
                // 原生风格：侧栏玻璃延伸到顶——左段与侧栏同色（深色），交通灯与 logo
                // 落在同一材质的延伸面上（Finder / 邮件式的一体感），消除"顶栏浅、侧栏深"
                // 在 y=48 处的横向色阶断层；右段保持浅色玻璃，导航按钮在任何壁纸上都保持可读。
                HStack(spacing: 0) {
                    GlassSidebarBackground(dark: true)
                        .frame(width: layoutState.width)
                    GlassSidebarBackground()
                }
                .overlay(alignment: .leading) {
                    // 侧栏 / 内容区分界线在顶栏中的延续（与侧栏的白色细分隔线同色）
                    if layoutState.width > 0 {
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: layoutState.width)
                            Rectangle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 0.5)
                        }
                    }
                }
            }
            Group {
                if router.isSubPage {
                    HStack {
                        WindowButton(.btnBack) {
                            router.removeLast()
                        }
                        MyText(router.title, size: 16, color: isNative ? .primary : .white)
                    }
                    .environment(\.colorScheme, leftChromeScheme)
                } else {
                    HStack {
                        Image(.iconTitleLogo)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(isNative ? Color.primary : .white)
                            .frame(height: 19)
                        MyTag("Mac", labelColor: isNative ? .primary : .color2, backgroundColor: isNative ? Color.primary.opacity(0.22) : .white)

                        if Metadata.debugMode {
                            MyTag("Debug", backgroundColor: .green)
                        }
                    }
                    .environment(\.colorScheme, leftChromeScheme)
                    HStack {
                        Spacer()
                        if isNative {
                            // 悬停/选中态用整组深色玻璃胶囊承载：白色标签在任何壁纸上都清晰可读；
                            // PCL 经典主题保持原有设计（蓝条 + 按钮自身底色），不加胶囊。
                            navigationButtons
                                .glassBackground(in: Capsule(), tint: .black.opacity(0.38))
                        } else {
                            navigationButtons
                        }
                        Spacer()
                    }
                }
            }
            // 原生风格下交通灯更靠右，加大左侧留白避免 logo 与绿灯重叠
            .padding(.leading, isNative ? 84 : 65)
        }
        .frame(height: 48)
    }

    /// 顶栏左侧内容的着色外观。
    ///
    /// 原生风格下左段是深色玻璃（侧栏延伸到顶）：语义色（`.primary`、`Color.primary`）
    /// 需按深色外观解析为白色前景——与侧栏强制 `.dark` 的做法一致（见 `AppSidebarView`）。
    /// 无侧栏的子页（安装页等）左段仍是浅色玻璃，维持默认浅色外观；经典主题不受影响。
    private var leftChromeScheme: ColorScheme {
        ThemeManager.shared.theme.isNativeStyle && layoutState.width > 0 ? .dark : .light
    }

    /// 导航项定义（数组顺序即选中胶囊的滑动位置）。
    private var navigationItems: [NavigationItem] {
        var items: [NavigationItem] = [
            .init("启动", .iconLaunchPage, .launch),
            .init("下载", .iconDownloadPage, .download)
        ]
        items.append(.init("设置", .iconSettingsPage, .settings))
        items.append(.init("更多", .iconMorePage, .more))
        return items
    }

    /// 当前选中项在导航组中的位置。
    private var selectedIndex: Int? {
        navigationItems.firstIndex { $0.route == router.root }
    }

    /// 顶栏导航按钮组。
    ///
    /// 原生风格的选中胶囊是组内唯一的一层玻璃：按索引做 `offset` 位移并挂 spring 动画
    /// （不依赖匹配几何，动画稳定、也不随路由重建）；经典主题保持按钮各自的白底胶囊。
    private var navigationButtons: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        return HStack(spacing: isNative ? NavigationButtonMetrics.spacing : 8) {
            ForEach(navigationItems, id: \.route) { item in
                PageButton(item.label, item.icon, item.route)
            }
        }
        .padding(isNative ? NavigationButtonMetrics.padding : 0)
        .background(alignment: .topLeading) {
            if isNative, let selectedIndex {
                Capsule()
                    .fill(.clear)
                    .glassHighlight(true, in: Capsule(), fallbackTint: .black.opacity(0.15))
                    .frame(width: NavigationButtonMetrics.width, height: NavigationButtonMetrics.height)
                    .offset(
                        x: NavigationButtonMetrics.padding
                            + CGFloat(selectedIndex) * (NavigationButtonMetrics.width + NavigationButtonMetrics.spacing),
                        y: NavigationButtonMetrics.padding
                    )
                    .animation(.spring(response: 0.36, dampingFraction: 0.6), value: selectedIndex)
            }
        }
    }

    private struct NavigationItem {
        let label: String
        let icon: ImageResource
        let route: AppRoute

        init(_ label: String, _ icon: ImageResource, _ route: AppRoute) {
            self.label = label
            self.icon = icon
            self.route = route
        }
    }
}

private struct PageButton: View {
    @ObservedObject private var router: AppRouter = .shared
    @State private var hovered: Bool = false
    private var isRoot: Bool { router.root == route }
    private let label: String
    private let icon: ImageResource
    private let route: AppRoute

    init(_ label: String, _ icon: ImageResource, _ route: AppRoute) {
        self.label = label
        self.icon = icon
        self.route = route
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        ZStack {
            if isNative {
                // 选中背景由导航组统一的滑动胶囊承载，这里只画悬停反馈
                Capsule()
                    .fill(hovered && !isRoot ? Color.white.opacity(0.1) : .clear)
            } else {
                RoundedRectangle(cornerRadius: 13)
                    .fill(backgroundColor)
            }
            HStack(spacing: 7) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isNative ? 17 : 16)
                    .foregroundStyle(foregroundColor)
                MyText(label, size: isNative ? 15 : 14, color: foregroundColor)
            }
        }
        .frame(
            width: isNative ? NavigationButtonMetrics.width : 78,
            height: isNative ? NavigationButtonMetrics.height : 27
        )
        .contentShape(Rectangle())
        .onHover { hovered in
            self.hovered = hovered
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if router.root != route {
                        router.setRoot(route)
                    }
                }
        )
        .animation(isNative ? nil : .easeInOut(duration: 0.2), value: isRoot)
        .animation(.easeInOut(duration: 0.2), value: hovered)
    }

    private var foregroundColor: Color {
        if ThemeManager.shared.theme.isNativeStyle {
            // 深色玻璃胶囊上统一使用白色字体（选中为纯白，未选中略降透明度，悬停提亮）
            if isRoot { return .white }
            return hovered ? .white : Color.white.opacity(0.85)
        }
        return isRoot ? .color2 : .white
    }

    private var backgroundColor: Color {
        // 经典主题：选中为白色胶囊，悬停半透明白
        .white.opacity(isRoot ? 1 : hovered ? 0.25 : 0)
    }
}
