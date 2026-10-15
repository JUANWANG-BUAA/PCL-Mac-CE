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

    public func exportLogs() throws -> URL {
        let destination: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Desktop/PCLMacCE-logs-\(dateFormatter.string(from: .now)).zip")
        try FileManager.default.zipItem(at: URLConstants.logsDirectoryURL, to: destination, shouldKeepParent: false)
        return destination
    }
}
