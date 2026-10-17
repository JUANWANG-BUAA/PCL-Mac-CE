//
//  InstalledResourcesPage.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct InstalledResourcesPage: View {
    @StateObject private var viewModel: InstalledResourcesViewModel
    @StateObject private var loadingVM: MyLoadingViewModel

    init(instanceManager: InstanceManager, id: String, type: ResourceType) {
        self._viewModel = .init(wrappedValue: .init(instanceManager: instanceManager, id: id, type: type))
        self._loadingVM = .init(wrappedValue: MyLoadingViewModel(text: "加载中"))
    }

    var body: some View {
        Group {
            if !viewModel.supportMods {
                MyCard(nil) {
                    VStack(spacing: 10) {
                        MyText("该实例不可使用 Mod", size: 19, color: .color3)

                        Rectangle()
                            .fill(Color.color3)
                            .frame(height: 2)

                        MyText("你需要先安装 Forge、Fabric 等 Mod 加载器才能使用 Mod，请在安装实例时选择这些加载器。\n如果你已经安装了 Mod 加载器，那么你很可能选择了错误的实例，请点击实例选择按钮切换实例。")
                            .padding(.vertical, 5)

                        HStack(spacing: 20) {
                            MyButton("转到下载页面", type: .highlight) {
                                AppRouter.shared.setRoot(.download)
                            }
                            .frame(width: 140)
                            MyButton("实例选择") {
                                AppRouter.shared.setRoot(.launch)
                                AppRouter.shared.append(.instanceList(repositoryId: viewModel.currentRepositoryId))
                            }
                            .frame(width: 140)
                        }
                        .frame(height: 35)
                    }
                    .padding(10)
                }
                .padding(40)
            } else {
                CardContainer {
                    if viewModel.type == .shader {
                        // 原站教程链接随上游关闭失效，先只保留提示本身
                        MyTip(text: "光影包需要搭配光影加载器使用。", theme: .blue)
                    }

                    MySearchBox(placeholder: "搜索\(viewModel.type.localizedName)") { keyword in
                        viewModel.setSearchKeyword(keyword)
                    }

                    MyCard(nil) {
                        HStack {
                            MyButton("下载\(viewModel.type.localizedName)", type: .highlight) {
                                downloadMore()
                            }
                            .frame(width: 150)
                            MyButton("打开文件夹") {
                                if let directory = viewModel.directory() {
                                    NSWorkspace.shared.open(directory)
                                }
                            }
                            .frame(width: 120)
                            Spacer(minLength: 0)
                        }
                        .frame(height: 40)
                    }
                    .cardIndex(1)

                    if let resources = viewModel.resources {
                        if resources.isEmpty {
                            // 空态与错误态分离：没有资源不是错误，不显示红叉
                            emptyResourcesCard
                        } else {
                            PaginatedContainer(currentPage: $viewModel.currentPage, pageCount: viewModel.pageCount) { currentPage in
                                MyCard(nil) {
                                    VStack(spacing: 0) {
                                        ForEach(resources, id: \.id) { resource in
                                            ResourceListItem(viewModel: viewModel, resource: resource)
                                        }
                                    }
                                }
                                .onChange(of: currentPage) { _ in
                                    viewModel.updateResources()
                                }
                            }
                        }
                    } else {
                        MyLoading(viewModel: loadingVM)
                    }
                }
            }
        }
        .task {
            await loadResources()
        }
        .onDisappear {
            viewModel.resources = nil
        }
    }

    /// 没有任何已安装资源（或搜索无结果）时的占位卡片。
    private var emptyResourcesCard: some View {
        MyCard(nil, foldable: false) {
            VStack(spacing: 10) {
                MyText(
                    viewModel.hasSearchKeyword
                        ? "没有匹配“\(viewModel.currentSearchKeyword)”的结果"
                        : "这个实例还没有安装任何\(viewModel.type.localizedName)",
                    size: 16,
                    color: .color3
                )
                if !viewModel.hasSearchKeyword {
                    MyText("从下载页面获取\(viewModel.type.localizedName)后，它们会出现在这里。也可以直接把文件拖进启动器窗口。", size: 13, color: .color3)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity)
        }
    }

    /// 加载已安装资源列表；失败时提供重试入口。
    private func loadResources() async {
        loadingVM.reset()
        do {
            try await viewModel.load()
        } catch {
            err("加载资源列表失败：\(error.localizedDescription)")
            loadingVM.fail(with: "加载资源列表失败：\(error.localizedDescription)") {
                Task { await loadResources() }
            }
        }
    }

    /// 跳转到下载页对应类型的搜索页，并带上本实例的定向上下文。
    private func downloadMore() {
        AppRouter.shared.setRoot(.download)
        AppRouter.shared.append(.resourceDownload(type: viewModel.type, context: .instance(id: viewModel.id)))
    }
}

private struct ResourceListItem: View {
    @ObservedObject private var viewModel: InstalledResourcesViewModel
    @ObservedObject private var resource: ResourceDisplayModel

    init(viewModel: InstalledResourcesViewModel, resource: ResourceDisplayModel) {
        self.viewModel = viewModel
        self.resource = resource
    }

    var body: some View {
        MyListItem { hovered in
            HStack {
                resource.icon.makeView()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(Color.color1)

                VStack(alignment: .leading) {
                    HStack(alignment: .center, spacing: 0) {
                        Group {
                            if #available(macOS 13, *) {
                                MyText(resource.name)
                                    .strikethrough(resource.disabled)
                            } else {
                                MyText((resource.disabled ? "（已禁用）" : "") + resource.name)
                            }
                        }
                        .animation(.easeInOut(duration: 0.1), value: resource.disabled)

                        MyText(" | \(resource.fileName)", size: 12, color: .textSecondary)
                        HStack(spacing: 3) {
                            ForEach(resource.tags, id: \.self) { tag in
                                MyTag(tag, labelColor: .colorGray2, backgroundColor: .black.opacity(0.05), size: 12)
                            }
                        }
                        .padding(.leading, 3)
                    }
                    HStack(spacing: 0) {
                        if let version = resource.version {
                            MyText("\(version) | ", size: 12, color: .textSecondary)
                        }
                        MyText(resource.description, size: 12, color: .textSecondary)
                    }
                }
                .lineLimit(1)
                .textSelection(.enabled)

                Spacer(minLength: 0)

                HStack {
                    ListItemButton(.resource(.btnOpen), scale: 0.8) {
                        NSWorkspace.shared.activateFileViewerSelecting([resource.url])
                    }
                    if !resource.sources.isEmpty {
                        ListItemButton(.resource(.iconAbout), clickPerform: viewInfo)
                    }
                    ListItemButton(.resource(resource.disabled ? .btnEnable : .btnDisable), clickPerform: toggleDisabled)
                        .animation(.easeInOut(duration: 0.1), value: resource.disabled)
                    ListItemButton(.system("trash"), clickPerform: deleteResource)
                }
                .padding(.horizontal, 4)
                .allowsHitTesting(hovered)
                .opacity(hovered ? 1 : 0)
            }
        }
    }

    private func viewInfo() {
        Task {
            do {
                guard let info = try await viewModel.loadInfo(for: resource) else {
                    hint("未找到 \(resource.fileName) 对应的远端资源信息！", type: .critical)
                    return
                }
                AppRouter.shared.append(.projectInstall(project: info, context: .instance(id: viewModel.id)))
            } catch {
                err("获取资源信息失败：\(error.localizedDescription)")
                hint("获取资源信息失败：\(error.localizedDescription)", type: .critical)
            }
        }
    }

    private func toggleDisabled() {
        Task {
            do {
                try await viewModel.toggleDisabled(resource)
            } catch {
                let type = resource.disabled ? "启用" : "禁用"
                err("\(type)资源失败：\(error.localizedDescription)")
                hint("\(type)资源失败：\(error.localizedDescription)", type: .critical)
            }
        }
    }

    private func deleteResource() {
        Task {
            let result = await MessageBoxManager.shared.showTextAsync(
                title: "删除资源",
                content: "确定要删除 \(resource.fileName) 吗？\n此操作会将文件移动到废纸篓，不可撤销。",
                level: .info,
                .no(),
                .yes(label: "删除", type: .red)
            )
            guard result == 1 else { return }
            do {
                try await viewModel.deleteResource(resource)
                hint("删除 \(resource.fileName) 成功！", type: .finish)
            } catch {
                err("删除资源失败：\(error.localizedDescription)")
                hint("删除资源失败：\(error.localizedDescription)", type: .critical)
            }
        }
    }
}
