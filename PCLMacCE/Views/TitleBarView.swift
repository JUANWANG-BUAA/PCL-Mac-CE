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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var router: AppRouter = .shared
    @ObservedObject private var flagsManager: FlagsManager = .shared

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        ZStack(alignment: .leading) {
            if !isNative {
                Rectangle()
                    .fill(.blue)
            } else {
                GlassSidebarBackground()
            }
            Group {
                if router.isSubPage {
                    HStack {
                        WindowButton(.btnBack) {
                            router.removeLast()
                        }
                        MyText(router.title, size: 16, color: isNative ? .primary : .white)
                    }
                } else {
                    HStack {
                        Text("PCL Mac CE")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isNative ? Color.primary : .white)

                        if Metadata.debugMode {
                            MyTag("Debug", backgroundColor: .green)
                        }
                    }
                    HStack {
                        Spacer()
                        navigationButtons
                        Spacer()
                    }
                }
            }
            // 原生风格下交通灯更靠右，加大左侧留白避免 logo 与绿灯重叠
            .padding(.leading, isNative ? 84 : 65)
        }
        .frame(height: 48)
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
                    .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.6), value: selectedIndex)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        Button {
            router.setRoot(route)
        } label: {
            ZStack {
                if isNative {
                    Capsule()
                        .fill(hovered && !isRoot ? Color.primary.opacity(0.08) : .clear)
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
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isRoot ? [.isSelected] : [])
        .onHover { hovered in
            self.hovered = hovered
        }
        .animation(reduceMotion ? nil : (isNative ? nil : .easeInOut(duration: 0.2)), value: isRoot)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: hovered)
    }

    private var foregroundColor: Color {
        if ThemeManager.shared.theme.isNativeStyle {
            // 文字随系统浅色 / 深色外观变化。
            if isRoot { return .primary }
            return hovered ? .primary : .primary.opacity(0.8)
        }
        return isRoot ? .color2 : .white
    }

    private var backgroundColor: Color {
        // 经典主题：选中为白色胶囊，悬停半透明白
        .white.opacity(isRoot ? 1 : hovered ? 0.25 : 0)
    }
}
