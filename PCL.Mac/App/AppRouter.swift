//
//  AppRouter.swift
//  PCL.Mac
//

import SwiftUI
import Core

/// 资源下载的上下文，区分「普通下载」与「实例定向下载」两种模式。
enum InstallContext: Hashable, Equatable, CustomStringConvertible {
    /// 普通下载：不预设目标实例，可选择下载到缓存或安装时再选实例。
    case general
    /// 实例定向下载：已锁定目标实例（`id` 为实例目录名）。
    case instance(id: String)

    var description: String {
        switch self {
        case .general: "general"
        case .instance(let id): "instance:\(id)"
        }
    }
}

enum AppRoute: Identifiable, Hashable, Equatable {
    // 根页面
    case launch, download, settings, more, tasks

    // 启动页面的子页面
    case instanceList(repositoryId: UUID), instanceSettings(id: String)

    // 实例设置页面的子页面
    case instanceConfig(id: String), installedResources(id: String, type: ResourceType)

    // 下载页面的子页面
    case minecraftDownload, minecraftInstallOptions(version: VersionManifest.Version)
    /// 资源搜索页（Mod / 资源包 / 光影包 / 整合包），`context` 区分普通下载与实例定向下载。
    case resourceDownload(type: ResourceType, context: InstallContext)
    case projectInstall(project: ProjectListItemModel, context: InstallContext)

    // 设置页面的子页面
    case launcherSettings, javaSettings, otherSettings

    // 更多页面的子页面
    case about, toolbox

    var id: String { stringValue }

    var stringValue: String {
        switch self {
        default: String(describing: self)
        }
    }
}

@MainActor
class AppRouter: ObservableObject {
    static let shared: AppRouter = .init()
    private static let rootRoutes: [AppRoute] = [.launch, .download, .settings, .more]

    @Published private(set) var path: [AppRoute] = [.launch]

    /// 当前子页面的标题
    var title: String {
        switch last {
        case .tasks: "任务列表"
        case .instanceList: "实例列表"
        case .instanceSettings(let id), .instanceConfig(let id), .installedResources(let id, _): "实例设置 - \(id)"
        case .minecraftInstallOptions(let version): "游戏安装 - \(version.id)"
        case .projectInstall(let project, _): "资源下载 - \(project.title)"
        default: "错误：当前页面（\(last)）没有标题，请报告此问题！"
        }
    }

    /// 当前页面是不是子页面（需要显示返回键和标题，隐藏导航按钮）
    var isSubPage: Bool {
        switch last {
        case .tasks: true
        case .instanceList: true
        case .instanceSettings, .instanceConfig, .installedResources: true
        case .minecraftInstallOptions: true
        case .projectInstall: true
        default: false
        }
    }

    var last: AppRoute { path[path.count - 1] }
    var root: AppRoute { path[0] }

    func setRoot(_ newRoot: AppRoute) {
        path = [newRoot]
        // 各根页面的默认子页面
        if newRoot == .download { append(.minecraftDownload) }
        if newRoot == .settings { append(.launcherSettings) }
        if newRoot == .more { append(.about) }
    }

    func append(_ route: AppRoute) {
        path.append(route)
        if case .instanceSettings(let id) = route { append(.instanceConfig(id: id)) }
    }

    func removeLast() {
        if path.count > 1 {
            path.removeLast()
            if case .instanceSettings = last { removeLast() }
        }
    }

    private init() {}
}

struct AppRouterView: View {
    @ObservedObject private var router: AppRouter = .shared
    @EnvironmentObject private var instanceManager: InstanceManager

    var body: some View {
        switch router.last {
        case .launch:
            LaunchPage()
        case .minecraftDownload:
            MinecraftDownloadPage()
        case .minecraftInstallOptions(let version):
            MinecraftInstallOptionsPage(instanceManager: instanceManager, version: version)
        case .resourceDownload(let type, let context):
            ResourcesSearchPage(type: type, context: context)
                .id("\(type.rawValue)@\(context)")
        case .projectInstall(let project, let context):
            ResourceInstallPage(instanceManager: instanceManager, project: project, context: context)
                .id("\(project.id)@\(context)")
        case .tasks:
            TasksPage()
        case .instanceList(let repositoryId):
            InstanceListPage(instanceManager: instanceManager, repositoryId: repositoryId)
                .id(repositoryId)
        case .launcherSettings:
            LauncherSettingsPage()
        case .javaSettings:
            JavaSettingsPage()
        case .otherSettings:
            OtherSettingsPage()
        case .about:
            AboutPage()
        case .toolbox:
            ToolboxPage()
        case .instanceConfig(let id):
            InstanceConfigPage(instanceManager: instanceManager, id: id)
        case .installedResources(let id, let type):
            InstalledResourcesPage(instanceManager: instanceManager, id: id, type: type)
                .id(router.last)
        default:
            Spacer()
        }
    }
}

/// 侧栏布局状态：顶栏分界线与侧栏玻璃共用的"当前侧栏宽度"。
///
/// 侧栏宽度随路由切换做动画；若顶栏各自读取静态宽度，动画期间分界线会与玻璃边缘错位。
/// 共享同一数值后，`withAnimation` 事务会同时驱动两处动画，分界线始终贴合玻璃边缘。
@MainActor
final class SidebarLayoutState: ObservableObject {
    static let shared: SidebarLayoutState = .init()

    @Published private(set) var width: CGFloat = AppSidebarView.sidebarWidth(for: .launch)

    private init() {}

    /// 更新宽度；`animated` 为 `false` 用于首次出现（避免从 0 滑出）。
    func updateWidth(_ newWidth: CGFloat, animated: Bool = true) {
        guard animated else {
            width = newWidth
            return
        }
        withAnimation(ThemeManager.shared.theme.isNativeStyle
            ? .spring(response: 0.28, dampingFraction: 0.9)
            : .spring(response: 0.16, dampingFraction: 1.0)) {
            width = newWidth
        }
    }
}

struct AppSidebarView: View {
    @EnvironmentObject private var instanceManager: InstanceManager
    @ObservedObject private var router: AppRouter = .shared
    @ObservedObject private var layoutState: SidebarLayoutState = .shared
    @State private var animationProgress: Double = 0

    init() {}

    /// 当前路由对应的侧栏宽度。
    /// 侧栏宽度的单一事实来源：顶栏绘制"侧栏延伸到顶"的分层背景也读取本映射。
    static func sidebarWidth(for route: AppRoute) -> CGFloat {
        switch route {
        case .launch: 285
        case .instanceList: 300
        case .instanceSettings, .instanceConfig, .installedResources: 140
        case .minecraftDownload, .resourceDownload: 150
        case .settings, .launcherSettings, .javaSettings, .otherSettings: 140
        case .more, .about, .toolbox: 140
        case .tasks: 220
        // 其余页面（安装页/项目详情等）无侧栏，与 `sidebar` 的 default 分支一致
        default: 0
        }
    }

    /// 当前路由对应的侧栏视图。
    ///
    /// 使用 `@ViewBuilder` 而非 `AnyView`：避免类型擦除导致侧栏子树在每次求值时被整体重建，
    /// 同时不再为了读取宽度而重复实例化侧栏。
    @ViewBuilder
    private var sidebar: some View {
        switch router.last {
        case .launch: LaunchSidebar(instanceManager: instanceManager)
        case .instanceList: InstanceListSidebar(instanceManager: instanceManager)
        case .instanceSettings(let id), .instanceConfig(let id), .installedResources(let id, _): InstanceSettingsSidebar(id: id)
        case .minecraftDownload, .resourceDownload: DownloadSidebar()
        case .settings, .launcherSettings, .javaSettings, .otherSettings: SettingsSidebar()
        case .more, .about, .toolbox: MoreSidebar()
        case .tasks: TasksSidebar()
        default: EmptySidebar()
        }
    }

    var body: some View {
        let sidebarWidth = Self.sidebarWidth(for: router.last)
        ZStack(alignment: .leading) {
            Group {
                if ThemeManager.shared.theme.isNativeStyle {
                    // 原生风格：深色玻璃侧栏（承载白色文字）
                    GlassSidebarBackground(dark: true)
                } else {
                    Rectangle()
                        .fill(ThemeManager.shared.theme.sidebarBackground)
                }
            }
            .frame(width: layoutState.width)
            .shadow(radius: ThemeManager.shared.theme.isNativeStyle ? 0 : 2)
            .overlay(alignment: .trailing) {
                // 原生风格：侧栏与内容区的细分隔线（材质色差微弱时提供明确分界）
                if ThemeManager.shared.theme.isNativeStyle {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 0.5)
                }
            }
            .zIndex(10)

            sidebar
                // 原生风格：侧栏为深色玻璃，强制深色外观使语义色（.primary/.secondary）与材质白字适配
                .environment(\.colorScheme, ThemeManager.shared.theme.isNativeStyle ? .dark : .light)
                .opacity(animationProgress)
                .scaleEffect(animationProgress * 0.04 + 0.96)
                .zIndex(11)
                // 内容按最终宽度布局，外层用动画中的宽度从左向右显示（避免文字重排导致的跳动）
                .frame(width: sidebarWidth, alignment: .leading)
                .frame(width: layoutState.width, alignment: .leading)
                .clipped()
        }
        .onAppear {
            layoutState.updateWidth(sidebarWidth, animated: false)
            // 当前一定是启动页面，直接开始动画
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: router.last) { _ in
            // 侧栏宽度平滑过渡（顶栏分界线读取同一共享值，保持一致）
            layoutState.updateWidth(Self.sidebarWidth(for: router.last))
            switch router.last {
            case .launch, .tasks:
                animationProgress = 0.0
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    animationProgress = 1.0
                }
            default:
                break
            }
        }
    }
}
