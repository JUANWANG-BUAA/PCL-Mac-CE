//
//  ResourceInstallPage.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct ResourceInstallPage: View {
    @StateObject private var viewModel: ResourceInstallViewModel
    @StateObject private var instanceVM: InstanceViewModel
    @State private var currentPage: Int = 0
    private let context: InstallContext

    init(instanceManager: InstanceManager, project: ProjectListItemModel, context: InstallContext = .general) {
        self._viewModel = .init(wrappedValue: .init(project: project))
        self._instanceVM = .init(wrappedValue: InstanceViewModel(instanceManager: instanceManager))
        self.context = context
    }

    /// 实例定向模式下的目标实例。
    private var targetInstance: MinecraftInstance? {
        guard case .instance(let id) = context else { return nil }
        return instanceVM.repositories.lazy.compactMap { $0.instance(named: id) }.first
    }

    var body: some View {
        CardContainer {
            modeTip
            MyCard(nil) {
                ProjectListItemView(project: viewModel.project, primary: true)
                HStack {
                    MyButton("Modrinth", type: .highlight) {
                        NSWorkspace.shared.open(WebLinks.modrinthProject(id: viewModel.project.id))
                    }
                    .frame(width: 120)
                    Spacer(minLength: 0)
                }
                .frame(height: 35)
            }
            if viewModel.loaded, let versionList = viewModel.versionList {
                if currentPage == 0, let selectedVersionGroup = viewModel.selectedVersionGroup {
                    versionCard(versionGroup: selectedVersionGroup, isSelected: true, folded: false)
                }
                PaginatedContainer(versionList, id: \.0, currentPage: $currentPage, viewsPerPage: 10) { versionGroup in
                    versionCard(versionGroup: versionGroup, folded: versionList.count == 1 ? false : true)
                }
            } else {
                MyLoading(viewModel: viewModel.loadingVM)
                    .cardIndex(1)
            }
        }
        .task(id: viewModel.project) {
            await loadVersions()
        }
    }

    /// 加载版本列表；失败时提供重试入口。
    private func loadVersions() async {
        do {
            try await viewModel.load(selectedInstance: targetInstance)
        } catch let error where error.isCancellationError {
        } catch {
            err("加载\(viewModel.project.type.localizedName) \(viewModel.project.title) 版本列表失败：\(error)")
            viewModel.loadingVM.fail(with: "加载版本列表失败：\(error.localizedDescription)") {
                Task { await loadVersions() }
            }
        }
    }

    // MARK: - 模式提示条

    /// 下载模式提示条：实例定向模式显示目标实例与退出入口；普通模式说明双通道行为。
    @ViewBuilder
    private var modeTip: some View {
        switch context {
        case .instance:
            if let instance = targetInstance {
                MyTip(
                    text: "实例定向下载：正在为「\(instance.name)」（\(instance.version.id)"
                        + "\(instance.modLoader.map { " · \($0)" } ?? "")）挑选\(viewModel.project.type.localizedName)，"
                        + "列表仅显示兼容版本。",
                    theme: .blue,
                    actionLabel: "退出实例模式"
                ) {
                    exitInstanceMode()
                }
            } else {
                MyTip(text: "目标实例不存在，已按普通下载模式浏览。", theme: .yellow)
            }
        case .general:
            if viewModel.project.type == .modpack {
                MyTip(text: "整合包下载：点击版本后将下载并导入为新实例。", theme: .blue)
            } else {
                MyTip(
                    text: "普通下载：点击版本后可选择下载到缓存，或直接安装到某个实例。",
                    theme: .blue,
                    actionLabel: "打开下载缓存"
                ) {
                    NSWorkspace.shared.open(URLConstants.downloadCacheURL)
                }
            }
        }
    }

    /// 退出实例定向模式，就地切换为普通下载。
    private func exitInstanceMode() {
        AppRouter.shared.removeLast()
        AppRouter.shared.append(.resourceDownload(type: viewModel.project.type, context: .general))
    }

    // MARK: - 版本点击

    private func onVersionTap(_ version: ProjectVersionModel) async throws {
        switch context {
        case .instance:
            // 实例定向：目标已确定，校验后直接安装
            guard let instance = targetInstance else {
                hint("目标实例不存在！", type: .critical)
                return
            }
            try await install(version, to: instance)
        case .general:
            // 普通下载：选择下载到缓存或安装到实例
            let result = await MessageBoxManager.shared.showTextAsync(
                title: "下载 \(viewModel.project.title)",
                content: "\(version.name)（\(version.version)）\n\n选择下载方式：\n· 下载到缓存：保存到「下载缓存」文件夹，之后可手动放入任意实例\n· 安装到实例：选择目标实例后直接安装",
                level: .info,
                .no(),
                .init(id: 2, label: "下载到缓存", type: .highlight),
                .yes(label: "安装到实例…")
            )
            switch result {
            case 2:
                downloadToCache(version)
            case 1:
                guard let instance = await pickInstance() else { return }
                try await install(version, to: instance)
            default:
                return
            }
        }
    }

    /// 校验兼容性并安装到指定实例。
    private func install(_ version: ProjectVersionModel, to instance: MinecraftInstance) async throws {
        do {
            try viewModel.checkInstance(instance, withVersion: version)
        } catch let error as ResourceInstallViewModel.InstanceCheckError {
            log("当前实例不满足该版本要求：\(error.localizedDescription)")
            switch error {
            case .versionUnsupported:
                if await MessageBoxManager.shared.showTextAsync(
                    title: "当前实例不符合要求",
                    content: "\(error.localizedDescription)\n你可以选择继续安装，但游戏可能会发生崩溃或无法正常游玩。\n是否继续安装？",
                    level: .error,
                    .no(),
                    .yes(label: "继续", type: .red)
                ) != 1 {
                    return
                }
            default:
                _ = await MessageBoxManager.shared.showTextAsync(
                    title: "当前实例不符合要求",
                    content: error.localizedDescription,
                    level: .error
                )
                return
            }
        }

        if await MessageBoxManager.shared.showTextAsync(
            title: "确认",
            content: "确定要安装 \(viewModel.project.title) \(version.version) 到「\(instance.name)」吗？",
            level: .info,
            .no(),
            .yes(type: .highlight)
        ) == 1 {
            do {
                let task = try await viewModel.createInstallTask(forVersion: version, to: instance)
                TaskManager.shared.execute(task: task)
                AppRouter.shared.append(.tasks)
            }
        }
    }

    /// 普通下载：下载到下载缓存目录。
    private func downloadToCache(_ version: ProjectVersionModel) {
        do {
            let (task, destination) = try viewModel.createCacheDownloadTask(forVersion: version)
            TaskManager.shared.execute(task: task)
            AppRouter.shared.append(.tasks)
            hint("下载完成后可在「\(destination.deletingLastPathComponent().path)」中找到", type: .finish)
        } catch {
            err("创建下载任务失败：\(error.localizedDescription)")
            hint("创建下载任务失败：\(error.localizedDescription)", type: .critical)
        }
    }

    /// 弹出全部仓库的实例列表供用户选择；没有任何实例时提示并返回 `nil`。
    private func pickInstance() async -> MinecraftInstance? {
        let instances: [(instance: MinecraftInstance, repository: MinecraftRepository)] = instanceVM.repositories
            .compactMap { repository in repository.instances?.values.map { ($0, repository) } }
            .flatMap { $0 }
            .sorted { $0.0.name < $1.0.name }

        guard !instances.isEmpty else {
            hint("请先安装一个实例，再下载\(viewModel.project.type.localizedName)！", type: .critical)
            AppRouter.shared.setRoot(.download)
            AppRouter.shared.append(.minecraftDownload)
            return nil
        }

        let index: Int? = await MessageBoxManager.shared.showListAsync(
            title: "选择要安装到的实例",
            items: instances.map { instance, repository in
                ListItem(
                    image: .system("cube"),
                    name: instance.name,
                    description: "\(repository.name) · \(instance.version.id)\(instance.modLoader.map { " · \($0)" } ?? "")"
                )
            }
        )
        guard let index, instances.indices.contains(index) else { return nil }
        let picked = instances[index]
        instanceVM.switchInstance(to: picked.instance, in: picked.repository)
        return picked.instance
    }

    private func onModpackTap(_ version: ProjectVersionModel) async throws {
        let repository = instanceVM.currentRepository
        guard await MessageBoxManager.shared.showTextAsync(
            title: "确认",
            content: "确定要安装整合包 \(viewModel.project.title) \(version.version) 吗？",
            level: .info,
            .no(),
            .yes(type: .highlight)
        ) == 1 else { return }

        hint("开始下载整合包……")

        let (downloadTask, destination): (MyTask<EmptyModel>, URL)
        do {
            (downloadTask, destination) = try viewModel.createModpackDownloadTask(version)
        } catch {
            err("创建下载任务失败：\(error.localizedDescription)")
            hint("创建下载任务失败：\(error.localizedDescription)", type: .critical)
            return
        }

        let downloadExecutorTask: Task<Void, Error> = TaskManager.shared.execute(task: downloadTask)
        do {
            try await downloadExecutorTask.value
        } catch {
            err("下载整合包失败：\(error.localizedDescription)")
            hint("下载整合包失败：\(error.localizedDescription)", type: .critical)
            return
        }

        let service = ModpackImportService(modpackURL: destination)
        var taskScheduled = false
        defer { if !taskScheduled { service.cleanup() } }

        do {
            let index = try await service.loadAsync()
            guard let name = await MessageBoxManager.shared.showInputAsync(
                title: "安装整合包 - 输入实例名",
                initialContent: index.name
            ) else { return }

            let task = try await service.createImportTask(name: name, repository: repository) { instance in
                instanceVM.switchInstance(to: instance, in: repository)
            }
            TaskManager.shared.execute(task: task) { _ in service.cleanup() }
            taskScheduled = true
        } catch {
            err("安装整合包失败：\(error.localizedDescription)")
            hint("安装整合包失败：\(error.localizedDescription)", type: .critical)
        }
    }

    @ViewBuilder
    private func versionCard(versionGroup: ResourceInstallViewModel.VersionGroup, isSelected: Bool = false, folded: Bool = true) -> some View {
        MyCard((isSelected ? "最佳版本：" : "") + versionGroup.0.description, folded: folded) {
            let dependencies: [ProjectVersionModel.Dependency] = versionGroup.1[0].requiredDependencies
            if !dependencies.isEmpty {
                VStack(alignment: .leading) {
                    MyText("前置资源")
                    VStack(spacing: 0) {
                        ForEach(dependencies) { dependency in
                            ProjectListItemView(project: dependency.project)
                                .onTapGesture {
                                    AppRouter.shared.append(.projectInstall(project: dependency.project, context: context))
                                }
                        }
                    }
                    MyText("版本列表")
                }
            }
            VStack(spacing: 0) {
                ForEach(versionGroup.1) { version in
                    VersionListItemView(version: version)
                        .onTapGesture {
                            log("\(version.name) \(version.version) 被点击")
                            Task {
                                do {
                                    if viewModel.project.type == .modpack {
                                        try await onModpackTap(version)
                                    } else {
                                        try await onVersionTap(version)
                                    }
                                } catch {
                                    err("执行点击回调意外失败：\(error.localizedDescription)")
                                    hint("执行点击回调意外失败：\(error.localizedDescription)", type: .critical)
                                }
                            }
                        }
                }
            }
        }
    }

    private struct VersionListItemView: View {
        private let model: ListItem

        init(version: ProjectVersionModel) {
            self.model = .init(
                image: version.type.icon,
                name: version.name,
                description: "\(version.version)，更新于\(version.datePublished)，\(version.type.localizedName)"
            )
        }

        var body: some View {
            MyListItem(model)
        }
    }
}
