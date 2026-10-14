//
//  InstanceListPage.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/12/29.
//

import SwiftUI
import Core

struct InstanceListPage: View {
    @StateObject private var viewModel: InstanceListViewModel
    @StateObject private var instanceVM: InstanceViewModel
    private let repositoryId: UUID

    init(instanceManager: InstanceManager, repositoryId: UUID) {
        self._viewModel = .init(wrappedValue: .init(instanceManager: instanceManager, repositoryId: repositoryId))
        self._instanceVM = .init(wrappedValue: .init(instanceManager: instanceManager))
        self.repositoryId = repositoryId
    }

    var body: some View {
        CardContainer {
            MyCard("当前目录：\(viewModel.repository.name)", foldable: false) {
                infoLine(label: "路径") { MyText(viewModel.repository.url.path).textSelection(.enabled) }
                    .padding(.top, 6)
                infoLine(label: "实例数") { MyText(viewModel.instanceCount?.description ?? "-") }
                HStack(spacing: 15) {
                    MyButton("打开文件夹") {
                        NSWorkspace.shared.open(viewModel.repository.url)
                    }
                    .frame(width: 150)
                    MyButton("更改显示名称") {
                        MessageBoxManager.shared.showInput(title: "输入新名称") { name in
                            guard let name, !name.isEmpty else { return }
                            viewModel.rename(to: name)
                            AppRouter.shared.setRoot(.launch)
                            AppRouter.shared.append(.instanceList(repositoryId: viewModel.repository.id))
                            hint("已将目录名称更改为 \(name)！", type: .finish)
                        }
                    }
                    .frame(width: 150)
                    MyButton("移除目录", type: .red) {
                        MessageBoxManager.shared.showText(
                            title: "确认",
                            content: "你确定要移除这个目录（\(viewModel.repository.url.path)）吗？\n这只会把它从启动器的目录列表中移除，而不会删除任何文件。",
                            level: .info,
                            .no(), .yes()
                        ) { button in
                            guard button == 1 else { return }
                            viewModel.removeRepository()
                            AppRouter.shared.removeLast()
                            hint("移除成功！", type: .finish)
                        }
                    }
                    .frame(width: 150)
                    Spacer()
                }
                .frame(height: 35)
                .padding(.top, 6)
            }

            if viewModel.loading {
                MyLoading(viewModel: viewModel.loadingViewModel)
            }

            if let errorInstances = viewModel.errorInstances, !errorInstances.isEmpty {
                MyCard("错误的实例") {
                    VStack(spacing: 0) {
                        ForEach(errorInstances, id: \.name) { instance in
                            ErrorInstanceView(instance: instance, repository: viewModel.repository) {
                                viewModel.reload()
                            }
                        }
                    }
                }
            }

            if let moddedInstances = viewModel.moddedInstances, !moddedInstances.isEmpty {
                MyCard("可安装 Mod", folded: viewModel.vanillaInstances?.isEmpty == false) {
                    instanceList(moddedInstances)
                }
                .cardIndex(1)
            }

            if let vanillaInstances = viewModel.vanillaInstances, !vanillaInstances.isEmpty {
                MyCard("常规实例", folded: false) {
                    instanceList(vanillaInstances)
                }
                .cardIndex(2)
            }
        }
        .onAppear {
            instanceVM.switchRepository(to: viewModel.repository)
        }
    }

    @ViewBuilder
    private func instanceList(_ instances: [MinecraftInstance]) -> some View {
        VStack(spacing: 0) {
            ForEach(instances, id: \.name) { instance in
                InstanceView(instance: instance, isCurrent: instance.id == instanceVM.currentInstance?.id)
                    .onTapGesture {
                        instanceVM.switchInstance(to: instance, in: viewModel.repository)
                        hint("已选择实例「\(instance.name)」", type: .finish)
                        AppRouter.shared.removeLast()
                    }
            }
        }
    }

    @ViewBuilder
    private func infoLine(label: String, @ViewBuilder body: () -> some View) -> some View {
        HStack(spacing: 20) {
            MyText(label)
                .frame(width: 120, alignment: .leading)
            HStack {
                Spacer(minLength: 0)
                body()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
    }
}

private struct ErrorInstanceView: View {
    private let instance: ErrorInstance
    private let directory: URL
    private let onDeleted: () -> Void

    init(instance: ErrorInstance, repository: MinecraftRepository, onDeleted: @escaping () -> Void) {
        self.instance = instance
        self.directory = repository.versionsDirectory.appending(path: instance.name)
        self.onDeleted = onDeleted
    }

    var body: some View {
        MyListItem { hovered in
            HStack {
                Image(.iconRedstoneBlock)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                VStack(alignment: .leading) {
                    MyText(instance.name)
                    MyText(instance.message, size: 12, color: .colorGray3)
                }
                .lineLimit(1)

                Spacer(minLength: 0)

                HStack {
                    ListItemButton(.resource(.btnOpen)) {
                        NSWorkspace.shared.activateFileViewerSelecting([directory])
                    }
                    ListItemButton(.system("trash"), clickPerform: deleteInstance)
                }
                .padding(.horizontal, 4)
                .allowsHitTesting(hovered)
                .opacity(hovered ? 1 : 0)
            }
        }
    }

    private func deleteInstance() {
        MessageBoxManager.shared.showText(
            title: "删除错误的实例",
            content: "确定要删除「\(instance.name)」吗？\n这个实例无法被启动器正常加载，删除后将移入废纸篓。",
            level: .error,
            .no(),
            .yes(label: "删除", type: .red)
        ) { result in
            guard result == 1 else { return }
            Task { @MainActor in
                do {
                    try await NSWorkspace.shared.recycle([directory])
                    hint("已删除「\(instance.name)」", type: .finish)
                    onDeleted()
                } catch {
                    err("删除错误的实例失败：\(error.localizedDescription)")
                    hint("删除失败：\(error.localizedDescription)", type: .critical)
                }
            }
        }
    }
}

private struct InstanceView: View {
    private let name: String
    private let version: MinecraftVersion
    private let icon: ImageResource
    private let isCurrent: Bool

    init(instance: MinecraftInstance, isCurrent: Bool) {
        self.name = instance.name
        self.version = instance.version
        self.isCurrent = isCurrent
        if let modLoader = instance.modLoader {
            self.icon = modLoader.icon
        } else {
            self.icon = .iconGrassBlock
        }
    }

    var body: some View {
        MyListItem(.init(image: icon, name: name, description: isCurrent ? "\(version.id) · 当前选择" : version.id), selected: isCurrent)
    }
}
