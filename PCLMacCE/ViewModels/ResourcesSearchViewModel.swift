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

    @Published public var searchResults: [ProjectListItemModel]?
    @Published public var query: String = ""
    @Published public var source: SearchSource = .modrinth
    @Published public private(set) var totalPages: Int = 0
    public let type: ResourceType
    public let loadingVM: MyLoadingViewModel = .init(text: "加载中")
    private var requestID = UUID()
    private let curseforgeClient: CurseForgeAPIClient = .init(apiKey: Secrets.shared.curseforgeApiKey ?? "")

    public init(type: ResourceType) {
        self.type = type
    }

    public func search(_ query: String, pageIndex: Int = 0, gameVersion: String? = nil) async throws {
        let requestID = UUID()
        self.requestID = requestID
        self.query = query
        loadingVM.reset()
        searchResults = nil

        let results: [ProjectListItemModel]
        switch source {
        case .modrinth:
            let response: ModrinthAPIClient.SearchResponse = try await ModrinthAPIClient.shared.search(
                type: type, query, forVersion: gameVersion, pageIndex: pageIndex
            )
            totalPages = Int(ceil(Double(response.totalHits) / Double(response.limit)))
            results = response.hits.filter { $0.clientCompatibility != .unsupported }.map(ProjectListItemModel.init(_:))
        case .curseforge:
            guard !curseforgeClient.apiKeyIsEmpty else {
                throw SimpleError("未配置 CurseForge API Key，无法搜索 CurseForge。")
            }
            let mods: [CurseForgeMod] = try await curseforgeClient.search(
                type: type, query, forVersion: gameVersion, pageIndex: pageIndex
            )
            // CurseForge 不返回总页数：满页时假定还有下一页
            totalPages = mods.count >= 40 ? pageIndex + 2 : pageIndex + 1
            results = mods.map { ProjectListItemModel($0, fallbackType: type) }
        }

        try Task.checkCancellation()
        guard self.requestID == requestID else { throw CancellationError() }
        searchResults = results
    }

    public func changePage(_ page: Int, gameVersion: String? = nil) async throws {
        try await search(query, pageIndex: page, gameVersion: gameVersion)
    }
}
