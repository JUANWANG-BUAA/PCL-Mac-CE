//
//  InstallationDirectoryReservation.swift
//  PCLMacCE.Core
//

import Foundation

/// 独占声明新的实例目录，并且只清理当前任务声明的目录。
final class InstallationDirectoryReservation: @unchecked Sendable {
    let url: URL
    private let lock: NSLock = .init()
    private var isOwned: Bool = false

    init(url: URL) {
        self.url = url
    }

    func create() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isOwned else { throw SimpleError("安装目录已被当前任务占用。") }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            isOwned = true
        } catch {
            if FileManager.default.fileExists(atPath: url.path) {
                throw SimpleError("该实例目录已存在，请更换名称后重试。")
            }
            throw error
        }
    }

    func createIncompleteMarker() throws {
        lock.lock()
        defer { lock.unlock() }
        guard isOwned else { throw SimpleError("安装任务尚未创建实例目录。") }
        let marker: URL = url.appending(path: ".incomplete")
        guard FileManager.default.createFile(atPath: marker.path, contents: Data()) else {
            throw SimpleError("创建实例安装标记失败，无法继续安装。")
        }
    }

    /// 仅在其他收尾工作成功后，移除实例未完成标记。
    func markComplete() throws {
        lock.lock()
        defer { lock.unlock() }
        guard isOwned else { throw SimpleError("安装任务尚未创建实例目录。") }
        let marker: URL = url.appending(path: ".incomplete")
        guard FileManager.default.fileExists(atPath: marker.path) else {
            throw SimpleError("实例安装标记丢失，无法确认安装完整性。")
        }
        try FileManager.default.removeItem(at: marker)
    }

    func removeIfOwned() throws {
        lock.lock()
        defer { lock.unlock() }
        guard isOwned else { return }
        try FileManager.default.removeItem(at: url)
        isOwned = false
    }
}
