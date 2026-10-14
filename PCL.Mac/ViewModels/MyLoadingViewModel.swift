//
//  MyLoadingViewModel.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/1/7.
//

import Foundation

class MyLoadingViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var text: String
    /// 失败后的重试动作；为 `nil` 时失败界面不显示重试按钮。
    private(set) var retryAction: (() -> Void)?
    private let initialText: String
    
    init(text: String) {
        self.text = text
        self.initialText = text
    }
    
    @MainActor
    func fail(with message: String, retry: (() -> Void)? = nil) {
        isFailed = true
        text = message
        retryAction = retry
    }
    
    @MainActor
    func reset() {
        text = initialText
        isFailed = false
        retryAction = nil
    }
}
