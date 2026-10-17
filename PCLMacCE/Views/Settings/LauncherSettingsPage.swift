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
    @State private var curseForgeKeyInput: String = ""
    @State private var hasCurseForgeKey: Bool = Secrets.shared.curseforgeApiKey != nil

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
                configLine(label: "CurseForge") {
                    MyTextField(text: $curseForgeKeyInput, placeholder: "粘贴 CurseForge API Key", secure: true)
                        .frame(width: 250)
                    MyButton("保存") {
                        saveCurseForgeKey()
                    }
                    .frame(width: 70)
                    if hasCurseForgeKey {
                        MyButton("清除") {
                            clearCurseForgeKey()
                        }
                        .frame(width: 70)
                    }
                    Spacer(minLength: 0)
                }
                MyTip(
                    text: hasCurseForgeKey
                        ? "已配置 CurseForge API Key（保存在本机，不会提交到仓库）。在 developers.curseforge.com 可申请或轮换。"
                        : "CurseForge 搜索与整合包导入需要 API Key。可免费申请：curseforge.com/developers。Key 仅保存在本机配置目录。",
                    theme: hasCurseForgeKey ? .blue : .yellow
                )
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

    /// 保存 CurseForge API Key 到本机覆盖文件并立即生效。
    private func saveCurseForgeKey() {
        let key: String = curseForgeKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            hint("请先粘贴 API Key", type: .critical)
            return
        }
        do {
            try Secrets.saveCurseForgeAPIKey(key)
            Secrets.shared.reload()
            hasCurseForgeKey = Secrets.shared.curseforgeApiKey != nil
            curseForgeKeyInput = ""
            hint("CurseForge API Key 已保存，立即生效", type: .finish)
        } catch {
            err("保存 CurseForge API Key 失败：\(error.localizedDescription)")
            hint("保存失败：\(error.localizedDescription)", type: .critical)
        }
    }

    /// 清除本机保存的 CurseForge API Key。
    private func clearCurseForgeKey() {
        do {
            try Secrets.saveCurseForgeAPIKey(nil)
            Secrets.shared.reload()
            hasCurseForgeKey = Secrets.shared.curseforgeApiKey != nil
            hint("已清除 CurseForge API Key", type: .finish)
        } catch {
            hint("清除失败：\(error.localizedDescription)", type: .critical)
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
