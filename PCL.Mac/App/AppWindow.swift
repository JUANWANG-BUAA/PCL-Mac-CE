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
