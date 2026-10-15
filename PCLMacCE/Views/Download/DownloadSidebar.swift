//
//  DownloadSidebar.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct DownloadSidebar: Sidebar {
    @EnvironmentObject private var minecraftDownloadPageViewModel: MinecraftDownloadPageViewModel
    @ObservedObject private var router: AppRouter = .shared

    /// 当前下载上下文：在实例定向模式下切换资源类型时保留目标实例。
    private var context: InstallContext {
        if case .resourceDownload(_, let context) = router.last { return context }
        return .general
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        VStack(spacing: 4) {
            MyText("Minecraft", size: 12, color: isNative ? .secondary : .colorGray2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 13)
                .padding(.top, 10)
            MyNavigationList(
                .init(.minecraftDownload, .iconBlock, "游戏下载")
            ) { route in
                switch route {
                case .minecraftDownload:
                    minecraftDownloadPageViewModel.reload()
                default: break
                }
            }

            MyText("社区资源", size: 12, color: isNative ? .secondary : .colorGray2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 13)
                .padding(.top, 20)
            MyNavigationList(
                .init(.resourceDownload(type: .mod, context: context), .iconMod, "Mod"),
                .init(.resourceDownload(type: .resourcepack, context: context), .iconPicture, "资源包"),
                .init(.resourceDownload(type: .shader, context: context), .iconSun, "光影包"),
                .init(.resourceDownload(type: .modpack, context: context), .iconBox, "整合包")
            )
            Spacer()
        }
    }
}
