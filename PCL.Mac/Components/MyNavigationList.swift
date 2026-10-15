//
//  MyNavigationList.swift
//  PCL.Mac
//

import SwiftUI

/// 原生风格侧栏菜单行的尺寸（选中胶囊按同一套常量计算滑动位置）。
private enum NavigationRowMetrics {
    static let height: CGFloat = 34
    static let horizontalInset: CGFloat = 8
}

struct MyNavigationList: View {
    @ObservedObject private var router: AppRouter = .shared
    private let routes: [Route]
    private let performRefresh: ((AppRoute) -> Void)?

    init(_ routes: Route..., performRefresh: ((AppRoute) -> Void)? = nil) {
        self.init(routeList: routes, performRefresh: performRefresh)
    }

    init(routeList: [Route], performRefresh: ((AppRoute) -> Void)? = nil) {
        self.routes = routeList
        self.performRefresh = performRefresh
    }

    /// 当前选中项在列表中的位置。
    private var selectedIndex: Int? {
        routes.firstIndex { $0.route == router.last }
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        VStack(alignment: .leading, spacing: 0) {
            ForEach(routes, id: \.route) { route in
                RouteView(route: route, refresh: performRefresh)
                    .onTapGesture {
                        if router.last != route.route {
                            router.removeLast()
                            router.append(route.route)
                        }
                    }
            }
        }
        .background(alignment: .topLeading) {
            if isNative, let selectedIndex {
                // 选中：与顶栏选中一致的 Liquid Glass 胶囊（不额外加深色色调），
                // 按索引做 `offset` 位移并挂带回弹的 spring 动画（"跃动"的液体滑动）
                Capsule()
                    .fill(.clear)
                    .glassHighlight(true, in: Capsule())
                    // 强制浅色外观：玻璃观感与顶栏选中胶囊保持一致
                    .environment(\.colorScheme, .light)
                    .frame(height: NavigationRowMetrics.height)
                    .padding(.horizontal, NavigationRowMetrics.horizontalInset)
                    .offset(y: CGFloat(selectedIndex) * NavigationRowMetrics.height)
                    .animation(.spring(response: 0.36, dampingFraction: 0.6), value: selectedIndex)
            }
        }
    }

    struct Route {
        let route: AppRoute
        let image: ImageResource?
        let text: String

        init(_ route: AppRoute, _ image: ImageResource?, _ text: String) {
            self.route = route
            self.image = image
            self.text = text
        }
    }
}

private struct RouteView: View {
    @ObservedObject private var router: AppRouter = .shared
    @State private var hovered: Bool = false
    @State private var lastRefresh: Date = .distantPast
    private let route: AppRoute
    private let image: ImageResource?
    private let label: String
    private let refresh: ((AppRoute) -> Void)?

    /// 选中状态直接由路由派生（而不是 `@State` + `onChange`）：
    /// `onChange` 的更新发生在动画事务之外，会导致选中胶囊不滑动；派生计算才能随 `router.last` 一起动画。
    private var selected: Bool { router.last == route }

    init(route: MyNavigationList.Route, refresh: ((AppRoute) -> Void)?) {
        self.route = route.route
        self.image = route.image
        self.label = route.text
        self.refresh = refresh
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        HStack(spacing: isNative ? 8 : 11) {
            if !isNative {
                RoundedRectangle(cornerRadius: 2)
                    .fill(selected ? Color.color3 : .clear)
                    .frame(width: 4, height: selected ? 24 : 10)
            }
            if let image {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isNative ? 22 : 20, height: isNative ? 22 : 20)
            }
            Text(label)
                .font(.app(isNative ? 15 : 14))
                .lineLimit(1)
            if selected, hovered, let refresh {
                Spacer(minLength: 0)
                Image(.iconRefresh)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13)
                    .contentShape(.rect)
                    .onTapGesture {
                        if Date.now.timeIntervalSince(lastRefresh) > 0.5 {
                            lastRefresh = Date.now
                            refresh(route)
                        }
                    }
                    .padding(.trailing, 6)
            }
        }
        .padding(.horizontal, isNative ? 8 : 0)
        .frame(height: isNative ? NavigationRowMetrics.height : 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isNative {
                if hovered, !selected {
                    // 悬停：白色半透明填充（与顶栏按钮一致的悬停语言）
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                }
            } else if hovered {
                Rectangle()
                    .fill(Color.color2.opacity(0.1))
            }
        }
        .foregroundStyle(
            isNative
                ? Color.white
                : (selected ? Color.color3 : .color1)
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.1), value: hovered)
        .animation(isNative ? nil : .easeOut(duration: 0.15), value: selected)
        // 外层留白：玻璃胶囊在侧栏内缩，不贴窗口边缘
        .padding(.horizontal, isNative ? NavigationRowMetrics.horizontalInset : 0)
    }
}

#Preview {
    MyNavigationList(
        .init(.launch, .iconLaunchPage, "启动")
    )
    .frame(width: 150)
    .padding()
    .background(.white)
}
