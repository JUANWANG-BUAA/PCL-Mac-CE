//
//  LiquidGlass.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/10/14.
//

import SwiftUI
import AppKit

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

/// 侧栏/顶栏玻璃背景：在页面玻璃之上再叠一层 clear 玻璃，并施加额外的模糊。
///
/// 需要比内容区更重的模糊以区分层次，但依然保持透光（可以辨认壁纸轮廓）。
/// 实测直接叠加多层 clear 玻璃不会进一步模糊（每层都采样窗口背后的壁纸），
/// 因此在 clear 玻璃之上再应用一次 `blur`，用极低的白色代价换取更强磨砂感。
///
/// - Parameter dark: 深色侧栏（原生风格）：加黑色色调以承载白色文字，
///   同时保持半透明，让壁纸以磨砂形式透出。
struct GlassSidebarBackground: View {
    var dark: Bool = false

    var body: some View {
        if #available(macOS 26.0, *) {
            NativeGlassEffectView(
                style: .clear,
                // 顶栏：一层轻而均匀的浅色底，保证标题区不受背后壁纸明暗影响；
                // 侧栏：深色调，承载白色文字
                tint: dark
                    ? NSColor.black.withAlphaComponent(0.38)
                    : NSColor.windowBackgroundColor.withAlphaComponent(0.35)
            )
            .blur(radius: 5, opaque: true)
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
