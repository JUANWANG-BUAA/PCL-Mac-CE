//
//  ToolboxPage.swift
//  PCL.Mac
//

import SwiftUI
import Core

struct ToolboxPage: View {
    @StateObject private var viewModel: ToolboxViewModel = .init()

    var body: some View {
        CardContainer {
            MyCard("百宝箱", foldable: false) {
                HStack {
                    MyButton("今日人品") {
                        let lucky: Int = viewModel.todayLucky
                        MessageBoxManager.shared.showText(
                            title: "今日人品 - \(viewModel.todayDate)",
                            content: "你今天的人品值是：\(viewModel.formatLucky(lucky))",
                            level: lucky <= 30 ? .error : .info
                        )
                    }
                    .frame(width: 120)

                    MyButton("千万别点", type: .red) {
                        MessageBoxManager.shared.showText(
                            title: "警告",
                            content: "PCL.Mac 作者不会受理由于点击千万别点造成的任何 Bug。\n这是最后的警告，是否继续操作？",
                            level: .error,
                            .init(id: 0, label: "确定", type: .red),
                            .init(id: 1, label: "确定", type: .normal),
                            .init(id: 2, label: "确定", type: .normal)
                        ) { _ in
                            viewModel.executeEasterEgg()
                        }
                    }
                    .frame(width: 120)
                    Spacer()
                }
                .frame(height: 40)
            }
        }
    }
}
