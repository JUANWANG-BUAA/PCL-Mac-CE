//
//  AppWindow.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2025/11/29.
//

import SwiftUI
import Core
import Combine

private let osMajorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion

class AppWindow: NSWindow, NSWindowDelegate {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private var cancellables: Set<AnyCancellable> = []

    init(instanceManager: InstanceManager) {
        super.init(
            contentRect: .init(x: 0, y: 0, width: 1000, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        // 标题本身仍然设置：标题栏不显示它，但窗口菜单 / Mission Control / 辅助功能依赖该值
        self.title = "PCL.Mac"
        // 窗口透明：使侧栏/顶栏的玻璃层能透出桌面壁纸，呈现毛玻璃质感。
        // 底色全透明（原 0.25 浅色底会让整个主区域"蒙一层白"）：
        // 其当年的"防首帧黑"职责已由遮罩体系接管（首帧有遮罩、页面玻璃不会黑、
        // 失焦期整体被遮罩盖住），现在去掉只净收益——更通透、不损失任何稳定性。
        self.isOpaque = false
        self.backgroundColor = .clear
        // 允许在自绘顶栏的空白区域拖动窗口（原生体验）
        self.isMovableByWindowBackground = true

        // 缩放按钮：原生风格显示（可最大化/全屏），经典主题保持隐藏；主题切换时实时更新
        self.standardWindowButton(.zoomButton)?.isHidden = !ThemeManager.shared.theme.isNativeStyle
        ThemeManager.shared.$theme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                self?.standardWindowButton(.zoomButton)?.isHidden = !theme.isNativeStyle
            }
            .store(in: &cancellables)

        self.contentView = NSHostingView(rootView: RootView(instanceManager: instanceManager))
        self.delegate = self

        self.setFrameAutosaveName("AppWindow")
        self.center()
    }

    func windowDidUpdate(_ notification: Notification) {
        guard osMajorVersion >= 14 else { return }

        guard let close = standardWindowButton(.closeButton),
              let titlebarView = close.superview else {
            return
        }

        let offset = osMajorVersion >= 26 ? 9 : 11
        let origin = CGPoint(x: offset, y: -offset)
        guard titlebarView.frame.origin != origin else {
            return
        }

        titlebarView.frame.origin = origin
    }
}
