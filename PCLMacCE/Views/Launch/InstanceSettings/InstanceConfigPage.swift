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
        }
        .onDisappear { viewModel.savePendingChanges() }
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
