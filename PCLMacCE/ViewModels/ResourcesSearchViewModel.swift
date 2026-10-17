//
//  ResourcesSearchViewModel.swift
//  PCLMacCE
//

import Foundation
import Core

@MainActor
class ResourcesSearchViewModel: ObservableObject {
    /// 资源搜索来源。
    enum SearchSource: String, CaseIterable, Identifiable, CustomStringConvertible {
        case modrinth, curseforge

        var id: String { rawValue }

        var description: String {
            switch self {
            case .modrinth: "Modrinth"
            case .curseforge: "CurseForge"
            }
        }
    }

    /// 筛选条件。任一变化都会触发重新搜索并把页码归零。
    struct Filters: Equatable {
        var gameVersion: String?
        var loader: ModLoader?
        var sort: ResourceSearchSort = .relevance

        static let `default`: Filters = .init()
    }

    @Published public var searchResults: [ProjectListItemModel]?
    @Published public var query: String = ""
    @Published public var source: SearchSource = .modrinth
    @Published public var filters: Filters = .default
    @Published public private(set) var totalPages: Int = 0
    @Published public private(set) var resultCount: Int = 0
    @Published public private(set) var availableGameVersions: [String] = []
    @Published public private(set) var isLoadingGameVersions: Bool = false
    @Published public private(set) var gameVersionLoadFailed: Bool = false
    public let type: ResourceType
    public let loadingVM: MyLoadingViewModel = .init(text: "加载中")
    private var requestID = UUID()
    private let curseforgeClient: CurseForgeAPIClient = .init()

    /// 加载器筛选是否适用于当前资源类型（资源包与光影没有加载器概念）。
    public var supportsLoaderFilter: Bool {
        type == .mod || type == .modpack
    }

    public init(type: ResourceType) {
        self.type = type
    }

    /// 加载游戏版本清单；页面搜索不依赖清单成功，可在清单失败时照常浏览资源。
    public func loadGameVersions() async {
        if let manifest = VersionManifest.shared {
            updateGameVersions(from: manifest)
            gameVersionLoadFailed = false
            return
        }
        guard !isLoadingGameVersions else { return }
        isLoadingGameVersions = true
        gameVersionLoadFailed = false
        defer { isLoadingGameVersions = false }
        do {
            updateGameVersions(from: try await VersionManifest.load(revalidate: true))
        } catch {
            if let manifest = VersionManifest.shared {
                updateGameVersions(from: manifest)
                gameVersionLoadFailed = false
            } else {
                gameVersionLoadFailed = true
                warn("加载资源筛选用游戏版本清单失败：\(error.localizedDescription)")
            }
        }
    }

    private func updateGameVersions(from manifest: VersionManifest) {
        availableGameVersions = manifest.versions
            .filter { $0.type == .release || $0.type == .snapshot || $0.type == .aprilFool }
            .map(\.id)
    }

    /// 执行搜索。`filters` 为**实际生效**的筛选条件（实例定向模式下可能由调用方
    /// 强制覆盖版本与加载器），与界面上的手动筛选状态分离。
    public func search(_ query: String, filters: Filters, pageIndex: Int = 0) async throws {
        let requestID = UUID()
        self.requestID = requestID
        self.query = query
        loadingVM.reset()
        searchResults = nil

        let results: [ProjectListItemModel]
        var newTotalPages: Int = 0
        var newResultCount: Int = 0
        switch source {
        case .modrinth:
            let response: ModrinthAPIClient.SearchResponse = try await ModrinthAPIClient.shared.search(
                type: type,
                query,
                forVersion: filters.gameVersion,
                loader: supportsLoaderFilter ? filters.loader : nil,
                sort: filters.sort,
                pageIndex: pageIndex
            )
            newTotalPages = Int(ceil(Double(response.totalHits) / Double(response.limit)))
            newResultCount = response.totalHits
            results = response.hits.filter { $0.clientCompatibility != .unsupported }.map(ProjectListItemModel.init(_:))
        case .curseforge:
            guard !curseforgeClient.apiKeyIsEmpty else {
                throw SimpleError("未配置 CurseForge API Key。请在「设置 → 下载」中填入 Key 后重试。")
            }
            // CurseForge 的加载器过滤必须与游戏版本同时提供；只选加载器时给出明确提示
            if supportsLoaderFilter, filters.loader != nil, filters.gameVersion == nil {
                throw SimpleError("CurseForge 的加载器筛选需要同时指定游戏版本。请先选择版本，或改用 Modrinth。")
            }
            let result: (mods: [CurseForgeMod], totalCount: Int?) = try await curseforgeClient.search(
                type: type,
                query,
                forVersion: filters.gameVersion,
                loader: supportsLoaderFilter ? filters.loader : nil,
                sort: filters.sort,
                pageIndex: pageIndex
            )
            if let totalCount = result.totalCount {
                newResultCount = totalCount
                newTotalPages = max(1, Int(ceil(Double(totalCount) / 40.0)))
            } else {
                // 响应未提供总条数：满页时假定还有下一页
                newResultCount = result.mods.count
                newTotalPages = result.mods.count >= 40 ? pageIndex + 2 : pageIndex + 1
            }
            results = result.mods.map { ProjectListItemModel($0, fallbackType: type) }
        }

        try Task.checkCancellation()
        // 页码与总数必须和结果一起在 requestID 校验之后写入，否则旧请求会覆盖新状态
        guard self.requestID == requestID else { throw CancellationError() }
        totalPages = newTotalPages
        resultCount = newResultCount
        searchResults = results
    }

    public func changePage(_ page: Int, filters: Filters) async throws {
        try await search(query, filters: filters, pageIndex: page)
    }

    /// 重置手动筛选条件（实例定向模式的强制筛选由调用方另行处理）。
    public func resetFilters() {
        filters = .default
    }
}
