//
//  ResourcesSearchViewModel.swift
//  PCLMacCE
//

import Foundation
import Core

@MainActor
class ResourcesSearchViewModel: ObservableObject {
    @Published public var searchResults: [ProjectListItemModel]?
    @Published public var query: String = ""
    public let type: ResourceType
    public let loadingVM: MyLoadingViewModel = .init(text: "加载中")
    private var lastSearchResponse: ModrinthAPIClient.SearchResponse?
    private var requestID = UUID()

    public var totalPages: Int {
        guard let lastSearchResponse else { return 0 }
        return Int(ceil(Double(lastSearchResponse.totalHits) / Double(lastSearchResponse.limit)))
    }

    public init(type: ResourceType) {
        self.type = type
    }

    public func search(_ query: String, pageIndex: Int = 0, gameVersion: String? = nil) async throws {
        let requestID = UUID()
        self.requestID = requestID
        self.query = query
        loadingVM.reset()
        searchResults = nil
        let response: ModrinthAPIClient.SearchResponse = try await ModrinthAPIClient.shared.search(
            type: type, query, forVersion: gameVersion, pageIndex: pageIndex
        )
        try Task.checkCancellation()
        guard self.requestID == requestID else { throw CancellationError() }
        lastSearchResponse = response
        searchResults = response.hits.filter { $0.clientCompatibility != .unsupported }.map(ProjectListItemModel.init(_:))
    }

    public func changePage(_ page: Int, gameVersion: String? = nil) async throws {
        try await search(query, pageIndex: page, gameVersion: gameVersion)
    }
}
