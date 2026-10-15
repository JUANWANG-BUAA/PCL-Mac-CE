//
//  MyComboBox.swift
//  PCLMacCE
//

import SwiftUI

struct MyComboBox: View {
    @Binding private var checked: Bool
    @State private var hovered: Bool = false
    @State private var scale: CGFloat = 1.0
    @State private var checkedScale: CGFloat = 0.0
    @State private var canClick: Bool = true
    private let text: String

    private let scaleAnimation: Animation = .spring(response: 0.3, dampingFraction: 0.5)

    init(checked: Binding<Bool>, text: String) {
        self._checked = checked
        self.text = text
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        HStack(spacing: 8) {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(borderColor, lineWidth: 1.1)
                    .background {
                        // 原生风格：选中时填充强调色（与系统复选框一致）
                        if isNative && checked {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .scaleEffect(scale, anchor: .center)

                Image(.iconTaskFinished)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12)
                    .scaleEffect(checkedScale)
                    .foregroundStyle(checkColor)
            }
            MyText(text, color: textColor)
        }
        .frame(minWidth: 20, minHeight: 20)
        .fixedSize()
        .contentShape(.rect)
        .onHover { hovered = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !canClick { return }
                    withAnimation(.spring(duration: 0.3)) {
                        scale = 0.95
                    }
                }
                .onEnded { _ in
                    if !canClick { return }
                    canClick = false
                    withAnimation(.spring(duration: 0.1)) {
                        scale = 0.5
                    }

                    let checked = checked
                    self.checked.toggle()

                    if checked {
                        withAnimation(scaleAnimation) {
                            checkedScale = 0
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(scaleAnimation) {
                            scale = 1
                            if !checked { checkedScale = 1 }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            canClick = true
                        }
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: hovered)
        .animation(scaleAnimation, value: checked)
        .onAppear {
            checkedScale = checked ? 1 : 0
        }
        .onChange(of: checked) { newValue in
            guard canClick else { return }
            withAnimation(scaleAnimation) {
                checkedScale = newValue ? 1 : 0
            }
        }
    }

    /// 原生风格使用系统复选框语言：未选中为灰色描边（悬停加深），选中为强调色填充；
    /// 经典主题保留悬停变蓝的 PCL 风格。
    private var borderColor: Color {
        if ThemeManager.shared.theme.isNativeStyle {
            if checked { return .accentColor }
            return Color.primary.opacity(hovered ? 0.5 : 0.32)
        }
        return hovered ? .color3 : checked ? .color2 : .color1
    }

    private var checkColor: Color {
        ThemeManager.shared.theme.isNativeStyle ? .white : (hovered ? .color3 : .color2)
    }

    private var textColor: Color {
        ThemeManager.shared.theme.isNativeStyle ? .primary : (hovered ? .color3 : .color1)
    }
}

#Preview {
    PreviewView()
}

private struct PreviewView: View {
    @State private var checked: Bool = false

    var body: some View {
        MyComboBox(checked: $checked, text: "复选框")
            .padding()
            .background(.white)
    }
}
