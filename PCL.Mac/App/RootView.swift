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
    // 提升为 @StateObject：避免 RootView 重新求值/主题重建时重置下载页与联机状态
    @StateObject private var downloadPageViewModel: MinecraftDownloadPageViewModel = .init()
    @StateObject private var multiplayerViewModel: MultiplayerViewModel = .init()
    @StateObject private var cardInteractionState: CardInteractionState = .init(isStatic: true)

    var body: some View {
        ContentView()
            .ignoresSafeArea(.all)
            .frame(minWidth: 1000, minHeight: 550)
            .environmentObject(instanceManager)
            .environmentObject(downloadPageViewModel)
            .environmentObject(multiplayerViewModel)
            .environmentObject(cardInteractionState)
            // 主题切换时重建整个视图树，使所有静态色板读取（Color.colorN 等）刷新
            .id(themeManager.theme)
    }
}
