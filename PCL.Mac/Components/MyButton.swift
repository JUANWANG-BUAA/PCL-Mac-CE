//
//  MyButton.swift
//  PCL.Mac
//

import SwiftUI

struct MyButton: View {
    @State private var hovered: Bool = false
    @State private var isPressed: Bool = false
    private let label: String
    private let subLabel: String?
    private let textPadding: EdgeInsets
    private let type: Style
    private let disabled: Bool
    private let action: () -> Void

    private var color: Color {
        disabled ? .colorGray4 :
        hovered ? type.hoverColor : type.color
    }

    init(
        _ label: String,
        subLabel: String? = nil,
        textPadding: EdgeInsets = .init(),
        type: Style = .normal,
        disabled: Bool = false,
        _ action: @escaping () -> Void
    ) {
        self.label = label
        self.subLabel = subLabel
        self.textPadding = textPadding
        self.type = type
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Group {
            if ThemeManager.shared.theme.isNativeStyle {
                if #available(macOS 26.0, *) {
                    // 系统 Liquid Glass 材质（自带交互反馈，不挂 DragGesture）
                    glassBody
                } else {
                    acrylicBody.gesture(pressGesture)
                }
            } else {
                pclBody.gesture(pressGesture)
            }
        }
        .scaleEffect(isPressed ? (ThemeManager.shared.theme.isNativeStyle ? 0.98 : 0.85) : 1.0)
        // 动效节奏：原生风格用短促 ease-out，经典主题保留较长过渡
        .animation(.easeOut(duration: ThemeManager.shared.theme.isNativeStyle ? 0.12 : 0.2), value: hovered)
        .animation(.easeOut(duration: ThemeManager.shared.theme.isNativeStyle ? 0.1 : 0.2), value: isPressed)
        .onHover {
            guard !disabled else { return }
            hovered = $0
        }
    }

    /// 自绘按钮的按压手势（系统按钮不需要）。
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !disabled else { return }
                isPressed = true
            }
            .onEnded { _ in
                guard !disabled else { return }
                action()
                isPressed = false
            }
    }

    /// macOS 26 以下的原生风格回退：自绘 Acrylic 玻璃按钮。
    private var acrylicBody: some View {
        ZStack {
            // 可扩展的透明形状：与经典主题一致地填满调用点的 frame 约束
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(.clear)
            materialSheenRect
            nativeLabel
        }
        .acrylicBackground(
            in: RoundedRectangle(cornerRadius: Radius.md),
            tint: materialTint ?? .white,
            tintOpacity: tintOpacity,
            noise: 0.03
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    /// macOS 26+ 官方 Liquid Glass 按钮。
    ///
    /// 系统 `.glass` / `.glassProminent` 样式只会按内容自然尺寸渲染，忽略布局给出的宽高
    /// 约束（单边 frame 被撑满、固定 width 被居中），导致同一布局下按钮比原版 PCL 明显
    /// 偏小、突兀。这里改用自定义 `GlassStyle` 承载官方玻璃材质，让按钮像经典主题的
    /// 自绘按钮一样服从调用点的 frame 约束，切换主题时尺寸保持不变。
    @available(macOS 26.0, *)
    private var glassBody: some View {
        Button(action: action) {
            nativeLabel
        }
        .buttonStyle(GlassStyle(tint: materialTint, sheen: materialSheen, disabled: disabled, hovered: hovered))
        .disabled(disabled)
    }

    /// 原生玻璃按钮的标签（与经典主题使用同一套字号，仅颜色随材质区分）。
    private var nativeLabel: some View {
        VStack(spacing: Spacing.xs) {
            MyText(label, color: foregroundColor)
                .padding(textPadding)
            if let subLabel {
                MyText(subLabel, size: 12, color: subLabelColor)
            }
        }
    }

    /// 原生按钮的前景色。
    private var foregroundColor: Color {
        switch type {
        case .normal: disabled ? Color.primary.opacity(0.35) : .primary
        case .highlight, .red: disabled ? Color.white.opacity(0.6) : .white
        }
    }

    /// 原生按钮副标题的颜色（语义色，随材质自适应）。
    private var subLabelColor: Color {
        switch type {
        case .normal: .secondary
        case .highlight, .red: .white.opacity(0.7)
        }
    }

    /// 玻璃/材质色调：普通按钮为中性材质，高亮与危险操作带语义色。
    private var materialTint: Color? {
        switch type {
        case .normal: nil
        case .highlight: .accentColor
        case .red: .danger
        }
    }

    /// 危险按钮的玻璃光影。
    ///
    /// 系统红色在玻璃上接近纯色平涂（白底/蓝底自带细微渐变与透光），单独看会显得
    /// 死板；叠加纵向光影后与官方玻璃材质一样有厚度，质感接近普通与高亮按钮。
    private var materialSheen: LinearGradient? {
        guard type == .red, !disabled else { return nil }
        return LinearGradient(
            stops: [
                .init(color: .white.opacity(0.18), location: 0),
                .init(color: .white.opacity(0.03), location: 0.45),
                .init(color: .clear, location: 0.55),
                .init(color: .black.opacity(0.09), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 光影层（位于材质之上、文字之下）。
    @ViewBuilder
    private var materialSheenRect: some View {
        if let materialSheen {
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(materialSheen)
                .allowsHitTesting(false)
        }
    }

    /// Acrylic 色调层的不透明度（悬停时加深）。
    private var tintOpacity: Double {
        if disabled { return 0.1 }
        switch type {
        case .normal: return hovered ? 0.7 : 0.5
        case .highlight, .red: return hovered ? 0.95 : 0.85
        }
    }

    /// PCL 经典风格：描边式按钮。
    private var pclBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(color.opacity(hovered ? 0.2 : 0.005))
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(style: .init(lineWidth: 1.2))
                .fill(color)
                .padding(1.2)
                .brightness(hovered ? 0.2 : 0)
            VStack(spacing: Spacing.xs) {
                MyText(label, color: color)
                    .padding(textPadding)
                if let subLabel {
                    MyText(subLabel, size: 12, color: .colorGray3)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    /// macOS 26+ 的玻璃按钮样式：官方 `glassEffect` + 与 `pclBody` 相同的尺寸语义。
    @available(macOS 26.0, *)
    private struct GlassStyle: ButtonStyle {
        /// 玻璃色调（nil 为中性玻璃）。
        let tint: Color?
        /// 叠加在材质之上的光影（位于文字之下，nil 为不加）。
        let sheen: LinearGradient?
        /// 禁用时保持中性玻璃并关闭交互反馈。
        let disabled: Bool
        /// 悬停时叠加轻微高光。
        let hovered: Bool

        func makeBody(configuration: Configuration) -> some View {
            // macOS 26 玻璃按钮的系统形状是胶囊；经典主题仍为 4pt 圆角（pclBody）
            ZStack {
                // 可扩展的透明形状：给按钮一个能填满可用空间的尺寸来源
                Capsule()
                    .fill(.clear)
                if let sheen {
                    Capsule()
                        .fill(sheen)
                        .allowsHitTesting(false)
                }
                configuration.label
            }
            .contentShape(Capsule())
            .glassEffect(glass, in: Capsule())
            .overlay {
                if hovered && !disabled {
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }

        private var glass: Glass {
            .regular
                .tint(disabled ? nil : tint)
                .interactive(!disabled)
        }
    }

    enum Style {
        case normal, highlight, red

        var color: Color {
            switch self {
            case .normal: .color1
            case .highlight: .color2
            case .red: .danger
            }
        }

        var hoverColor: Color {
            switch self {
            case .normal: .color3
            case .highlight: .color3
            case .red: .dangerHover
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        MyButton("实例选择", type: .highlight) {
            print("Button pressed")
        }
        MyButton("普通按钮") {}
        MyButton("危险操作", type: .red) {}
    }
    .frame(width: 200)
    .padding()
}
