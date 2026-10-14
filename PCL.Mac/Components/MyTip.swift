//
//  MyTip.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/2/13.
//

import SwiftUI

struct MyTip: View {
    private let text: String
    private let theme: Theme
    private let actionLabel: String?
    private let action: (() -> Void)?

    init(text: String, theme: Theme, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        self.text = text
        self.theme = theme
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        HStack(spacing: 0) {
            if !isNative {
                Rectangle()
                    .fill(theme.borderColor)
                    .frame(width: 3)
            }
            MyText(text, color: theme.foregroundColor)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 9)
            Spacer(minLength: 0)
            if let actionLabel, let action {
                ZStack {
                    MyButton(actionLabel, textPadding: .init(top: -1, leading: 6, bottom: -1, trailing: 6)) {
                        action()
                    }
                }
                .frame(height: 22)
                .padding(.trailing, 10)
            }
        }
        .background(theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: isNative ? 6 : Radius.xs))
        .fixedSize(horizontal: false, vertical: true)
    }

    enum Theme {
        case blue, red, yellow

        var borderColor: Color {
            let hex: UInt = switch self {
            case .blue: 0x1172D4
            case .red: 0xD82929
            case .yellow: 0xF57A00
            }
            return .init(hex)
        }

        var backgroundColor: Color {
            let hex: UInt = switch self {
            case .blue: 0xD9ECFF
            case .red: 0xFFDDDF
            case .yellow: 0xFFEBD7
            }
            return .init(hex)
        }

        var foregroundColor: Color {
            let hex: UInt = switch self {
            case .blue: 0x0F64B8
            case .red: 0xBF0B0B
            case .yellow: 0xD86C00
            }
            return .init(hex)
        }
    }
}

#Preview {
    VStack {
        MyTip(text: "Test", theme: .red)
        MyTip(text: "Test", theme: .yellow)
        MyTip(text: "Test", theme: .blue)
    }
    .padding()
}
