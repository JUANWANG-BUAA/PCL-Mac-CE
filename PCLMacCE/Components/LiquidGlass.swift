//
//  LiquidGlass.swift
//  PCLMacCE
//

import SwiftUI
import AppKit
import Core

/// Liquid Glass 辅助：macOS 26+ 使用官方玻璃效果，低版本回退为系统材质。
///
/// 适用对象是"悬浮在内容之上的控制层"（选中项、工具栏按钮、浮层、悬浮按钮），
/// 而非普通内容卡片——这是 Apple Liquid Glass 设计的核心用法。
extension View {
    /// 给视图加上玻璃材质背景。
    /// - Parameters:
    ///   - shape: 裁剪形状（圆角矩形/胶囊/圆形）。
    ///   - interactive: 是否响应交互（触摸时玻璃有动态反馈），用于按钮类元素。
    ///   - tint: 玻璃色调（用于深色悬浮控件等需要与浅色底拉开对比的场景），`nil` 为中性玻璃。
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background {
                ZStack {
                    shape.fill(.regularMaterial)
                    if let tint {
                        shape.fill(tint)
                    }
                }
            }
        }
    }
}

/// 组装 `Glass` 参数（ViewBuilder 内不允许声明变量，故独立成函数）。
@available(macOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass: Glass = .regular
    if let tint {
        glass = glass.tint(tint)
    }
    if interactive {
        glass = glass.interactive()
    }
    return glass
}

/// 选中态/常显的玻璃高亮（导航项、工具栏按钮、悬浮按钮）。
struct GlassHighlightModifier<S: Shape>: ViewModifier {
    let isEnabled: Bool
    let shape: S
    /// 官方玻璃的色调（macOS 26+，用于深色悬浮胶囊等需要白色前景的场景）。
    let tint: Color?
    /// macOS 26 以下无官方玻璃，回退材质可叠加的色调（用于保证白色前景的对比度）。
    let fallbackTint: Color?

    func body(content: Content) -> some View {
        if isEnabled {
            if #available(macOS 26.0, *) {
                content.glassEffect(makeGlass(tint: tint, interactive: true), in: shape)
            } else {
                content.background {
                    ZStack {
                        shape.fill(.regularMaterial)
                        if let fallbackTint {
                            shape.fill(fallbackTint)
                        }
                    }
                }
            }
        } else {
            content
        }
    }
}

extension View {
    /// 在启用时给视图叠加交互式玻璃高亮。
    /// - Parameters:
    ///   - tint: 官方玻璃的色调（macOS 26+）。
    ///   - fallbackTint: macOS 26 以下回退材质的色调，默认无。
    func glassHighlight<S: Shape>(_ isEnabled: Bool, in shape: S, tint: Color? = nil, fallbackTint: Color? = nil) -> some View {
        modifier(GlassHighlightModifier(isEnabled: isEnabled, shape: shape, tint: tint, fallbackTint: fallbackTint))
    }
}

// MARK: - 页面级玻璃背景

/// AppKit 官方玻璃视图的 SwiftUI 包装。
///
/// 相比 SwiftUI 的 `glassEffect`，`NSGlassEffectView` 是真正的 NSView，参与窗口生命周期，
/// 更适合作为整窗/侧栏这类大面积背景层。
@available(macOS 26.0, *)
private struct NativeGlassEffectView: NSViewRepresentable {
    let style: NSGlassEffectView.Style
    let tint: NSColor?

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = 0
        view.style = style
        view.tintColor = tint
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        view.style = style
        view.tintColor = tint
    }
}

/// 页面级玻璃背景：承载整个窗口的材质层。
///
/// macOS 26+ 使用官方 clear 玻璃——不加额外色调，尽量让桌面壁纸以强模糊的形式透出；
/// 低版本回退为轻材质。
struct GlassPageBackground: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            NativeGlassEffectView(style: .clear, tint: nil)
        } else {
            Rectangle()
                .fill(AppTheme.liquidGlass.pageBackground)
        }
    }
}

/// 玻璃遮罩状态：控制全窗遮罩（侧栏 / 顶栏 / 内容区）的显示。
///
/// 背景（Cmd+Tab 问题的完整根因，见 ADR-007 补充五）：系统在窗口失活 / Cmd+Tab
/// 切换期间不提供背板采样——**任何采样类内容**（自定义玻璃、系统材质、卡片材质、
/// 页面玻璃）都会回退成平板外观，并在背板恢复时"settle"，
/// 实机表现为黑块 / 纯色块 / 亮度突变。
/// 遮罩必须是**完全不依赖采样的纯 App 绘制面**（平滑玻璃光泽面：底色 + 光泽渐变 +
/// 顶部泛光，无任何噪声颗粒）：任何窗口状态下的渲染完全一致。
/// 失活瞬间立即盖上（侧栏深色调、顶栏与内容区浅色调，保留窗口的结构感）；
/// 回到前台 0.7s 后再 0.35s 淡出——此时切换动画与背板恢复都已结束，
/// 露出的玻璃与内容都已是最终状态，全程没有任何突变。
@MainActor
private final class GlassCoverState: ObservableObject {
    static let shared: GlassCoverState = .init()

    /// 揭幕延迟：激活后遮罩保持的时长（实机调试后定为 0.7s）。
    /// 越短揭幕越快；过短可能露出玻璃/材质的回退态（黑块/亮度突变）。
    private static let revealDelay: TimeInterval = 0.7

    /// 遮罩是否遮盖（= 窗口失活 / 切换过渡 / 回到前台后的短暂收尾期）。
    @Published private(set) var isCovered: Bool

    private var revealWorkItem: DispatchWorkItem?

    private init() {
        self.isCovered = !NSApplication.shared.isActive
        let center = NotificationCenter.default
        // 用 willResignActive（比 didResignActive 更早）：第一时间盖上遮罩，
        // 失活期任何采样类内容的回退渲染都不可见
        center.addObserver(forName: NSApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.cover()
            }
        }
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleReveal()
            }
        }
    }

    /// 失活 / 切换出去：立即盖上遮罩（无动画，失活瞬间完成遮挡）。
    private func cover() {
        revealWorkItem?.cancel()
        revealWorkItem = nil
        guard !isCovered else { return }
        isCovered = true
        log("玻璃遮罩：盖上（应用失活）")
    }

    /// 激活：等安全间隔到点后自动揭幕（无需用户交互，可预期且更快）。
    private func scheduleReveal() {
        revealWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.reveal()
        }
        revealWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealDelay, execute: item)
    }

    private func reveal() {
        guard isCovered else { return }
        isCovered = false
        log("玻璃遮罩：揭幕（激活后 \(Self.revealDelay)s）")
    }
}

/// 遮罩面：完全不透明的"玻璃光泽面"——平滑底色 + 上亮下暗的光泽渐变
/// + 顶部柔和泛光，参照系统玻璃按钮的质感。纯 App 绘制、**不含任何噪声颗粒**，
/// 任何窗口状态下的渲染完全一致。
private struct GlassCoverSurface: View {
    let dark: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(dark ? Color(0x1E2025) : Color(0xAAB2BC))
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(dark ? 0.10 : 0.18), location: 0),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(dark ? 0.12 : 0.06), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.white.opacity(dark ? 0.06 : 0.12), .clear],
                center: .init(x: 0.5, y: 0.1),
                startRadius: 0,
                endRadius: dark ? 180 : 260
            )
        }
    }
}

/// 全窗遮罩：按 `GlassCoverState` 把玻璃光泽面盖上 / 揭开——
/// 盖上无动画（失活瞬间完成遮挡），揭开 0.35s 淡出（渐变呈现，不突然）。
struct GlassCoverOverlay: View {
    @ObservedObject private var coverState: GlassCoverState = .shared
    let dark: Bool

    var body: some View {
        GlassCoverSurface(dark: dark)
            .opacity(coverState.isCovered ? 1 : 0)
            .allowsHitTesting(false)
            .animation(coverState.isCovered ? nil : .easeOut(duration: 0.35), value: coverState.isCovered)
    }
}

/// 侧栏/顶栏玻璃背景：在页面玻璃之上再叠一层 regular 玻璃，组成侧栏/顶栏的材质层。
///
/// 磨砂质感由玻璃自身与其色调承担：`.regular` 是玻璃系统给"需要明确存在感"的
/// 大面积材质准备的样式，直接用它拿到磨砂，而不在玻璃之上再套 SwiftUI `.blur`——
/// 后置模糊会把玻璃自身的边缘高光与透镜感一并糊掉（实机观感接近"磨砂塑料板"），
/// 且会把玻璃推进离屏合成路径（失焦回退成块的诱因之一）。
/// 若日后觉得磨砂过头，可换回 `.clear`（更透、能辨认壁纸轮廓）。
///
/// 失焦 / 切换期间由上方的不透明毛玻璃遮罩（见 `GlassCoverState` / `GlassCoverOverlay`）
/// 遮挡：遮罩是纯 App 绘制面，任何状态下渲染恒定；玻璃被遮住期间渲染成什么都不可见。
/// 因此这里**不再对玻璃做任何状态切换**——色调恒定，就是原版；
/// 回到前台约 0.7s 后遮罩 0.35s 淡出露出原版玻璃，全程只有一次柔和过渡。
///
/// - Parameter dark: 深色侧栏（原生风格）：加黑色色调以承载白色文字，
///   同时保持半透明，让壁纸以磨砂形式透出。
struct GlassSidebarBackground: View {
    var dark: Bool = false

    var body: some View {
        if #available(macOS 26.0, *) {
            ZStack {
                NativeGlassEffectView(style: .regular, tint: glassTint)
                // 遮罩盖在玻璃之上：完全不透明，玻璃在它之下渲染什么都不可见
                GlassCoverOverlay(dark: dark)
            }
        } else if dark {
            // macOS 26 以下：用暗色材质模拟深色玻璃
            Rectangle()
                .fill(.regularMaterial)
                .environment(\.colorScheme, .dark)
        } else {
            Rectangle()
                .fill(AppTheme.liquidGlass.sidebarBackground)
        }
    }

    /// 玻璃色调：顶栏一层轻而均匀的浅色底（标题区不受背后壁纸明暗影响）；
    /// 侧栏深色调，承载白色文字。
    private var glassTint: NSColor {
        dark
            ? NSColor.black.withAlphaComponent(0.38)
            : NSColor.windowBackgroundColor.withAlphaComponent(0.35)
    }
}

// MARK: - WinUI 风格 Acrylic

/// WinUI Acrylic 材质：高模糊玻璃 + 色调层 + 细噪点 + 高光描边。
///
/// 专用于"漂浮"在内容之上的组件（弹窗、提示浮层、悬浮按钮、下拉弹层）：
/// 相比纯系统材质，色调层提供"奶白"感，噪点纹理增加磨砂质感，高光边勾出玻璃边缘。
struct AcrylicModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    /// 色调层颜色（默认白色奶白感，可按按钮语义改为强调色）
    var tint: Color = .white
    /// 色调层不透明度
    var tintOpacity: Double = 0.32
    /// 噪点层不透明度（磨砂纹理强度）
    var noiseOpacity: Double = 0.04

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(tint.opacity(tintOpacity))
                    NoiseTextureView()
                        .clipShape(shape)
                        .opacity(noiseOpacity)
                }
            }
            .overlay {
                shape.strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
            }
    }
}

extension View {
    /// 给视图加上 WinUI 风格 Acrylic 材质背景。
    func acrylicBackground<S: InsettableShape>(
        in shape: S,
        tint: Color = .white,
        tintOpacity: Double = 0.32,
        noise: Double = 0.04
    ) -> some View {
        modifier(AcrylicModifier(shape: shape, tint: tint, tintOpacity: tintOpacity, noiseOpacity: noise))
    }
}

/// 平铺的细噪点纹理（生成一次并缓存），用于 Acrylic 的磨砂质感。
struct NoiseTextureView: View {
    static let image: NSImage = makeNoiseImage()

    var body: some View {
        Image(nsImage: Self.image)
            .resizable(resizingMode: .tile)
    }

    /// 生成 128x128 的随机灰度噪点图（确定性伪随机，保证每次运行一致）。
    private static func makeNoiseImage() -> NSImage {
        let size = 128
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return NSImage(size: .init(width: size, height: size))
        }
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        for y in 0..<size {
            for x in 0..<size {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let v = CGFloat((seed >> 33) & 0xFF) / 255.0
                context.setFillColor(CGColor(red: v, green: v, blue: v, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        guard let cgImage = context.makeImage() else {
            return NSImage(size: .init(width: size, height: size))
        }
        return NSImage(cgImage: cgImage, size: .init(width: size, height: size))
    }
}

/// 条件应用 Acrylic（用于悬浮按钮等"有时显示"的元素）。
struct AcrylicHighlightModifier<S: InsettableShape>: ViewModifier {
    let isEnabled: Bool
    let shape: S
    let tintOpacity: Double

    func body(content: Content) -> some View {
        if isEnabled {
            content.acrylicBackground(in: shape, tintOpacity: tintOpacity)
        } else {
            content
        }
    }
}

extension View {
    func acrylicHighlight<S: InsettableShape>(_ isEnabled: Bool, in shape: S, tintOpacity: Double = 0.32) -> some View {
        modifier(AcrylicHighlightModifier(isEnabled: isEnabled, shape: shape, tintOpacity: tintOpacity))
    }
}
