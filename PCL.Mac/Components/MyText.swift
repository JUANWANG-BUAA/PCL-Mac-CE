//
//  MyText.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/10.
//

import SwiftUI

struct MyText: View {
    private let text: String
    private let size: CGFloat
    private let color: Color?

    init(_ text: String, size: CGFloat = 14, color: Color? = nil) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.app(size))
            .foregroundStyle(color ?? defaultColor)
    }

    /// 默认文字色：原生风格使用语义色（可随侧栏的深色外观自动变白），经典主题使用色板正文色。
    private var defaultColor: Color {
        ThemeManager.shared.theme.isNativeStyle ? .primary : .color1
    }
}
