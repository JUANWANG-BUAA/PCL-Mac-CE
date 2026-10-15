//
//  MessageBoxView.swift
//  PCLMacCE
//

import SwiftUI

struct MessageBoxView: View {
    private let model: MessageBoxModel
    @State private var selectedItemIndex: Int?
    @State private var inputText: String = ""

    init(model: MessageBoxModel) {
        self.model = model
    }

    var body: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        ZStack {
            if isNative {
                // 原生风格：官方玻璃浮层（与顶栏胶囊/按钮同一材质语言），
                // 替代此前的 WinUI Acrylic（噪点 + 白描边是 Windows 语言）
                Color.clear
                    .glassBackground(in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 26)
            } else {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.white)
                    .shadow(color: .color1.opacity(0.8), radius: 20)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(model.title)
                    .font(isNative ? .system(size: 17, weight: .semibold) : .custom("PCLEnglish", size: 23))
                    .foregroundStyle(foregroundColor)
                    .padding(.leading, 7)
                Rectangle()
                    .fill(foregroundColor)
                    .frame(height: isNative ? 1 : 2)
                    .opacity(isNative ? 0.2 : 1)
                    .padding(.top, 9)
                    .padding(.bottom, isNative ? 10 : 13)
                content
                    .frame(minHeight: 1)
                    .padding(.horizontal, 7)
                    .padding(.bottom, 17)
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    ForEach(model.buttons, id: \.id) { button in
                        MyButton(button.label, textPadding: .init(top: 7, leading: 12, bottom: 7, trailing: 12), type: button.type) {
                            onButtonTap(button)
                        }
                        .fixedSize()
                    }
                }
            }
            .padding(22)
        }
        .frame(minWidth: 400, maxWidth: 800)
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            if case .input(let initialContent, _) = model.content, let initialContent {
                inputText = initialContent
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .messageBoxConfirm)) { _ in
            confirmWithKeyboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: .messageBoxCancel)) { _ in
            cancelWithKeyboard()
        }
    }

    /// 回车：触发主按钮（优先 highlight，其次 id 为 1 的按钮，再次最后一个按钮）。
    private func confirmWithKeyboard() {
        let button = model.buttons.first(where: { $0.type == .highlight })
            ?? model.buttons.first(where: { $0.id == 1 })
            ?? model.buttons.last
        guard let button else { return }
        onButtonTap(button)
    }

    /// ESC：触发取消按钮（id 为 0 或 cancelButtonID）；
    /// 单按钮弹窗按 macOS 惯例等同于点按该按钮，多按钮且无取消按钮时不响应。
    private func cancelWithKeyboard() {
        if let button = model.buttons.first(where: { $0.id == 0 || $0.id == MessageBoxManager.cancelButtonID }) {
            onButtonTap(button)
            return
        }
        if model.buttons.count == 1, let button = model.buttons.first {
            onButtonTap(button)
        }
    }

    /// 弹窗标题与分隔线的颜色。
    /// 原生风格使用正文色（macOS 面板标题从不着品牌色）；经典主题保留 PCL 品牌蓝/红。
    private var foregroundColor: Color {
        if ThemeManager.shared.theme.isNativeStyle { return .primary }
        return switch model.level {
        case .info: .color2
        case .error: .red
        }
    }

    private var content: some View {
        Group {
            switch model.content {
            case .text(let text):
                MyText(text)
            case .list(let items):
                ScrollView {
                    MyList(items: items, onSelect: { self.selectedItemIndex = $0 })
                        .padding(.horizontal, 4)
                }
                .frame(maxHeight: 240)
            case .input(_, let placeholder):
                MyTextField(text: $inputText, placeholder: placeholder ?? "")
            }
        }
    }

    private func onButtonTap(_ button: MessageBoxModel.Button) {
        switch model.content {
        case .text:
            MessageBoxManager.shared.onButtonTap(button)
        case .list:
            if button.id == MessageBoxManager.cancelButtonID { // 取消
                MessageBoxManager.shared.onListSelect(index: nil)
            } else if button.id == MessageBoxManager.okButtonID { // 确定
                MessageBoxManager.shared.onListSelect(index: selectedItemIndex)
            } else {
                MessageBoxManager.shared.onButtonTap(button)
            }
        case .input:
            if button.id == MessageBoxManager.cancelButtonID { // 取消
                MessageBoxManager.shared.onInputFinished(text: nil)
            } else if button.id == MessageBoxManager.okButtonID { // 确定
                MessageBoxManager.shared.onInputFinished(text: inputText)
            } else {
                MessageBoxManager.shared.onButtonTap(button)
            }
        }
    }
}

#Preview {
    MessageBoxView(
        model: .init(
            title: "测试",
            content: .text(text: "test"),
            level: .info,
            buttons: [
                .init(id: 0, label: "高亮", type: .highlight),
                .init(id: 1, label: "普通", type: .normal),
                .init(id: 2, label: "千万别点", type: .red)
            ]
        )
    )
    .padding()
}
