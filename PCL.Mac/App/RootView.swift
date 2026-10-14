//
//  RootView.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/4/16.
//

import SwiftUI
import Core

struct RootView: View {
    @ObservedObject var instanceManager: InstanceManager
    @ObservedObject private var themeManager: ThemeManager = .shared

    var body: some View {
        ContentView()
            .ignoresSafeArea(.all)
            .frame(minWidth: 1000, minHeight: 550)
            .environmentObject(instanceManager)
            .environmentObject(MinecraftDownloadPageViewModel())
            .environmentObject(MultiplayerViewModel())
            .environmentObject(CardInteractionState(isStatic: true))
            // 主题切换时重建整个视图树，使所有静态色板读取（Color.colorN 等）刷新
            .id(themeManager.theme)
    }
}
