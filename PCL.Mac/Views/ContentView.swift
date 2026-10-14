//
//  ContentView.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/8.
//

import SwiftUI
import UniformTypeIdentifiers
import Core

struct ContentView: View {
    @ObservedObject private var hintManager: HintManager = .shared
    @ObservedObject private var router: AppRouter = .shared
    @ObservedObject private var easterEggManager: EasterEggManager = .shared

    @EnvironmentObject private var instanceManager: InstanceManager

    var body: some View {
        VStack(spacing: 0) {
            TitleBarView()
                .zIndex(10)
            HStack(spacing: 0) {
                AppSidebarView()
                AppRouterView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { ExtraButtonsOverlay() }
        .overlay { MessageBoxOverlay() }
        .overlay {
            VStack(alignment: .leading, spacing: 16) {
                Spacer()
                ForEach(hintManager.hints) { hint in
                    HintView(model: hint)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.2), value: hintManager.hints)
            .padding(.bottom, 100)
        }
        .background(ThemeManager.shared.theme.pageBackground)
        .rotation3DEffect(easterEggManager.rotationAngle, axis: easterEggManager.rotationAxis)
        .contrast(easterEggManager.modifyColor ? -1 : 1)
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { item, error in
                if let error {
                    err("处理拖拽失败：\(error.localizedDescription)")
                    hint("处理拖拽失败：\(error.localizedDescription)", type: .critical)
                    return
                }
                guard let url = item else {
                    hint("处理拖拽失败：发生未知错误。", type: .critical)
                    return
                }
                Task {
                    await FileDropHandler.handle(url, instanceManager: instanceManager)
                }
            }
            return true
        }
    }
}

private struct HintView: View {
    @State private var appeared: Bool = false
    private let model: HintModel

    init(model: HintModel) {
        self.model = model
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        Group {
            if isNative {
                // 原生风格：玻璃胶囊提示
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(model.text)
                        .font(.app(13))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .acrylicBackground(in: Capsule(), tintOpacity: 0.3)
            } else {
                ZStack(alignment: .leading) {
                    RightRoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(height: 22)
                    MyText(model.text, color: .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -30)
        .fixedSize(horizontal: true, vertical: false)
        .animation(.easeOut(duration: isNative ? 0.15 : 0.2), value: appeared)
        .onAppear {
            appeared = true
        }
    }

    private var color: Color {
        if ThemeManager.shared.theme.isNativeStyle {
            switch model.type {
            case .info: .init(0x0071e3)
            case .finish: .init(0x28a745)
            case .critical: .init(0xd70015)
            }
        } else {
            switch model.type {
            case .info: Color(0x0A8EFC)
            case .finish: Color(0x1DA01D)
            case .critical: Color(0xFF2B00)
            }
        }
    }
}

private struct MessageBoxOverlay: View {
    @ObservedObject var messageBoxManager: MessageBoxManager = .shared
    @State private var messageBox: MessageBoxModel?

    @State private var opacity: CGFloat = 0
    @State private var scale: CGFloat = 0.92
    private var isNative: Bool { ThemeManager.shared.theme.isNativeStyle }

    @State private var animationHideWorkItem: DispatchWorkItem?

    var body: some View {
        Group {
            if let messageBox {
                ZStack {
                    Rectangle()
                        .fill(messageBox.level == .error ? Color(0xFF0000).opacity(0.5) : .black.opacity(0.35))
                    MessageBoxView(model: messageBox)
                        .scaleEffect(isNative ? scale : 1)
                }
                .opacity(opacity)
            }
        }
        .onChange(of: messageBoxManager.currentMessageBox) { newValue in
            if newValue != nil { // 移入：原生弹窗的缩放淡入（无旋转与弹跳）
                animationHideWorkItem?.cancel()
                messageBox = newValue
                withAnimation(.easeOut(duration: 0.18)) {
                    opacity = 1
                    scale = 1
                }
            } else { // 移出
                let workItem: DispatchWorkItem = .init {
                    self.messageBox = nil
                    self.scale = 0.92
                }
                animationHideWorkItem = workItem
                let duration: CGFloat = 0.12
                DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
                withAnimation(.easeOut(duration: duration)) {
                    opacity = 0
                    scale = 0.96
                }
            }
        }
    }
}

private struct ExtraButtonsOverlay: View {
    @ObservedObject private var router: AppRouter = .shared
    @ObservedObject private var launchManager: MinecraftLaunchManager = .shared
    @ObservedObject private var taskManager: TaskManager = .shared

    var body: some View {
        VStack(spacing: 0) {
            ExtraButton(.iconDownloadPage, showTasksButton) {
                router.append(.tasks)
            }
            ExtraButton(.iconPower, launchManager.isRunning) {
                launchManager.stop()
                if launchManager.isLaunching {
                    hint("已取消启动！", type: .finish)
                } else {
                    hint("已关闭游戏！", type: .finish)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .animation(.spring(response: 0.4), value: launchManager.isRunning)
        .animation(.spring(response: 0.4), value: showTasksButton)
    }

    private var showTasksButton: Bool {
        !taskManager.tasks.filter(\.display).isEmpty && router.last != .tasks
    }

    private struct ExtraButton: View {
        @State private var hovered: Bool = false
        @State private var pressed: Bool = false
        private let icon: ImageResource
        private let show: Bool
        private let onClick: () -> Void

        init(_ icon: ImageResource, _ show: Bool, onClick: @escaping () -> Void) {
            self.icon = icon
            self.show = show
            self.onClick = onClick
        }

        var body: some View {
            let isNative = ThemeManager.shared.theme.isNativeStyle
            Circle()
                .fill(isNative ? .clear : (hovered ? Color.color4 : .color3))
                .frame(width: show ? 40 : 1)
                .overlay {
                    Image(icon)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .foregroundStyle(isNative ? Color.primary : Color.color8)
                }
                .acrylicHighlight(isNative && show, in: Circle(), tintOpacity: 0.25)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in pressed = true }
                        .onEnded { _ in
                            pressed = false
                            onClick()
                        }
                )
                .onHover { hovered = $0 }
                .scaleEffect(show ? (pressed ? 0.85 : 1) : 0, anchor: .center)
                .padding(show ? 4 : 0)
                .animation(.linear(duration: 0.15), value: hovered)
                .animation(.easeOut(duration: 0.15), value: pressed)
                .animation(.spring(response: 0.4), value: show)
        }
    }
}
