//
//  MyListItem.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/12/5.
//

import SwiftUI

struct MyListItem<Content: View>: View {
    @State private var hovered: Bool = false
    @State private var backgroundScale: CGFloat = 0.92
    private let content: (Bool) -> Content

    init(_ content: @escaping (Bool) -> Content) {
        self.content = content
    }

    init(_ content: @escaping () -> Content) {
        self.init({ _ in content() })
    }

    init(_ model: ListItem, selected: Bool = false) where Content == AnyView {
        self.init {
            AnyView(
                HStack(spacing: 0) {
                    if selected && !ThemeManager.shared.theme.isNativeStyle {
                        // 经典主题：PCL 蓝色竖条
                        RightRoundedRectangle(cornerRadius: 2)
                            .fill(Color.color3)
                            .frame(width: 4, height: 24)
                            .offset(x: -4)
                    }
                    HStack {
                        if let image = model.image {
                            image.makeView()
                            .scaledToFit()
                            .frame(width: model.imageSize, height: model.imageSize)
                            .foregroundStyle(ThemeManager.shared.theme.isNativeStyle ? Color.primary : Color.color1)
                        }
                        VStack(alignment: .leading) {
                            MyText(model.name)
                                .lineLimit(1)
                            if let description = model.description {
                                MyText(description, color: .textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer()
                    if selected && ThemeManager.shared.theme.isNativeStyle {
                        // 原生风格：以对勾标记"当前选择"（与系统"当前项"语言一致），
                        // 不再使用 PCL 的蓝色竖条
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.trailing, 8)
                    }
                }
            )
        }
    }

    var body: some View {
        content(hovered)
            .frame(maxWidth: .infinity)
            .padding(4)
            .contentShape(Rectangle())
            .background {
                let isNative = ThemeManager.shared.theme.isNativeStyle
                RoundedRectangle(cornerRadius: isNative ? 6 : 4)
                    .fill(hovered ? (isNative ? Color.primary.opacity(0.06) : Color.color2.opacity(0.1)) : .clear)
                    .scaleEffect(backgroundScale)
                    .allowsHitTesting(false)
            }
            .onHover { hovered in
                let animation: Animation = ThemeManager.shared.theme.isNativeStyle
                    ? .easeOut(duration: 0.1)
                    : .spring(response: 0.2)
                withAnimation(animation) {
                    self.hovered = hovered
                    if hovered || ThemeManager.shared.theme.isNativeStyle {
                        backgroundScale = 1
                    } else {
                        backgroundScale = 0.92
                    }
                }
            }
    }
}

struct ListItemButton: View {
    @State private var pressed: Bool = false
    private let icon: ListItem.Image
    private let scale: Double
    private let clickPerform: () -> Void

    init(_ icon: ListItem.Image, scale: Double = 1.0, clickPerform: @escaping () -> Void) {
        self.icon = icon
        self.scale = scale
        self.clickPerform = clickPerform
    }

    var body: some View {
        icon.makeView()
            .scaledToFit()
            .frame(height: 16)
            .foregroundStyle(ThemeManager.shared.theme.isNativeStyle ? Color.accentColor : Color.color3)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        pressed = true
                    }
                    .onEnded { _ in
                        clickPerform()
                        pressed = false
                    }
            )
            .scaleEffect((pressed ? 0.8 : 1.0) * scale)
            .animation(.spring(response: 0.2), value: pressed)
    }
}

#Preview {
    MyListItem(.init(name: "Test", description: "lorem ipsum dolor sit amet consectetur"))
    .frame(width: 400, height: 50)
    .padding()
    .background(.white)
}
