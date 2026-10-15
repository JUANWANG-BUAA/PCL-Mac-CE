//
//  MySearchBox.swift
//  PCLMacCE
//

import SwiftUI

struct MySearchBox: View {
    @State private var query: String = ""
    @FocusState private var focused: Bool
    private let placeholder: String
    private let onSubmit: (String) -> Void

    init(placeholder: String, onSubmit: @escaping (String) -> Void) {
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        MyCard(nil) {
            HStack {
                Image(.iconSearch)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(ThemeManager.shared.theme.isNativeStyle ? Color.secondary : Color.color1)

                ZStack(alignment: .leading) {
                    TextField("", text: $query)
                        .textFieldStyle(.plain)
                        .foregroundStyle(ThemeManager.shared.theme.isNativeStyle ? Color.primary : Color.color1)
                    if !focused && query.isEmpty {
                        Text(placeholder)
                            .allowsHitTesting(false)
                            .foregroundStyle(ThemeManager.shared.theme.isNativeStyle ? Color.primary.opacity(0.35) : Color.colorGray3)
                    }
                }
                .font(.app(16))
                .focused($focused)
                .onChange(of: query) { _ in
                    if query.count > 50 {
                        query = String(query.prefix(50))
                    }
                }
                .onSubmit {
                    focused = false
                    onSubmit(query)
                }
            }
        }
        .frame(height: ThemeManager.shared.theme.isNativeStyle ? 34 : 40)
    }
}
