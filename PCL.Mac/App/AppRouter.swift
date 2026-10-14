//
//  AppRouter.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/9.
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
    case launch, download, multiplayer, settings, more, tasks

    // 启动页面的子页面
    case instanceList(repositoryId: UUID), instanceSettings(id: String)

    // 实例设置页面的子页面
    case instanceConfig(id: String), installedResources(id: String, type: ResourceType)

    // 下载页面的子页面
    case minecraftDownload, minecraftInstallOptions(version: VersionManifest.Version)
    /// 资源搜索页（Mod / 资源包 / 光影包 / 整合包），`context` 区分普通下载与实例定向下载。
    case resourceDownload(type: ResourceType, context: InstallContext)
    case projectInstall(project: ProjectListItemModel, context: InstallContext)

    // 联机页面的子页面
    case multiplayerSub, multiplayerSettings

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
    private static let rootRoutes: [AppRoute] = [.launch, .download, .multiplayer, .settings, .more]

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
        if newRoot == .multiplayer { append(.multiplayerSub) }
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
        case .multiplayerSub:
            MultiplayerPage()
        case .multiplayerSettings:
            MultiplayerSettingsPage()
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

struct AppSidebarView: View {
    @EnvironmentObject private var instanceManager: InstanceManager
    @ObservedObject private var router: AppRouter = .shared
    @State private var width: CGFloat = 0
    @State private var animationProgress: Double = 0

    init() {}

    var sidebar: any Sidebar {
        switch router.last {
        case .launch: LaunchSidebar(instanceManager: instanceManager)
        case .instanceList: InstanceListSidebar(instanceManager: instanceManager)
        case .instanceSettings(let id), .instanceConfig(let id), .installedResources(let id, _): InstanceSettingsSidebar(id: id)
        case .minecraftDownload, .resourceDownload: DownloadSidebar()
        case .multiplayer, .multiplayerSub, .multiplayerSettings: MultiplayerSidebar()
        case .settings, .launcherSettings, .javaSettings, .otherSettings: SettingsSidebar()
        case .more, .about, .toolbox: MoreSidebar()
        case .tasks: TasksSidebar()
        default: EmptySidebar()
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(ThemeManager.shared.theme.sidebarBackground)
                .frame(width: width)
                .shadow(radius: 2)
                .zIndex(10)

            AnyView(sidebar)
                .opacity(animationProgress)
                .scaleEffect(animationProgress * 0.04 + 0.96)
                .zIndex(11)
                .frame(width: sidebar.width)
        }
        .onAppear {
            width = sidebar.width
            // 当前一定是启动页面，直接开始动画
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: sidebar.width) { newWidth in
            withAnimation(.spring(response: 0.16, dampingFraction: 1.0)) {
                width = newWidth
            }
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
