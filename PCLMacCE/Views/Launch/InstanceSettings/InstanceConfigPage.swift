//
//  InstanceConfigPage.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct InstanceConfigPage: View {
    @StateObject private var viewModel: InstanceConfigViewModel
    @StateObject private var instanceVM: InstanceViewModel
    @StateObject private var loadingVM: MyLoadingViewModel = .init(text: "加载中")
    /// 补装加载器时选择的加载器与版本。
    @State private var selectedLoader: MinecraftInstallTask.Loader?

    init(instanceManager: InstanceManager, id: String) {
        self._viewModel = .init(wrappedValue: .init(instanceManager: instanceManager, id: id))
        self._instanceVM = .init(wrappedValue: InstanceViewModel(instanceManager: instanceManager))
    }

    var body: some View {
        CardContainer {
            MyCard(nil, padding: 10) {
                MyListItem(.init(image: viewModel.icon, name: viewModel.instance?.name ?? "实例不存在", description: viewModel.description))
            }
            MyCard(nil) {
                HStack {
                    MyButton("重命名实例") {
                        renameInstance()
                    }
                    .frame(width: 120)
                    MyButton("打开实例目录") {
                        if let url = viewModel.instance?.url {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .frame(width: 120)
                    MyButton("删除实例", type: .red) {
                        guard let instance = viewModel.instance else { return }
                        MessageBoxManager.shared.showText(
                            title: "确认",
                            content: "确定移除实例「\(instance.name)」吗？实例及其存档、模组和资源包会一起移入废纸篓，可在废纸篓中恢复。",
                            level: .error,
                            .no(),
                            .yes(type: .red)
                        ) { result in
                            if result == 1 {
                                do {
                                    try instanceVM.deleteInstance(instance)
                                    hint("实例已移入废纸篓", type: .finish)
                                    AppRouter.shared.removeLast()
                                } catch {
                                    hint("删除实例失败：\(error.localizedDescription)", type: .critical)
                                }
                            }
                        }
                    }
                    .frame(width: 120)
                    Spacer()
                }
                .frame(height: 35)
            }
            .cardIndex(1)
            jvmCard
                .cardIndex(2)
            modLoaderCard
                .cardIndex(3)
        }
        .onDisappear { viewModel.savePendingChanges() }
    }

    /// 补装 / 更换 Mod 加载器。
    @ViewBuilder
    private var modLoaderCard: some View {
        if let instance = viewModel.instance {
            MyCard("Mod 加载器", foldable: false) {
                HStack {
                    MyText("当前加载器")
                        .frame(width: 120, alignment: .leading)
                    MyText(instance.modLoader.map { "\($0)" } ?? "无（原版）")
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 6)
                if otherLoaderTypes.isEmpty {
                    MyTip(text: "这个实例已经安装了 \(instance.modLoader.map { "\($0)" } ?? "") 加载器。如需更换，请选择一个尚未安装的加载器。", theme: .blue)
                }
                ForEach(otherLoaderTypes, id: \.self) { type in
                    ModLoaderCard(type, instance.version.id, $selectedLoader)
                }
                HStack {
                    MyButton("安装所选加载器", type: .highlight) {
                        installSelectedLoader(for: instance)
                    }
                    .frame(width: 150)
                    .disabled(selectedLoader == nil)
                    Spacer(minLength: 0)
                }
                .frame(height: 35)
                .padding(.top, 8)
            }
        }
    }

    /// 允许补装的加载器类型：排除实例已有的加载器。
    private var otherLoaderTypes: [ModLoader] {
        guard let instance = viewModel.instance else { return [] }
        return ModLoader.allCases.filter { $0 != instance.modLoader }
    }

    /// 弹出输入框重命名实例；成功后更新路由标题（页面以实例名标识）。
    private func renameInstance() {
        guard let instance = viewModel.instance else { return }
        MessageBoxManager.shared.showInput(
            title: "重命名实例",
            initialContent: instance.name,
            placeholder: "新的实例名称"
        ) { text in
            guard let text, text != instance.name else { return }
            viewModel.savePendingChanges()
            Task { @MainActor in
                do {
                    let renamed = try await viewModel.rename(to: text)
                    hint("实例已重命名为「\(renamed.name)」", type: .finish)
                    // 路由以实例名作为标识：替换当前页，避免返回栈里残留旧名字
                    AppRouter.shared.replaceLast(with: .instanceConfig(id: renamed.name))
                } catch {
                    err("重命名实例失败：\(error.localizedDescription)")
                    hint("重命名实例失败：\(error.localizedDescription)", type: .critical)
                }
            }
        }
    }

    private func installSelectedLoader(for instance: MinecraftInstance) {
        guard let loader = selectedLoader else { return }
        MessageBoxManager.shared.showText(
            title: "安装 \(loader.type)",
            content: "将为实例「\(instance.name)」安装 \(loader.type) \(loader.version)。\n\n"
                + "安装会改写实例的版本清单（原清单会保留在 .parent 目录），"
                + "不会影响已有的存档与模组文件。\n是否继续？",
            level: .info,
            .no(),
            .yes(label: "开始安装", type: .highlight)
        ) { result in
            guard result == 1 else { return }
            let task = ModLoaderInstallTask.create(
                for: instance, loader: loader, in: instanceVM.currentRepository
            ) { updated in
                hint("\(loader.type) 安装完成！", type: .finish)
                // 更新仓库缓存并刷新页面显示
                instanceVM.currentRepository.addInstance(updated)
                viewModel.replaceInstance(updated)
                selectedLoader = nil
            }
            TaskManager.shared.execute(task: task)
            AppRouter.shared.append(.tasks)
        }
    }

    @ViewBuilder
    private var jvmCard: some View {
        MyCard("JVM 设置", foldable: false) {
            configLine(label: "使用的 Java") {
                MyText(viewModel.javaDescription)
            }
            configLine(label: "内存分配") {
                MyTextField(text: $viewModel.jvmHeapSize)
                    .onChange(of: viewModel.jvmHeapSize) { newValue in
                        if let jvmHeapSize: UInt64 = .init(newValue) { viewModel.setHeapSize(jvmHeapSize) }
                    }
                MyText("MB")
            }
            configLine(label: "额外 JVM 参数") {
                MyTextField(text: $viewModel.jvmArguments, placeholder: "例如 -XX:+UseG1GC -Dfile.encoding=UTF-8，将被追加至原本 JVM 参数后")
                    .onChange(of: viewModel.jvmArguments) { newValue in
                        viewModel.setJvmArguments(newValue)
                    }
            }
            HStack(spacing: 30) {
                MyButton("切换 Java") {
                    let runtimes: [JavaRuntime] = viewModel.javaList()
                    MessageBoxManager.shared.showList(
                        title: "切换 Java",
                        items: runtimes.map { .init(name: $0.description, description: $0.executableURL.path) }
                    ) { index in
                        guard let index else { return }
                        let runtime: JavaRuntime = runtimes[index]
                        do {
                            try viewModel.switchJava(to: runtime)
                        } catch let error as InstanceConfigViewModel.Error {
                            switch error {
                            case .invalidJavaVersion(let min):
                                MessageBoxManager.shared.showText(
                                    title: "Java 版本不满足要求",
                                    content: "这个实例需要 Java \(min) 才能启动，但你选择的是 Java \(runtime.version)！",
                                    level: .error
                                )
                            }
                        } catch {}
                    }
                }
                .frame(minWidth: 150)
                .fixedSize(horizontal: true, vertical: false)
                Spacer()
            }
            .frame(height: 35)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func configLine(label: String, @ViewBuilder body: () -> some View) -> some View {
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
    }
}
