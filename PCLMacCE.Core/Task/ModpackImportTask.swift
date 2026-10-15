//
//  ModpackImportTask.swift
//  PCLMacCE
//

import Foundation
import ZIPFoundation

public enum ModpackImportTask {
    public static func create(
        modpackDirectory: URL,
        index: ModpackIndex,
        repository: MinecraftRepository,
        name: String,
        completion: (@MainActor (MinecraftInstance) -> Void)? = nil
    ) -> MyTask<Model> {
        let minecraftInstallTask: MyTask<Model> = MinecraftInstallTask.create(
            name: name,
            version: index.minecraftVersion,
            repository: repository,
            modLoader: index.modLoader.map { .init(type: $0.0, version: $0.1) },
            completion: completion
        )
        var subTasks: [MyTask<Model>.SubTask] = minecraftInstallTask.subTasks

        subTasks.insert(
            contentsOf: [
                .init(6, "下载整合包所需文件") { task, model in
                    try await downloadModpackFiles(index: index, model: model, task: task)
                },
                .init(7, "应用整合包修改") { _, model in
                    try applyOverrides(index.overridesDirectories, from: modpackDirectory, to: model.runningDirectory)
                }
            ],
            at: subTasks.count - 2
        )

        return .init(
            name: "整合包安装：\(index.name)",
            model: minecraftInstallTask.model,
            subTasks
        ) { _ in
            // 复用安装子任务时也必须继承失败清理。
            cleanupFailedImport(at: repository.versionsDirectory.appending(path: name))
        }
    }

    private static func downloadModpackFiles(index: ModpackIndex, model: Model, task: MyTask<Model>.SubTask) async throws {
        let progressHandler = await ConcurrentProgressHandler(totalHandler: task.setProgress(_:))
        let fetchProgressHandler = await progressHandler.handler(withMultiplier: 0.2)
        let total = Double(index.files.count)
        var completed = 0.0
        var downloadItems: [DownloadItem] = []
        await progressHandler.startCalculate()

        do {
            try await withThrowingTaskGroup(of: DownloadItem.self) { group in
                var remaining = index.files.makeIterator()
                for _ in 0..<min(16, index.files.count) {
                    guard let file = remaining.next() else { break }
                    group.addTask {
                        try await fetchDownloadItem(file, in: model.runningDirectory)
                    }
                }
                while let item = try await group.next() {
                    downloadItems.append(item)
                    completed += 1
                    await fetchProgressHandler(completed / total)
                    if let file = remaining.next() {
                        group.addTask {
                            try await fetchDownloadItem(file, in: model.runningDirectory)
                        }
                    }
                }
            }
            if index.files.isEmpty { await fetchProgressHandler(1) }
            let downloadProgressHandler = await progressHandler.handler(withMultiplier: 0.8)
            try await FileDownloader.shared.download(files: downloadItems, progressHandler: downloadProgressHandler)
            await progressHandler.stopCalculate()
        } catch {
            await progressHandler.cancelCalculate()
            throw error
        }
    }

    private static func fetchDownloadItem(_ file: ModpackIndex.File, in directory: URL) async throws -> DownloadItem {
        try await file.fetchInfo()
        guard let url = file.url, let path = file.path else {
            throw SimpleError("整合包资源缺少下载地址或目标路径。")
        }
        let destination = try validatedDestination(for: path, in: directory)
        return .init(url: url, destination: destination, checksums: file.checksums ?? [:])
    }

    private static func applyOverrides(_ names: [String], from source: URL, to destination: URL) throws {
        for name in names {
            let directory = try validatedDestination(for: name, in: source)
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            do {
                try apply(directory, to: destination)
            } catch {
                throw Error.failedToApplyOverrides(underlying: error)
            }
        }
    }

    private static func cleanupFailedImport(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            err("清理失败的整合包实例失败：\(error.localizedDescription)")
        }
    }

    public typealias Model = MinecraftInstallTask.Model

    /// 索引来自外部整合包，不允许绝对路径、`.` / `..` 或反斜杠逃出实例目录。
    static func validatedDestination(for path: String, in directory: URL) throws -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), !path.contains("\\"),
              parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw SimpleError("整合包包含非法文件路径：\(path)")
        }
        var destination = directory
        for part in parts {
            destination = destination.appending(path: String(part))
            // 即使末尾文件尚不存在，也要逐级检查已存在的符号链接。
            if (try? destination.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw SimpleError("整合包文件路径包含符号链接：\(path)")
            }
        }
        return destination
    }

    public enum Error: LocalizedError {
        case failedToCreateEnumerator
        case failedToApplyOverrides(underlying: Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .failedToCreateEnumerator:
                "创建文件枚举器失败。"
            case .failedToApplyOverrides(let underlying):
                "应用整合包修改失败：\(underlying.localizedDescription)"
            }
        }
    }

    fileprivate static func apply(_ source: URL, to destination: URL) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            throw Error.failedToCreateEnumerator
        }

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else {
                throw SimpleError("整合包覆盖目录含符号链接：\(fileURL.lastPathComponent)")
            }
            guard values.isDirectory == false else { continue }
            do {
                let relativePath = fileURL.pathComponents.dropFirst(source.pathComponents.count).joined(separator: "/")
                let dest = try validatedDestination(for: relativePath, in: destination)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                log("正在拷贝文件 \(fileURL.lastPathComponent)")
                try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: fileURL, to: dest)
            }
        }
    }
}

public enum SimpleModpackImportTask {
    public static func create(
        modpackDirectory: URL,
        index: ModpackIndex,
        repository: MinecraftRepository,
        name: String,
        completion: (@MainActor (MinecraftInstance) -> Void)? = nil
    ) -> MyTask<Model> {
        let runningDirectory = repository.versionsDirectory.appending(path: name)

        return .init(
            name: "整合包安装：\(index.name)",
            .init(0, "拷贝整合包文件") { _, _ in
                try FileManager.default.createDirectory(at: runningDirectory, withIntermediateDirectories: true)
                try Data().write(to: runningDirectory.appending(path: ".incomplete"), options: .atomic)

                for dirName in index.overridesDirectories {
                    let overridesDirectory = try ModpackImportTask.validatedDestination(for: dirName, in: modpackDirectory)
                    if FileManager.default.fileExists(atPath: overridesDirectory.path) {
                        do {
                            try ModpackImportTask.apply(overridesDirectory, to: runningDirectory)
                        } catch {
                            throw ModpackImportTask.Error.failedToApplyOverrides(underlying: error)
                        }
                    }
                }
            },
            .init(1, "__completion", display: false) { _, _ in
                try? FileManager.default.removeItem(at: runningDirectory.appending(path: ".incomplete"))
                try await repository.load()
                guard let instance = repository.instance(named: name) else {
                    try? FileManager.default.removeItem(at: runningDirectory)
                    throw SimpleError("该实例无法被加载。")
                }
                await MainActor.run {
                    completion?(instance)
                }
            }
        ) { _ in
            try? FileManager.default.removeItem(at: runningDirectory)
        }
    }

    public typealias Model = EmptyModel
}
