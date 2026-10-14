//
//  LiquidGlass.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/10/14.
//

import SwiftUI

/// Liquid Glass 辅助：macOS 26+ 使用官方玻璃效果，低版本回退为系统材质。
///
/// 适用对象是"悬浮在内容之上的控制层"（选中项、工具栏按钮、浮层、悬浮按钮），
/// 而非普通内容卡片——这是 Apple Liquid Glass 设计的核心用法。
extension View {
    /// 给视图加上玻璃材质背景。
    /// - Parameters:
    ///   - shape: 裁剪形状（圆角矩形/胶囊/圆形）。
    ///   - interactive: 是否响应交互（触摸时玻璃有动态反馈），用于按钮类元素。
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}

/// 选中态/常显的玻璃高亮（导航项、工具栏按钮、悬浮按钮）。
struct GlassHighlightModifier<S: Shape>: ViewModifier {
    let isEnabled: Bool
    let shape: S

    func body(content: Content) -> some View {
        if isEnabled {
            content.glassBackground(in: shape, interactive: true)
        } else {
            content
        }
    }
}

extension View {
    /// 在启用时给视图叠加交互式玻璃高亮。
    func glassHighlight<S: Shape>(_ isEnabled: Bool, in shape: S) -> some View {
        modifier(GlassHighlightModifier(isEnabled: isEnabled, shape: shape))
    }
}

// MARK: - 页面级玻璃背景

/// 页面级玻璃背景：承载整个窗口的材质层。
///
/// macOS 26+ 使用官方 `glassEffect(.clear)`——相比普通材质，clear 玻璃的白色雾面极轻、
/// 透光性高，能让桌面壁纸以强模糊的形式透出（而非一层白色高斯模糊）；
/// 低版本回退为轻材质。
struct GlassPageBackground: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.clear, in: Rectangle())
                .overlay {
                    // 轻微提亮：clear 玻璃在暗色壁纸上对比偏低，5% 白色保证前景文字可读
                    Rectangle()
                        .fill(.white.opacity(0.05))
                        .allowsHitTesting(false)
                }
        } else {
            Rectangle()
                .fill(AppTheme.liquidGlass.pageBackground)
        }
    }
}

/// 侧栏玻璃背景：在页面玻璃之上再叠一层 clear 玻璃，并施加额外的模糊。
///
/// 侧栏需要比内容区更重的模糊以区分层次，但依然要保持透光（可以辨认壁纸轮廓）。
/// 实测直接叠加多层 clear 玻璃不会进一步模糊（每层都采样窗口背后的壁纸），
/// 因此在 clear 玻璃之上再应用一次 `blur`，用极低的白色代价换取更强磨砂感。
struct GlassSidebarBackground: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.clear, in: Rectangle())
                .blur(radius: 5, opaque: true)
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
