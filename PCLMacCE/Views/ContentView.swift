//
//  ContentView.swift
//  PCLMacCE
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
                    // 主区域只叠加轻微的非采样底色，不再对整窗玻璃做第二次材质模糊。
                    // 保留壁纸透光，同时降低亮暗壁纸对正文对比度的影响。
                    .background {
                        if ThemeManager.shared.theme.isNativeStyle {
                            Color.white.opacity(0.22)
                        }
                    }
                    // 内容区遮罩：页面玻璃与卡片材质在失焦 / 过渡期会"回退态 → 真实态"地
                    // settle（亮度突变）；盖上后 settle 发生在遮罩之下（见 GlassCoverState）
                    .overlay { GlassCoverOverlay(dark: false) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { ExtraButtonsOverlay() }
        .overlay { MessageBoxOverlay() }
        .overlay {
            // 原生风格：提示出现在右上角（macOS 瞬时反馈惯例，避开底部内容）；
            // 经典主题保持 PCL 的左下角提示
            let isNative = ThemeManager.shared.theme.isNativeStyle
            VStack(alignment: isNative ? .trailing : .leading, spacing: isNative ? 10 : 16) {
                if !isNative {
                    Spacer()
                }
                ForEach(hintManager.hints) { hint in
                    HintView(model: hint)
                }
                if isNative {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isNative ? .topTrailing : .bottomLeading)
            .animation(.easeOut(duration: 0.2), value: hintManager.hints)
            .padding(isNative
                ? EdgeInsets(top: 64, leading: 0, bottom: 0, trailing: 20)
                : EdgeInsets(top: 0, leading: 0, bottom: 100, trailing: 0))
        }
        .background {
            if ThemeManager.shared.theme.isNativeStyle {
                GlassPageBackground()
            } else {
                Rectangle().fill(ThemeManager.shared.theme.pageBackground)
            }
        }
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
        // 原生（右上角）：自上滑入；经典（左下角）：自左滑入
        .offset(x: isNative ? 0 : (appeared ? 0 : -30), y: isNative && !appeared ? -10 : 0)
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

    /// 弹窗遮罩色调：原生风格一律中性变暗（macOS 从不把整窗染色）；
    /// 经典主题保留 PCL 的"错误红屏"。
    private func overlayTint(for level: MessageBoxModel.Level) -> Color {
        if isNative { return .black.opacity(0.35) }
        return level == .error ? Color(0xFF0000).opacity(0.5) : .black.opacity(0.35)
    }

    @State private var animationHideWorkItem: DispatchWorkItem?

    var body: some View {
        Group {
            if let messageBox {
                ZStack {
                    Rectangle()
                        .fill(overlayTint(for: messageBox.level))
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
