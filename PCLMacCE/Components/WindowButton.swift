//
//  WindowButton.swift
//  PCLMacCE
//

import SwiftUI

struct WindowButton: View {
    @State private var hovered: Bool = false
    private let icon: ImageResource
    private let action: () -> Void

    init(_ icon: ImageResource, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }

    var body: some View {
        ZStack {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .padding(.top, 3)
                .foregroundStyle(ThemeManager.shared.theme.isNativeStyle ? Color.primary : .white)
            Circle()
                .fill(ThemeManager.shared.theme.isNativeStyle
                      ? Color.primary.opacity(hovered ? 0.1 : 0)
                      : .white.opacity(hovered ? 0.15 : 0))
                .frame(width: hovered ? 30 : 20)
        }
        .animation(.spring(response: 0.2), value: hovered)
        .frame(width: 30, height: 30)
        .contentShape(.rect)
        .onHover { isHovered in
            self.hovered = isHovered
        }
        .onTapGesture(perform: action)
    }
}
