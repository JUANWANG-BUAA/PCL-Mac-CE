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
                nativeBody
            } else {
                pclBody
            }
        }
        .scaleEffect(isPressed ? (ThemeManager.shared.theme.isNativeStyle ? 0.97 : 0.85) : 1.0)
        .animation(.easeInOut(duration: 0.2), value: hovered)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        .onHover {
            guard !disabled else { return }
            hovered = $0
        }
        .gesture(
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
        )
    }

    /// 原生 macOS 风格：填充式按钮（与系统按钮的强调色/次级填充一致）。
    private var nativeBody: some View {
        let fill: Color
        let foreground: Color
        switch type {
        case .normal:
            fill = Color.primary.opacity(hovered ? 0.14 : 0.08)
            foreground = disabled ? Color.primary.opacity(0.35) : .primary
        case .highlight, .red:
            fill = hovered ? type.hoverColor : type.color
            foreground = disabled ? Color.white.opacity(0.6) : .white
        }
        return VStack(spacing: Spacing.xs) {
            Text(label)
                .font(.app(13))
                .foregroundStyle(foreground)
                .padding(textPadding)
            if let subLabel {
                Text(subLabel)
                    .font(.app(11))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(disabled ? Color.primary.opacity(0.05) : fill)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
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
    MyButton("实例选择", type: .highlight) {
        print("Button pressed")
    }
    .frame(width: 117, height: 32)
    .padding()
    .background(.white)
}
