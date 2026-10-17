//
//  DownloadSpeedManager.swift
//  PCLMacCE
//

import Foundation

public final class DownloadSpeedManager: ObservableObject, @unchecked Sendable {
    public static let shared: DownloadSpeedManager = .init()

    @Published public private(set) var currentSpeed: Int64 = 0
    private var tickerTask: Task<Void, Error>?
    private let bytesLock: NSLock = .init()
    private var bytes: Int64 = 0

    private init() {
        self.tickerTask = .init(priority: .background) {
            while !Task.isCancelled {
                try await Task.sleep(seconds: 1)
                await updateSpeed()
            }
        }
    }

    @MainActor
    private func updateSpeed() {
        bytesLock.lock()
        let latestBytes: Int64 = bytes
        bytes = 0
        bytesLock.unlock()
        currentSpeed = latestBytes
    }

    public func addBytes(_ bytes: Int64) {
        bytesLock.lock()
        self.bytes += bytes
        bytesLock.unlock()
    }
}
