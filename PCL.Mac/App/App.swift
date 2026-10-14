//
//  PCL_MacApp.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/8.
//

import SwiftUI

@main
struct PCLMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate: AppDelegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button {
                        AppRouter.shared.setRoot(.settings)
                    } label: {
                        Label("设置", systemImage: "gear")
                    }
                    .keyboardShortcut(",", modifiers: [.command])
                }
                CommandMenu("导航") {
                    // Escape 快捷键由 AppDelegate 的本地监视器处理（菜单项无法承载 Esc 键等效），
                    // 这里提供菜单入口本身可用
                    Button("返回") {
                        guard AppRouter.shared.isSubPage else { return }
                        AppRouter.shared.removeLast()
                    }
                }
            }
        // 主视图声明被移至 AppWindow.swift:26
    }
}
