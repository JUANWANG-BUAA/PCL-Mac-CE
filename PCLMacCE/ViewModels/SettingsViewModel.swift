//
//  SettingsViewModel.swift
//  PCLMacCE
//

import Foundation
import ZIPFoundation
import Core

class SettingsViewModel: ObservableObject {
    public static let shared: SettingsViewModel = .init()

    private let dateFormatter: DateFormatter = {
        let formatter: DateFormatter = .init()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    public func exportLogs() async throws -> URL {
        let zipName: String = "PCLMacCE-logs-\(dateFormatter.string(from: .now)).zip"
        let destination: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Desktop/\(zipName)")
        // 日志目录可能较大，压缩放到后台线程执行
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.zipItem(at: URLConstants.logsDirectoryURL, to: destination, shouldKeepParent: false)
        }.value
        return destination
    }
}
