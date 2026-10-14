//
//  AppTheme.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/10/14.
//

import SwiftUI

/// 应用主题：控制全局色板、页面背景与卡片材质风格。
///
/// 主题的生效方式：`Color.colorN` / `Color.colorGrayN` 等静态色板委托到
/// `ThemeManager.shared.theme.palette`，根视图在主题变化时以 `.id(theme)` 重建视图树，
/// 使所有静态色板引用重新求值（见 `RootView`）。
enum AppTheme: String, Codable, CaseIterable, CustomStringConvertible {
    /// PCL 经典主题（PCL2 风格浅蓝背景与前蓝配色）。
    case classic
    /// Liquid Glass 主题（macOS 26 风格：材质卡片、柔和渐变背景、系统蓝）。
    case liquidGlass

    var description: String {
        switch self {
        case .classic: "PCL 经典"
        case .liquidGlass: "Liquid Glass"
        }
    }

    /// 全局色板。
    var palette: Palette {
        switch self {
        case .classic: .classic
        case .liquidGlass: .liquidGlass
        }
    }

    /// 卡片背景是否使用系统材质（毛玻璃）。
    var usesMaterialCards: Bool { self == .liquidGlass }

    /// 是否为原生 macOS 视觉风格：系统字体、填充控件、白底细边卡片。
    var isNativeStyle: Bool { self == .liquidGlass }

    /// 界面字体（原生风格使用系统字体 SF Pro，经典主题使用 PCL 品牌字体）。
    /// 原生风格字号整体 -1：SF Pro 相比 PCLEnglish 视觉更大，13pt 接近 macOS 正文标准。
    func font(size: CGFloat) -> Font {
        isNativeStyle ? .system(size: max(size - 1, 9), weight: .regular) : .custom("PCLEnglish", size: size)
    }

    /// 卡片与区块标题字体。
    var titleFont: Font {
        isNativeStyle ? .system(size: 13, weight: .semibold) : .custom("PingFangSC-Semibold", size: 14)
    }

    /// 卡片背景。
    var cardBackground: AnyShapeStyle {
        isNativeStyle ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Color.colorGray8)
    }

    /// 卡片圆角半径（原生风格使用 macOS 卡片标准的 10pt）。
    var cardCornerRadius: CGFloat {
        isNativeStyle ? 10 : Radius.lg
    }

    /// 卡片描边（原生风格为细边框，经典主题无描边）。
    var cardBorder: Color? {
        isNativeStyle ? Color.black.opacity(0.07) : nil
    }

    /// 卡片阴影半径。
    var cardShadowRadius: CGFloat {
        isNativeStyle ? 1.5 : 6
    }

    /// 卡片悬停时的阴影半径。
    var cardHoverShadowRadius: CGFloat {
        isNativeStyle ? 4 : 8
    }

    /// 页面背景（经典主题使用；Liquid Glass 的原生玻璃层见 `GlassPageBackground`）。
    var pageBackground: AnyShapeStyle {
        switch self {
        case .classic:
            AnyShapeStyle(Color(0xC0DEF5))
        case .liquidGlass:
            // 原生风格：轻磨砂玻璃（材质层再叠加透明度，减少白雾感、更透出壁纸）
            AnyShapeStyle(.ultraThinMaterial.opacity(0.72))
        }
    }

    /// 侧栏背景（经典主题使用；Liquid Glass 的原生玻璃层见 `GlassSidebarBackground`）。
    var sidebarBackground: AnyShapeStyle {
        switch self {
        case .classic: AnyShapeStyle(.white)
        case .liquidGlass: AnyShapeStyle(.thinMaterial)
        }
    }

    /// 完整色板。
    ///
    /// 字段与 `Color.color1-8` / `Color.colorGray1-8` / `Color.colorBg0-1` 逐一对应，
    /// 命名保留原品牌色板含义（见 `ColorExtension.swift` 的历史说明）。
    struct Palette {
        let color1: Color
        let color2: Color
        let color3: Color
        let color4: Color
        let color5: Color
        let color6: Color
        let color7: Color
        let color8: Color
        let bg0: Color
        let bg1: Color
        let gray1: Color
        let gray2: Color
        let gray3: Color
        let gray4: Color
        let gray5: Color
        let gray6: Color
        let gray7: Color
        let gray8: Color

        /// PCL 经典色板（源自 PCL2-CE，见 issue #13）。
        static let classic: Palette = .init(
            color1: .init(0x343d4a),
            color2: .init(0x0b5bcb),
            color3: .init(0x1370f3),
            color4: .init(0x4890f5),
            color5: .init(0x96c0f9),
            color6: .init(0xd5e6fd),
            color7: .init(0xe0eafd),
            color8: .init(0xeaf2fe),
            bg0: .init(0x96c0f9),
            bg1: .init(0xe0eafd, alpha: 0.75),
            gray1: .init(0x404040),
            gray2: .init(0x737373),
            gray3: .init(0x8c8c8c),
            gray4: .init(0xa6a6a6),
            gray5: .init(0xcccccc),
            gray6: .init(0xebebeb),
            gray7: .init(0xf0f0f0),
            gray8: .init(0xf5f5f5)
        )

        /// Liquid Glass 色板：Apple 系统蓝 + 中性灰阶（贴近 macOS 26 语义色）。
        static let liquidGlass: Palette = .init(
            color1: .init(0x1c1c1e),
            color2: .init(0x0071e3),
            color3: .init(0x2e90fa),
            color4: .init(0x64a8f5),
            color5: .init(0xa3cdf9),
            color6: .init(0xdcedfd),
            color7: .init(0xe8f3fe),
            color8: .init(0xf2f7fe),
            bg0: .init(0xa3cdf9),
            bg1: .init(0xe8f3fe, alpha: 0.75),
            gray1: .init(0x1c1c1e),
            gray2: .init(0x636366),
            gray3: .init(0x8e8e93),
            gray4: .init(0xaeaeb2),
            gray5: .init(0xc7c7cc),
            gray6: .init(0xe5e5ea),
            gray7: .init(0xefeff4),
            gray8: .init(0xf7f7fa)
        )
    }
}
