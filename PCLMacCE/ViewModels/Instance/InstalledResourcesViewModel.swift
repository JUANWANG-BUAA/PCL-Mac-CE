//
//  InstalledResourcesViewModel.swift
//  PCLMacCE
//

import Foundation
import AppKit
import Core
import Combine

@MainActor
class InstalledResourcesViewModel: ObservableObject {
    @Published public var resources: [ResourceDisplayModel]?
    @Published public var supportMods: Bool = true
    @Published public var currentRepositoryId: UUID
    @Published public var currentPage: Int = 0
    @Published public var pageCount: Int = 0
    @Published public var checkingUpdates: Bool = false

    public let type: ResourceType
    public var hasSearchKeyword: Bool { !searchKeyword.isEmpty }
    /// 当前搜索关键字，用于空态文案展示。
    public var currentSearchKeyword: String { searchKeyword }
    private var cancellables: Set<AnyCancellable> = []
    private var loadResult: [(URL, Resource)]?
    /// 更新检查结果：文件 URL → 可用更新；翻页重建显示模型时保持标记。
    private var updateMap: [URL: ResourceDisplayModel.ResourceUpdate] = [:]
    private var convertTask: Task<Void, Never>?
    private var searchKeyword: String = ""
    private let instance: MinecraftInstance?
    let id: String
    private let entriesPerPage: Int = 20

    private let service: ResourceLoadService

    init(instanceManager: InstanceManager, id: String, type: ResourceType) {
        self.instance = instanceManager.currentRepository.instance(named: id)
        self.id = id
        self.type = type
        self.currentRepositoryId = instanceManager.currentRepositoryId
        self.service = .init(
            preferredType: type,
            remoteLookupService: .init(curseforgeClient: .init(apiKey: Secrets.shared.curseforgeApiKey ?? "")),
            cache: .shared
        )

        instanceManager.$currentRepositoryId
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentRepositoryId, on: self)
            .store(in: &cancellables)
    }

    func load(resetPage: Bool = true) async throws {
        guard let instance else { throw SimpleError("实例不存在。") }

        if type == .mod && instance.modLoader == nil {
            supportMods = false
            return
        }

        let result: [(URL, Resource)] = try await service.loadResources(in: directory()!)
            .map { ($0, $1) }
            .sorted { $0.1.name.compare($1.1.name, options: .literal) == .orderedAscending }

        self.loadResult = result
        self.updateMap = [:]
        if resetPage {
            self.currentPage = 0
        }
        self.updateResources()
    }

    // MARK: - 更新检查

    /// 检查所有 Modrinth 来源的模组是否有新版本，结果就地标注在列表项上。
    public func checkForUpdates() async {
        guard !checkingUpdates else { return }
        guard let instance else { return }
        let entries: [(url: URL, projectId: String)] = (loadResult ?? []).compactMap { entry in
            for source in entry.1.sources {
                if case .modrinth(let projectId) = source {
                    return (entry.0, projectId)
                }
            }
            return nil
        }
        guard !entries.isEmpty else {
            hint("没有可检查更新的\(type.localizedName)：仅支持带 Modrinth 来源记录的资源。", type: .critical)
            return
        }

        checkingUpdates = true
        hint("正在检查 \(entries.count) 个\(type.localizedName)的更新……")
        let gameVersion: String = instance.version.id
        let loader: ModLoader? = instance.modLoader

        // 限制并发数，避免一次性大量请求触发 Modrinth 速率限制
        let results: [(url: URL, update: ResourceDisplayModel.ResourceUpdate?)] = await withTaskGroup(
            of: (url: URL, update: ResourceDisplayModel.ResourceUpdate?).self
        ) { group in
            var iterator = entries.makeIterator()
            func addNext() -> Bool {
                guard let entry = iterator.next() else { return false }
                group.addTask {
                    let update: ResourceDisplayModel.ResourceUpdate? = await Self.fetchLatestUpdate(
                        projectId: entry.projectId,
                        gameVersion: gameVersion,
                        loader: loader,
                        currentFileName: entry.url.lastPathComponent
                    )
                    return (entry.url, update)
                }
                return true
            }
            for _ in 0..<min(6, entries.count) {
                _ = addNext()
            }
            var collected: [(url: URL, update: ResourceDisplayModel.ResourceUpdate?)] = []
            while let result = await group.next() {
                collected.append(result)
                _ = addNext()
            }
            return collected
        }

        var updateCount: Int = 0
        for (url, update) in results {
            guard let update else { continue }
            updateCount += 1
            updateMap[url] = update
            // 就地更新当前页的显示模型，立即反馈
            for resource in resources ?? [] where resource.url == url {
                resource.availableUpdate = update
            }
        }
        checkingUpdates = false
        if updateCount == 0 {
            hint("所有\(type.localizedName)都已是最新版本！", type: .finish)
        } else {
            hint("发现 \(updateCount) 个可更新的\(type.localizedName)。", type: .finish)
        }
    }

    /// 查询单个资源在指定游戏版本与加载器下的最新版本；文件名一致视为已是最新。
    private static func fetchLatestUpdate(
        projectId: String,
        gameVersion: String,
        loader: ModLoader?,
        currentFileName: String
    ) async -> ResourceDisplayModel.ResourceUpdate? {
        do {
            let versions: [ModrinthVersion] = try await ModrinthAPIClient.shared.versions(
                ofProject: projectId, forGameVersion: gameVersion, loader: loader
            )
            guard let latest = versions.first(where: { !$0.files.isEmpty }),
                  let file = latest.files.filter(\.primary).first ?? latest.files.first else {
                return nil
            }
            let installedName: String = currentFileName.hasSuffix(".disabled")
                ? String(currentFileName.dropLast(".disabled".count))
                : currentFileName
            guard file.name != installedName else { return nil }
            return .init(versionNumber: latest.versionNumber, fileName: file.name, url: file.url, sha1: file.sha1)
        } catch {
            warn("检查 \(projectId) 的更新失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 一键更新：下载新版本文件到原目录，完成后把旧文件移入废纸篓并刷新列表。
    public func performUpdate(_ resource: ResourceDisplayModel) {
        guard let update = resource.availableUpdate else { return }
        guard let directory = directory() else { return }
        let oldURL: URL = resource.url
        let newURL: URL = directory.appending(path: update.fileName)
        let task: MyTask<EmptyModel> = .init(
            name: "更新资源 - \(resource.name) \(update.versionNumber)",
            .init(0, "下载新版本") { task, _ in
                try await FileDownloader.shared.download(
                    url: update.url,
                    destination: newURL,
                    sha1: update.sha1,
                    progressHandler: task.setProgress(_:)
                )
            }
        )
        TaskManager.shared.execute(task: task) { [weak self] error in
            if error != nil {
                hint("更新 \(resource.name) 失败：\(error?.localizedDescription ?? "未知错误")", type: .critical)
                return
            }
            Task { @MainActor in
                do {
                    try await NSWorkspace.shared.recycle([oldURL])
                    hint("更新 \(resource.name) 成功！", type: .finish)
                    try await self?.load()
                } catch {
                    err("清理旧版本文件失败：\(error.localizedDescription)")
                }
            }
        }
    }

    func updateResources() {
        if let convertTask {
            convertTask.cancel()
            self.convertTask = nil
        }
        guard let loadResult else { return }

        let validResources: [(URL, Resource)] = loadResult.lazy
            .filter {
                searchKeyword.isEmpty
                || $0.1.name.contains(searchKeyword)
                || $0.1.description?.contains(searchKeyword) == true
            }

        self.pageCount = validResources.isEmpty ? 0 : Int(ceil(Double(validResources.count) / Double(entriesPerPage)))
        if pageCount == 0 {
            self.resources = []
            return
        } else {
            currentPage = min(pageCount - 1, currentPage)
        }

        let start = currentPage * entriesPerPage
        let end = min(start + entriesPerPage, validResources.count)
        self.resources = nil
        convertTask = .detached {
            do {
                let resources = try validResources[start..<end]
                    .map {
                        try Task.checkCancellation()
                        return ResourceDisplayModel($0.0, $0.1)
                    }
                await MainActor.run {
                    for resource in resources {
                        resource.availableUpdate = self.updateMap[resource.url]
                    }
                    self.resources = resources
                }
            } catch let error where error.isCancellationError {
            } catch {
                err("刷新资源列表失败：\(error.localizedDescription)")
            }
            await MainActor.run {
                self.convertTask = nil
            }
        }
    }

    func setSearchKeyword(_ keyword: String) {
        searchKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        updateResources()
    }

    func toggleDisabled(_ resource: ResourceDisplayModel) async throws {
        let oldURL: URL = resource.url
        let newURL: URL
        if resource.disabled {
            newURL = resource.url.deletingPathExtension()
            log("正在启用资源 \(resource.fileName)")
        } else {
            newURL = resource.url.appendingPathExtension("disabled")
            log("正在禁用资源 \(resource.fileName)")
        }
        // 文件移动放在后台线程，避免大文件时卡住界面
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.moveItem(at: resource.url, to: newURL)
        }.value
        resource.disabled.toggle()
        resource.url = newURL
        // 同步缓存中的 URL，否则删除/搜索会引用旧路径
        if let index = loadResult?.firstIndex(where: { $0.0 == oldURL }) {
            loadResult?[index].0 = newURL
        }
    }

    /// 删除一个已安装的资源文件（移到废纸篓），并同步刷新列表。
    func deleteResource(_ resource: ResourceDisplayModel) async throws {
        try await NSWorkspace.shared.recycle([resource.url])
        log("已删除资源 \(resource.fileName)")
        loadResult?.removeAll { $0.0 == resource.url }
        updateResources()
    }

    func loadInfo(for resource: ResourceDisplayModel) async throws -> ProjectListItemModel? {
        for source in resource.sources {
            if case .modrinth(let projectId) = source {
                do {
                    guard let project = try await ModrinthAPIClient.shared.project(projectId) else {
                        warn("记录了 \(resource.fileName) 对应的 Modrinth projectId（\(projectId)），但它在 Modrinth 上已不存在")
                        return nil
                    }
                    return .init(project)
                } catch {
                    throw SimpleError("查询 Modrinth Project 失败：\(error.localizedDescription)")
                }
            }
        }
        return nil
    }

    func directory() -> URL? {
        guard let instance else { return nil }

        let directoryName = type.saveDirectory ?? ""
        let url = instance.url.appending(path: directoryName)

        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        return url
    }
}
