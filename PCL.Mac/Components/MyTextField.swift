//
//  MyTextField.swift
//  PCL.Mac
//

import SwiftUI

struct MyTextField: View {
    @Binding private var text: String
    @State private var hovered: Bool = false
    @FocusState private var focused: Bool
    private let placeholder: String
    private let secure: Bool

    init(text: Binding<String>, placeholder: String = "", secure: Bool = false) {
        self._text = text
        self.placeholder = placeholder
        self.secure = secure
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Group {
                if secure {
                    SecureField("", text: _text)
                } else {
                    TextField("", text: _text)
                }
            }
            .textFieldStyle(.plain)
            .focused($focused)
            .padding(.horizontal, 6)
            .foregroundStyle(Color.color1)
            .onSubmit {
                focused = false
            }

            if !focused && text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 6)
                    .allowsHitTesting(false)
            }

            if ThemeManager.shared.theme.isNativeStyle {
                // 原生风格聚焦环
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor.opacity(focused ? 0.7 : 0), lineWidth: 2)
                    .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(foregroundColor, lineWidth: 1.5, antialiased: false)
                    .allowsHitTesting(false)
            }
        }
        .onHover { hovered = $0 }
        .animation(.linear(duration: 0.1), value: hovered)
        .animation(.linear(duration: 0.1), value: focused)
        .onChange(of: text) { newValue in
            if newValue.contains("\n") {
                self.text = newValue.replacingOccurrences(of: "\n", with: "")
            }
        }
        .background(
            ThemeManager.shared.theme.isNativeStyle
                ? Color.primary.opacity(focused ? 0.08 : 0.05)
                : backgroundColor,
            in: RoundedRectangle(cornerRadius: ThemeManager.shared.theme.isNativeStyle ? 6 : 4)
        )
        .frame(height: 26)
    }

    private var foregroundColor: Color {
        if focused { return .color3 }
        if hovered { return .color4 }
        return .color5
    }

    private var backgroundColor: Color {
        if focused || hovered { return .color7 }
        return .white.opacity(0.5)
    }
}
