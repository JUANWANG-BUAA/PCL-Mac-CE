//
//  MyExtraTextButton.swift
//  PCLMacCE
//

import SwiftUI

struct MyExtraTextButton: View {
    @State private var hovered: Bool = false
    @State private var pressed: Bool = false
    private let icon: ImageResource
    private let imageSize: CGFloat
    private let text: String
    private let action: () -> Void

    init(icon: ImageResource, imageSize: CGFloat, text: String, action: @escaping () -> Void) {
        self.icon = icon
        self.imageSize = imageSize
        self.text = text
        self.action = action
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: ThemeManager.shared.theme.isNativeStyle ? 10 : 1000)
                .fill(fillColor)
            HStack(spacing: 12) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: imageSize, height: imageSize)
                Text(text)
                    .font(.app(15))
                    .foregroundStyle(.white)
            }
            .padding()
        }
        .fixedSize(horizontal: true, vertical: true)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in
                    pressed = false
                    action()
                }
        )
        .onHover { hovered = $0 }
        .scaleEffect(pressed ? (ThemeManager.shared.theme.isNativeStyle ? 0.98 : 0.85) : 1, anchor: .center)
        .animation(.easeOut(duration: 0.1), value: hovered)
        .animation(.easeOut(duration: 0.1), value: pressed)
    }

    /// 原生风格的填充式按钮悬停时略微加深（macOS 语言），经典主题悬停变浅（PCL 语言）。
    private var fillColor: Color {
        if ThemeManager.shared.theme.isNativeStyle {
            return hovered ? Color.accentColor.opacity(0.88) : .accentColor
        }
        return hovered ? .color4 : .color3
    }
}
