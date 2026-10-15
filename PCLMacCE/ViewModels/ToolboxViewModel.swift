//
//  ToolboxViewModel.swift
//  PCLMacCE
//

import SwiftUI
import GameplayKit
import Core

class ToolboxViewModel: ObservableObject {
    public lazy var todayDate: String = {
        let formatter: DateFormatter = .init()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: .now)
    }()

    public lazy var todayLucky: Int = {
        let key: String = "\(NSUserName())\(todayDate))"
        var seed: UInt64 = 0
        for byte in key.utf8 {
            seed = seed &* 257 &+ UInt64(byte)
        }
        let rng: GKMersenneTwisterRandomSource = .init(seed: seed)
        return rng.nextInt(upperBound: 100) + 1
    }()

    /// 将今日人品值转换为在 UI 上显示的文本。
    /// - Parameter value: 今日人品值。
    /// - Returns: 处理后的文本。
    public func formatLucky(_ value: Int) -> String {
        // https://github.com/PCL-Community/PCL-CE/blob/0965ff4779c2c8946ed54338b7443534c57b120e/Plain%20Craft%20Launcher%202/Pages/PageTools/PageToolsTest.xaml.vb#L501-L513
        if value >= 100 {
            return "\(value)！\(value)！\(value)！\n隐藏主题 欧皇…… 不对，主题系统好像还没做……"
        } else if value >= 95 {
            return "\(value)！差一点就到100了呢…"
        } else if value >= 90 {
            return "\(value)！好评如潮！"
        } else if value >= 60 {
            return "\(value)！还行啦，还行啦。"
        } else if value >= 40 {
            return "\(value)…勉强还行吧…"
        } else if value >= 30 {
            return "\(value)…呜…"
        } else if value >= 10 {
            return "\(value)…不会吧！"
        } else {
            return "\(value)…（是百分制哦）"
        }
    }

    /// 执行“千万别点”彩蛋。
    @MainActor
    public func executeEasterEgg() {
        let value: Int = .random(in: 0..<4)
        let easterEggManager: EasterEggManager = .shared
        switch value {
        case 0:
            NSWorkspace.shared.open(.init(string: "https://www.bilibili.com/video/BV1GJ411x7h7")!)
        case 1:
            guard easterEggManager.enable() else { break }
            easterEggManager.rotationAxis = (0, 0, 1)
            withAnimation(.linear(duration: 0.5)) {
                easterEggManager.rotationAngle = .degrees(180)
            }
        case 2:
            guard easterEggManager.enable() else { break }
            easterEggManager.rotationAxis = (0, 1, 0)
            easterEggManager.rotateTask?.cancel()
            easterEggManager.rotateTask = Task { @MainActor in
                var degrees: Double = 0
                while !Task.isCancelled {
                    degrees += 45
                    withAnimation(.linear(duration: 0.2)) {
                        easterEggManager.rotationAngle = .degrees(degrees)
                    }
                    try await Task.sleep(seconds: 0.19)
                }
            }
        case 3:
            easterEggManager.modifyColor = true
        default:
            break
        }
    }
}
