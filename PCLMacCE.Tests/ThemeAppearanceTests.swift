//
//  ThemeAppearanceTests.swift
//  PCLMacCE.Tests
//

import Testing
import Foundation
import AppKit
@testable import PCLMacCE
import Core

struct ThemeAppearanceTests {
    /// Liquid Glass 必须跟随系统外观（appearance 为 nil），经典主题锁定浅色。
    /// 这是深色模式可用的前提：此前的强制 aqua 被移除后，不能再有任何路径重新锁死外观。
    @Test @MainActor func appearanceFollowsTheme() {
        let manager = ThemeManager.shared
        let originalTheme = manager.theme
        defer {
            // 恢复用户原有主题，避免测试污染真实配置
            manager.switchTo(originalTheme)
        }

        manager.switchTo(.liquidGlass)
        #expect(NSApplication.shared.appearance == nil)

        manager.switchTo(.classic)
        #expect(NSApplication.shared.appearance?.name == .aqua)
    }

    /// 深色外观下，Liquid Glass 的关键语义色不应退化为纯黑/纯白之外的不可读组合。
    /// 这里验证的是系统语义色的解析路径可用（真正的对比度仍需截图人工确认）。
    @Test @MainActor func semanticColorsResolveInDarkAppearance() {
        let dark = NSAppearance(named: .darkAqua)
        var resolvedCount = 0
        dark?.performAsCurrentDrawingAppearance {
            for color in [NSColor.labelColor, .secondaryLabelColor, .windowBackgroundColor, .textBackgroundColor] {
                let converted = color.usingColorSpace(.sRGB)
                #expect(converted != nil)
                resolvedCount += 1
            }
        }
        #expect(resolvedCount == 4)
    }
}
