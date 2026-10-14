//
//  ResourcesSearchPage.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/3/16.
//

import SwiftUI
import Core

struct ResourcesSearchPage: View {
    @StateObject private var viewModel: ResourcesSearchViewModel
    @EnvironmentObject private var instanceManager: InstanceManager
    @State private var currentPage: Int = 0
    private let context: InstallContext
    
    init(type: ResourceType, context: InstallContext = .general) {
        self._viewModel = StateObject(wrappedValue: .init(type: type))
        self.context = context
    }
    
    /// 实例定向模式下的目标实例。
    private var targetInstance: MinecraftInstance? {
        guard case .instance(let id) = context else { return nil }
        return instanceManager.repositories.values.lazy.compactMap { $0.instance(named: id) }.first
    }
    
    var body: some View {
        CardContainer {
            modeTip
            if viewModel.type == .shader {
                MyTip(text: "光影包需要搭配光影加载器使用。\n详细教程：\(WebLinks.CylorineSite.shaderHelp.absoluteString)", theme: .blue)
                    .onTapGesture {
                        NSWorkspace.shared.open(WebLinks.CylorineSite.shaderHelp)
                    }
            }
            MySearchBox(placeholder: "搜索\(viewModel.type.localizedName)") { query in
                currentPage = 0
                Task { await search(query) }
            }
            
            if let searchResults = viewModel.searchResults {
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
            } else {
                MyLoading(viewModel: viewModel.loadingVM)
            }
        }
        .task {
            await search("")
        }
    }
    
    /// 搜索；失败时提供重试入口。
    @MainActor
    private func search(_ query: String) async {
        do {
            try await viewModel.search(query)
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
            try await viewModel.changePage(page)
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
                    text: "实例定向下载：正在为「\(instance.name)」（\(instance.version.id)\(instance.modLoader.map { " · \($0)" } ?? "")）挑选\(viewModel.type.localizedName)，列表仅显示兼容版本",
                    theme: .blue,
                    actionLabel: "退出实例模式"
                ) {
                    exitInstanceMode()
                }
            } else {
                MyTip(text: "目标实例不存在，已按普通下载模式浏览。", theme: .yellow)
            }
        case .general:
            EmptyView()
        }
    }
    
    /// 退出实例定向模式，回到普通下载（同一页面就地切换上下文）。
    private func exitInstanceMode() {
        AppRouter.shared.removeLast()
        AppRouter.shared.append(.resourceDownload(type: viewModel.type, context: .general))
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
        MyListItem {
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
                                    MyTag(tag, labelColor: .colorGray2, backgroundColor: .init(0x000000, alpha: 17 / 255), size: 12)
                                }
                            }
                        }
                        
                        MyText(project.description, color: .colorGray3)
                    } else {
                        HStack {
                            ForEach(project.tags.prefix(3), id: \.self) { tag in
                                MyTag(tag, labelColor: .colorGray2, backgroundColor: .init(0x000000, alpha: 17 / 255), size: 12)
                            }
                            MyText(project.description, color: .colorGray3)
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
                    .foregroundStyle(Color.colorGray3)
                MyText(text, size: 12, color: .colorGray3)
            }
            .frame(width: width, alignment: .leading)
        }
    }
}
