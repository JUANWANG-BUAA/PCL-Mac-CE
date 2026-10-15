//
//  DesignTokens.swift
//  PCLMacCE
//

import SwiftUI

// MARK: - 间距

/// 布局间距 token（4pt 栅格）。
///
/// 使用 token 而非裸数字，保证全局间距节奏一致：
/// ```swift
/// VStack(spacing: .spacingMd) { … }
/// .padding(.spacingLg)
/// ```
enum Spacing {
    /// 4pt —— 图标与文字的间距、紧凑内边距。
    static let xs: CGFloat = 4
    /// 8pt —— 紧凑控件内边距。
    static let sm: CGFloat = 8
    /// 12pt —— 常规控件内边距、卡片标题栏内边距。
    static let md: CGFloat = 12
    /// 16pt —— 卡片默认内边距。
    static let lg: CGFloat = 16
    /// 20pt —— 页面级区块间距。
    static let xl: CGFloat = 20
    /// 32pt —— 页面级大间距。
    static let xxl: CGFloat = 32
}

// MARK: - 圆角

/// 圆角半径 token。
enum Radius {
    /// 2pt —— 提示条（MyTip）等扁平方块。
    static let xs: CGFloat = 2
    /// 4pt —— 按钮（MyButton）。
    static let md: CGFloat = 4
    /// 5pt —— 卡片（MyCard）、标签（MyTag）。
    static let lg: CGFloat = 5
}

// MARK: - 阴影

/// 阴影 token。
enum ShadowToken {
    /// 卡片默认阴影。
    static let card: Color = .black.opacity(0.1)
    /// 卡片悬停阴影（品牌蓝）。
    static let cardHover: Color = .color3.opacity(0.6)
}

// MARK: - 字体

extension Font {
    /// PCL 品牌字体。
    static func pcl(_ size: CGFloat) -> Font {
        .custom("PCLEnglish", size: size)
    }

    /// 界面字体（随主题切换：系统字体 / PCL 品牌字体）。
    static func app(_ size: CGFloat) -> Font {
        ThemeManager.shared.theme.font(size: size)
    }

    /// 卡片标题字体（随主题切换）。
    static var cardTitle: Font {
        ThemeManager.shared.theme.titleFont
    }
}

// MARK: - 语义色

extension Color {
    /// 危险操作（删除、强制继续等按钮的默认红色）。
    static let danger: Color = .init(0xCE2111)
    /// 危险操作按钮的悬停红色。
    static let dangerHover: Color = .init(0xFF4C4C)

    /// 次级文字色（列表描述、信息行、面板标签等）。
    ///
    /// 原生风格使用系统语义色：随外观与材质自适应，在任何壁纸上的对比度都由系统保障；
    /// 固定灰阶（如 colorGray3）叠在透亮玻璃上会随壁纸亮度漂移、不可读。
    static var textSecondary: Color {
        ThemeManager.shared.theme.isNativeStyle ? .secondary : .colorGray3
    }

    /// 三级文字色（占位符、极弱提示）。
    static var textTertiary: Color {
        ThemeManager.shared.theme.isNativeStyle ? .secondary.opacity(0.75) : .colorGray4
    }
}
