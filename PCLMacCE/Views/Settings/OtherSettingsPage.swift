//
//  OtherSettingsPage.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct OtherSettingsPage: View {
    var body: some View {
        CardContainer {
            MyCard("调试", foldable: false) {
                HStack {
                    MyButton("导出日志") {
                        hint("正在导出日志……")
                        Task {
                            do {
                                let url: URL = try await SettingsViewModel.shared.exportLogs()
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } catch {
                                err("导出日志失败：\(error.localizedDescription)")
                                hint("导出日志失败：\(error.localizedDescription)", type: .critical)
                            }
                        }
                    }
                    .frame(width: 150)
                    Spacer()
                }
                .frame(height: 40)

                Text("功能开关")
                    .foregroundStyle(Color.color1)
                    .font(.cardTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                MyTip(text: "以下开关用于控制实验性功能及未经充分验证的更改。除非你了解其影响，否则请不要更改它们！", theme: .yellow)

                VStack(alignment: .leading) {
                    MyComboBox(checked: binding(of: .deduplicateLibraries), text: "去除同一清单中的重复依赖库")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }

            MyCard("启动器更新", foldable: false) {
                HStack {
                    MyButton("检查更新") {
                        UpdateService.shared.runInteractiveUpdateFlow(manually: true)
                    }
                    .frame(width: 150)
                    Spacer()
                }
                .frame(height: 40)
            }
        }
    }

    private func binding(of flag: FeatureFlag) -> Binding<Bool> {
        return .init(
            get: { FlagsManager.shared.isEnabled(flag) },
            set: { FlagsManager.shared.setEnabled(flag, enabled: $0) }
        )
    }
}
