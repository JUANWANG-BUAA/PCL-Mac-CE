//
//  TitleBarView.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/10.
//

import SwiftUI
import Core

struct TitleBarView: View {
    @ObservedObject private var router: AppRouter = .shared
    @ObservedObject private var flagsManager: FlagsManager = .shared

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        ZStack(alignment: .leading) {
            if !isNative {
                Rectangle()
                    .fill(.blue)
            } else {
                // 原生风格：工具栏材质（与系统 toolbar 一致）
                Rectangle()
                    .fill(.bar)
            }
            Group {
                if router.isSubPage {
                    HStack {
                        WindowButton(.btnBack) {
                            router.removeLast()
                        }
                        MyText(router.title, size: 16, color: isNative ? .primary : .white)
                    }
                } else {
                    HStack {
                        Image(.iconTitleLogo)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(isNative ? Color.primary : .white)
                            .frame(height: 19)
                        MyTag("Mac", labelColor: isNative ? .primary : .color2, backgroundColor: isNative ? Color.primary.opacity(0.08) : .white)

                        if Metadata.debugMode {
                            MyTag("Debug", backgroundColor: Color(0x9BF00B))
                        }
                    }
                    HStack {
                        Spacer()
                        PageButton("启动", .iconLaunchPage, .launch)
                        PageButton("下载", .iconDownloadPage, .download)
                        if flagsManager.isEnabled(.multiplayer) {
                            PageButton("联机", .iconMultiplayerPage, .multiplayer)
                        }
                        PageButton("设置", .iconSettingsPage, .settings)
                        PageButton("更多", .iconMorePage, .more)
                        Spacer()
                    }
                }
            }
            .padding(.leading, 65)
        }
        .frame(height: 48)
    }
}

private struct PageButton: View {
    @ObservedObject private var router: AppRouter = .shared
    @State private var hovered: Bool = false
    private var isRoot: Bool { router.root == route }
    private let label: String
    private let icon: ImageResource
    private let route: AppRoute

    init(_ label: String, _ icon: ImageResource, _ route: AppRoute) {
        self.label = label
        self.icon = icon
        self.route = route
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(backgroundColor)
            HStack(spacing: 7) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                    .foregroundStyle(foregroundColor)
                MyText(label, color: foregroundColor)
            }
        }
        .frame(width: 78, height: 27)
        .contentShape(Rectangle())
        .onHover { hovered in
            self.hovered = hovered
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if router.root != route {
                        router.setRoot(route)
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isRoot)
        .animation(.easeInOut(duration: 0.2), value: hovered)
    }

    private var foregroundColor: Color {
        if ThemeManager.shared.theme.isNativeStyle {
            return isRoot ? .primary : Color.primary.opacity(0.75)
        }
        return isRoot ? .color2 : .white
    }

    private var backgroundColor: Color {
        if ThemeManager.shared.theme.isNativeStyle {
            return isRoot ? Color.primary.opacity(0.1) : (hovered ? Color.primary.opacity(0.05) : .clear)
        }
        return .white.opacity(isRoot ? 1 : hovered ? 0.25 : 0)
    }
}
