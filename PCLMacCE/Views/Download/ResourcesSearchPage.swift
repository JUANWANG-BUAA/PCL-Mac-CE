//
//  ResourcesSearchPage.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct ResourcesSearchPage: View {
    @StateObject private var viewModel: ResourcesSearchViewModel
    @EnvironmentObject private var instanceManager: InstanceManager
    @State private var currentPage: Int = 0
    /// 实例定向模式的目标实例；用户可临时取消筛选以浏览全部资源。
    @State private var restrictedToInstance: Bool
    private let context: InstallContext

    init(type: ResourceType, context: InstallContext = .general) {
        self._viewModel = StateObject(wrappedValue: .init(type: type))
        self.context = context
        self._restrictedToInstance = State(initialValue: context.isInstanceContext)
    }

    /// 实例定向模式下的目标实例。
    private var targetInstance: MinecraftInstance? {
        guard case .instance(let id) = context else { return nil }
        return instanceManager.repositories.values.lazy.compactMap { $0.instance(named: id) }.first
    }

    /// 当前实际生效的筛选（取消实例限制后不再锁定版本与加载器）。
    private var activeFilters: ResourcesSearchViewModel.Filters {
        var filters = viewModel.filters
        if restrictedToInstance, let instance = targetInstance {
            filters.gameVersion = instance.version.id
            if viewModel.supportsLoaderFilter {
                filters.loader = instance.modLoader
            }
        }
        return filters
    }

    var body: some View {
        CardContainer {
            modeTip
            if viewModel.type == .shader {
                MyTip(text: "光影包需要搭配光影加载器使用。", theme: .blue)
            }
            filterBar
            MySearchBox(placeholder: "搜索\(viewModel.type.localizedName)") { query in
                currentPage = 0
                Task { await search(query) }
            }

            if let searchResults = viewModel.searchResults {
                if searchResults.isEmpty {
                    MyCard(nil, foldable: false) {
                        VStack(spacing: 8) {
                            MyText("没有找到匹配的\(viewModel.type.localizedName)", size: 16, color: .color3)
                            MyText("试试更换关键词，或放宽版本 / 加载器筛选条件。", size: 13, color: .color3)
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    PaginatedContainer(currentPage: $currentPage, pageCount: viewModel.totalPages) { _ in
                        MyCard(nil) {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults) { project in
                                    ProjectListItemView(project: project)
                                        .onTapGesture {
                                            AppRouter.shared.append(.projectInstall(project: project, context: context))
                                        }
                                }
                            }
                        }
                    }
                    .onChange(of: currentPage) { newValue in
                        Task { await changePage(newValue) }
                    }
                }
            } else {
                MyLoading(viewModel: viewModel.loadingVM)
            }
        }
        .task {
            Task { await viewModel.loadGameVersions() }
            await search("")
        }
    }

    /// 筛选栏：来源、排序、游戏版本、加载器。
    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                MyText("来源", size: 13)
                MySelect($viewModel.source, entries: ResourcesSearchViewModel.SearchSource.allCases)
                    .frame(width: 130)
                MyText("排序", size: 13)
                MySelect($viewModel.filters.sort, entries: ResourceSearchSort.allCases)
                    .frame(width: 130)
                Spacer(minLength: 0)
                if viewModel.resultCount > 0 {
                    MyText("共 \(viewModel.resultCount) 条", size: 12, color: .textSecondary)
                }
            }
            HStack(spacing: 12) {
                MyText("游戏版本", size: 13)
                MySelect(gameVersionBinding, entries: gameVersionOptions)
                    .frame(width: 130)
                if viewModel.isLoadingGameVersions {
                    MyText("读取版本清单…", size: 11, color: .textSecondary)
                } else if viewModel.gameVersionLoadFailed {
                    MyText("版本清单暂不可用", size: 11, color: .orange)
                    MyButton("重试") {
                        Task { await viewModel.loadGameVersions() }
                    }
                    .frame(width: 48)
                }
                if viewModel.supportsLoaderFilter {
                    MyText("加载器", size: 13)
                    MySelect(loaderBinding, entries: loaderOptions)
                        .frame(width: 130)
                }
                Spacer(minLength: 0)
                MyButton("重置筛选") {
                    viewModel.resetFilters()
                    currentPage = 0
                    Task { await search(viewModel.query) }
                }
                .frame(width: 90)
            }
        }
        .frame(height: 66)
        .onChange(of: viewModel.source) { _ in
            currentPage = 0
            Task { await search(viewModel.query) }
        }
        .onChange(of: viewModel.filters) { _ in
            currentPage = 0
            Task { await search(viewModel.query) }
        }
    }

    /// 版本选项：第一项为“全部版本”。
    private var gameVersionOptions: [String] {
        var versions = viewModel.availableGameVersions
        if let selectedVersion = activeFilters.gameVersion, !versions.contains(selectedVersion) {
            versions.insert(selectedVersion, at: 0)
        }
        return ["全部版本"] + versions
    }

    private var gameVersionBinding: Binding<String> {
        .init(
            get: { activeFilters.gameVersion ?? "全部版本" },
            set: { newValue in
                restrictedToInstance = false
                viewModel.filters.gameVersion = newValue == "全部版本" ? nil : newValue
            }
        )
    }

    private var loaderOptions: [String] {
        return ["全部加载器"] + ModLoader.allCases.map(\.description)
    }

    private var loaderBinding: Binding<String> {
        .init(
            get: { activeFilters.loader?.description ?? "全部加载器" },
            set: { newValue in
                restrictedToInstance = false
                viewModel.filters.loader = ModLoader.allCases.first { $0.description == newValue }
            }
        )
    }

    /// 搜索；失败时提供重试入口。
    @MainActor
    private func search(_ query: String) async {
        do {
            try await viewModel.search(query, filters: activeFilters)
        } catch let error where error.isCancellationError {
        } catch {
            err("搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)")
            viewModel.loadingVM.fail(with: "搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)") {
                Task { await search(query) }
            }
        }
    }

    /// 翻页；失败时提供重试入口。
    @MainActor
    private func changePage(_ page: Int) async {
        do {
            try await viewModel.changePage(page, filters: activeFilters)
        } catch let error where error.isCancellationError {
        } catch {
            err("搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)")
            viewModel.loadingVM.fail(with: "搜索\(viewModel.type.localizedName)失败：\(error.localizedDescription)") {
                Task { await changePage(page) }
            }
        }
    }

    /// 下载模式提示条：实例定向模式显示目标实例与退出入口；普通模式不显示。
    @ViewBuilder
    private var modeTip: some View {
        switch context {
        case .instance:
            if let instance = targetInstance {
                MyTip(
                    text: restrictedToInstance
                        ? "实例定向下载：正在为「\(instance.name)」（\(instance.version.id)"
                            + "\(instance.modLoader.map { " · \($0)" } ?? "")）挑选\(viewModel.type.localizedName)。"
                        : "已取消实例筛选，正在浏览全部版本。重新选择版本或加载器可恢复筛选。",
                    theme: restrictedToInstance ? .blue : .yellow,
                    actionLabel: restrictedToInstance ? "浏览全部" : "恢复实例筛选"
                ) {
                    restrictedToInstance.toggle()
                    currentPage = 0
                    Task { await search(viewModel.query) }
                }
            } else {
                MyTip(text: "目标实例不存在，已按普通下载模式浏览。", theme: .yellow)
            }
        case .general:
            EmptyView()
        }
    }
}

struct ProjectListItemView: View {
    private let project: ProjectListItemModel
    private let isTagRowSeparated: Bool

    init(project: ProjectListItemModel, primary: Bool = false) {
        self.project = project
        self.isTagRowSeparated = primary && project.tags.count > 3
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        // 标签配色：原生风格用语义灰（亮玻璃上可读），经典主题保留 PCL 灰阶
        let tagLabel: Color = isNative ? .secondary : .colorGray2
        let tagFill: Color = isNative ? Color.primary.opacity(0.07) : .init(0x000000, alpha: 17 / 255)
        return MyListItem {
            HStack {
                Group {
                    if let iconURL: URL = project.iconURL {
                        NetworkImage(url: iconURL)
                    } else {
                        Image(.iconModLogo)
                            .resizable()
                            .scaledToFit()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: 48, height: 48)
                .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 2) {
                    MyText(project.title, size: 16)
                        .lineLimit(1)

                    if isTagRowSeparated {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(project.tags, id: \.self) { tag in
                                    MyTag(tag, labelColor: tagLabel, backgroundColor: tagFill, size: 12)
                                }
                            }
                        }

                        MyText(project.description, color: .textSecondary)
                    } else {
                        HStack {
                            ForEach(project.tags.prefix(3), id: \.self) { tag in
                                MyTag(tag, labelColor: tagLabel, backgroundColor: tagFill, size: 12)
                            }
                            MyText(project.description, color: .textSecondary)
                                .lineLimit(1)
                        }
                    }

                    HStack {
                        InformationView(icon: .iconSettingsPage, text: project.supportDescription, width: 200)
                        InformationView(icon: .iconDownloadPage, text: project.downloads, width: 150)
                        InformationView(icon: .iconUpload, text: project.lastUpdate, width: 150)
                        Spacer()
                    }

                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private struct InformationView: View {
        private let icon: ImageResource
        private let text: String
        private let width: CGFloat

        init(icon: ImageResource, text: String, width: CGFloat) {
            self.icon = icon
            self.text = text
            self.width = width
        }

        var body: some View {
            HStack(spacing: 6) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14)
                    .foregroundStyle(Color.textSecondary)
                MyText(text, size: 12, color: .textSecondary)
            }
            .frame(width: width, alignment: .leading)
        }
    }
}
