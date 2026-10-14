//
//  MyButton.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/12/4.
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
                    // 系统 Liquid Glass 按钮（自带交互反馈，不挂 DragGesture）
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
        // 注意：背景直接修饰内容（不要用 Color.clear 占位——可扩展视图会把按钮撑满可用宽度）
        VStack(spacing: Spacing.xs) {
            Text(label)
                .font(.app(13))
                .foregroundStyle(foregroundColor)
                .padding(textPadding)
            if let subLabel {
                Text(subLabel)
                    .font(.app(11))
                    .foregroundStyle(foregroundColor.opacity(0.7))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .acrylicBackground(
            in: RoundedRectangle(cornerRadius: Radius.md),
            tint: tintColor,
            tintOpacity: tintOpacity,
            noise: 0.03
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.md))
    }
    
    /// macOS 26+ 官方 Liquid Glass 按钮（Apple 设计指南样式，保持系统默认形态与尺寸语义）。
    /// 尺寸由调用点的 `.frame` 决定；单边约束的调用点应用容器包裹（见各处调用点）。
    @available(macOS 26.0, *)
    @ViewBuilder
    private var glassBody: some View {
        switch type {
        case .normal:
            Button(action: action) {
                nativeLabel
            }
            .buttonStyle(.glass)
            .disabled(disabled)
        case .highlight:
            Button(action: action) {
                nativeLabel
            }
            .buttonStyle(.glassProminent)
            .disabled(disabled)
        case .red:
            Button(action: action) {
                nativeLabel
            }
            .buttonStyle(.glassProminent)
            .tint(.red)
            .disabled(disabled)
        }
    }
    
    /// Liquid Glass 按钮的标签内容。
    private var nativeLabel: some View {
        VStack(spacing: Spacing.xs) {
            Text(label)
                .font(.app(13))
                .padding(textPadding)
            if let subLabel {
                Text(subLabel)
                    .font(.app(11))
                    .opacity(0.7)
            }
        }
    }
    
    /// 原生按钮的玻璃色调。
    private var tintColor: Color {
        switch type {
        case .normal: .white
        case .highlight: .accentColor
        case .red: .red
        }
    }
    
    private var tintOpacity: Double {
        if disabled { return 0.1 }
        switch type {
        case .normal: return hovered ? 0.7 : 0.5
        case .highlight, .red: return hovered ? 0.95 : 0.85
        }
    }
    
    private var foregroundColor: Color {
        switch type {
        case .normal: disabled ? Color.primary.opacity(0.35) : .primary
        case .highlight, .red: disabled ? Color.white.opacity(0.6) : .white
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
