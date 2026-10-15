//
//  ColorExtension.swift
//  PCL.Mac
//

import SwiftUI

/// 全局色板。
///
/// 所有颜色都委托到 `ThemeManager`，因此主题切换后需要重建视图树才能刷新
/// （`RootView` 以 `.id(theme)` 实现，见 `ThemeManager` 文档）。
extension Color {
    // 出处：PCL2-CE 官方色板（原上游仓库 issue #13；该仓库已转为私有，此行仅作出处记录）
    // https://github.com/PCL-Community/PCL2-CE/blob/cf2ddb8cbd2a3edc00ebd9ebf7533b0ba7b7de10/Plain%20Craft%20Launcher%202/Application.xaml#L28-L84
    private static var palette: AppTheme.Palette { ThemeManager.shared.theme.palette }

    static var color1: Color { palette.color1 }
    static var color2: Color { palette.color2 }
    static var color3: Color { palette.color3 }
    static var color4: Color { palette.color4 }
    static var color5: Color { palette.color5 }
    static var color6: Color { palette.color6 }
    static var color7: Color { palette.color7 }
    static var color8: Color { palette.color8 }
    static var colorBg0: Color { palette.bg0 }
    static var colorBg1: Color { palette.bg1 }
    static var colorGray1: Color { palette.gray1 }
    static var colorGray2: Color { palette.gray2 }
    static var colorGray3: Color { palette.gray3 }
    static var colorGray4: Color { palette.gray4 }
    static var colorGray5: Color { palette.gray5 }
    static var colorGray6: Color { palette.gray6 }
    static var colorGray7: Color { palette.gray7 }
    static var colorGray8: Color { palette.gray8 }

    init(_ hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
