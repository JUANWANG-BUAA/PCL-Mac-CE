//
//  LauncherSettingsPage.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct LauncherSettingsPage: View {
    /// 下载并发选项；`auto` 跟随下载源推荐值（海外官方源 64 / 镜像源 16）。
    private enum DownloadConcurrencyOption: Int, CaseIterable, CustomStringConvertible {
        case auto = 0
        case x2 = 2
        case x4 = 4
        case x8 = 8
        case x16 = 16

        var description: String {
            self == .auto ? "自动" : "\(rawValue) 并发"
        }
    }

    @State private var downloadSourcePolicy: DownloadSourcePolicy = LauncherConfig.shared.downloadSourcePolicy
    @State private var homepageType: LauncherConfig.HomepageType = LauncherConfig.shared.homepageType
    @State private var theme: AppTheme = ThemeManager.shared.theme
    @State private var downloadConcurrency: DownloadConcurrencyOption =
        LauncherConfig.shared.downloadConcurrency.flatMap(DownloadConcurrencyOption.init(rawValue:)) ?? .auto

    var body: some View {
        CardContainer {
            MyCard("下载", foldable: false) {
                configLine(label: "下载源") {
                    MySelect(
                        $downloadSourcePolicy,
                        entries: [.officialFirst, .mirrorFirst]
                    )
                    .frame(width: 250)
                }
                .onChange(of: downloadSourcePolicy) { newValue in
                    DownloadSourceManager.shared.policy = newValue
                    LauncherConfig.shared.downloadSourcePolicy = newValue
                    AppDelegate.saveConfigQuietly()
                }
                configLine(label: "并发数") {
                    MySelect(
                        $downloadConcurrency,
                        entries: DownloadConcurrencyOption.allCases
                    )
                    .frame(width: 250)
                }
                .onChange(of: downloadConcurrency) { newValue in
                    LauncherConfig.shared.downloadConcurrency = newValue == .auto ? nil : newValue.rawValue
                    DownloadSourceManager.shared.preferredConcurrency = LauncherConfig.shared.downloadConcurrency
                    AppDelegate.saveConfigQuietly()
                }
            }

            MyCard("外观", foldable: false) {
                configLine(label: "主题") {
                    MySelect(
                        $theme,
                        entries: AppTheme.allCases
                    )
                    .frame(width: 250)
                }
                .onChange(of: theme) { newValue in
                    ThemeManager.shared.switchTo(newValue)
                }
            }
            .cardIndex(1)

            MyCard("个性化", foldable: false) {
                configLine(label: "主页") {
                    MySelect(
                        $homepageType,
                        entries: [.empty, .demo]
                    )
                    .frame(width: 250)
                }
                .onChange(of: homepageType) { newValue in
                    LauncherConfig.shared.homepageType = newValue
                    AppDelegate.saveConfigQuietly()
                }
            }
            .cardIndex(2)
        }
    }

    @ViewBuilder
    private func configLine(label: String, @ViewBuilder body: () -> some View) -> some View {
        HStack(spacing: 20) {
            MyText(label)
                .frame(width: 80, alignment: .leading)
            HStack {
                Spacer(minLength: 0)
                body()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
    }
}
