//
//  LaunchPage.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct LaunchPage: View {
    var body: some View {
        switch LauncherConfig.shared.homepageType {
        case .empty:
            emptyHomepage
        case .demo: DemoHomepageView()
        }
    }

    /// 空白主页的空状态：避免大片无内容的空白，提供简明引导。
    private var emptyHomepage: some View {
        VStack(spacing: 10) {
            Image(.iconGrassBlock)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .opacity(ThemeManager.shared.theme.isNativeStyle ? 0.8 : 0.35)
            MyText(
                "在左侧选择一个实例，点击「启动游戏」开始游玩",
                color: ThemeManager.shared.theme.isNativeStyle ? .primary : .textSecondary
            )
                .padding(.top, 4)
            MyText(
                "你可以在「下载」页面安装新的游戏版本与 Mod",
                size: 12,
                color: ThemeManager.shared.theme.isNativeStyle ? .secondary : .textTertiary
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
