//
//  MultiplayerSettingsPage.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/2/1.
//

import SwiftUI

struct MultiplayerSettingsPage: View {
    var body: some View {
        CardContainer {
            MyCard("EasyTier 设置", foldable: false) {
                HStack {
                    MyButton("删除 EasyTier", type: .red) {
                        MessageBoxManager.shared.showText(
                            title: "删除 EasyTier",
                            content: "确定要删除 EasyTier 吗？\n删除后需要重新下载才能使用联机功能。",
                            level: .info,
                            .no(),
                            .yes(label: "删除", type: .red)
                        ) { result in
                            guard result == 1 else { return }
                            EasyTierManager.shared.delete()
                        }
                    }
                    .frame(minWidth: 150)
                    .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                }
                .frame(height: 35)
            }
        }
    }
}
