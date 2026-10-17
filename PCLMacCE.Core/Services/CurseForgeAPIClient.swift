//
//  CurseForgeAPIClient.swift
//  PCLMacCE
//

import Foundation
import SwiftyJSON

public class CurseForgeAPIClient {
    /// 运行期密钥提供者：应用启动时注入，用户在设置中更换 Key 后立即生效，
    /// 无需重建各处已创建的客户端。
    public static var apiKeyProvider: (@Sendable () -> String)?

    private let semaphore: AsyncSemaphore = .init(value: 8)
    private let apiRoot: URL
    /// 显式密钥（测试用）；为 `nil` 时动态读取 `apiKeyProvider`。
    private let explicitApiKey: String?

    public init(apiRoot: URL = APIEndpoints.CurseForge.apiRoot, apiKey: String? = nil) {
        self.apiRoot = apiRoot
        self.explicitApiKey = apiKey
    }

    /// 当前生效的 API Key。
    private var apiKey: String {
        return explicitApiKey ?? Self.apiKeyProvider?() ?? ""
    }

    /// API Key 是否为空（为空时 CurseForge 相关功能不可用）。
    public var apiKeyIsEmpty: Bool { apiKey.isEmpty }

    /// 未配置 Key 时抛出明确的用户可读错误。
    private func requireAPIKey() throws {
        guard !apiKeyIsEmpty else {
            throw SimpleError("未配置 CurseForge API Key。请在「设置 → 下载」中填入 Key 后重试。")
        }
    }

    public func mod(id modId: Int) async throws -> CurseForgeMod? {
        let response = try await request("/v1/mods/\(modId)")
        if response.statusCode == 404 { return nil }
        return try response.decode(Response<CurseForgeMod>.self).data
    }

    public func modFile(modId: Int, fileId: Int) async throws -> CurseForgeModFile? {
        let response = try await request("/v1/mods/\(modId)/files/\(fileId)")
        if response.statusCode == 404 { return nil }
        return try response.decode(Response<CurseForgeModFile>.self).data
    }

    /// 获取指定项目的全部文件。CurseForge 单页上限 50，这里翻完所有页并按 ID 去重。
    /// - Returns: 全部文件（未保证顺序）。
    public func files(modId: Int) async throws -> [CurseForgeModFile] {
        var all: [CurseForgeModFile] = []
        var seen: Set<Int32> = []
        let pageSize: Int = 50
        var index: Int = 0
        // 上限保护：避免异常数据导致无限翻页
        for _ in 0..<40 {
            let response = try await request(
                "/v1/mods/\(modId)/files",
                params: ["index": String(index), "pageSize": String(pageSize)]
            )
            guard (200..<300).contains(response.statusCode) else {
                throw SimpleError("获取 CurseForge 文件列表失败（HTTP \(response.statusCode)）。")
            }
            let decoded = try response.decode(Response<[CurseForgeModFile]>.self)
            for file in decoded.data where seen.insert(file.id).inserted {
                all.append(file)
            }
            let total: Int = decoded.pagination?.totalCount ?? 0
            index += decoded.data.count
            guard decoded.data.count == pageSize, all.count < total || total == 0, !decoded.data.isEmpty else { break }
        }
        // 按发布时间倒序；缺失时间时按文件 ID 倒序（ID 随上传递增）
        return all.sorted { lhs, rhs in
            switch (lhs.fileDate, rhs.fileDate) {
            case let (l?, r?): return l > r
            default: return lhs.id > rhs.id
            }
        }
    }

    /// 搜索 CurseForge 项目。Minecraft 的 gameId 固定为 432。
    /// - Parameters:
    ///   - loader: 加载器过滤。CurseForge 要求该参数必须与 `gameVersion` 一起使用，
    ///     未指定游戏版本时会忽略加载器。
    ///   - sort: 排序方式。
    /// - Returns: 搜索结果与总条数（总条数来自响应头，缺失时为 `nil`）。
    public func search(
        type: ResourceType,
        _ query: String?,
        forVersion gameVersion: String?,
        loader: ModLoader? = nil,
        sort: ResourceSearchSort = .relevance,
        pageIndex: Int = 0,
        pageSize: Int = 40
    ) async throws -> (mods: [CurseForgeMod], totalCount: Int?) {
        try requireAPIKey()
        try await semaphore.wait()
        defer { Task { await semaphore.signal() } }
        var params: [String: String?] = [
            "gameId": "432",
            "classId": String(CurseForgeMod.classId(for: type)),
            "pageSize": String(min(pageSize, 50)),
            "index": String(pageIndex * pageSize),
            "sortField": String(sort.curseForgeSortField),
            "sortOrder": "desc",
            "searchFilter": (query ?? "").isEmpty ? nil : query
        ]
        if let gameVersion {
            params["gameVersion"] = gameVersion
            // CurseForge 文档要求 modLoaderType 必须与 gameVersion 搭配
            if let loader {
                params["modLoaderType"] = String(Self.modLoaderType(of: loader))
            }
        }
        let response = try await requestSearch(params: params)
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 403 {
                throw SimpleError("CurseForge 拒绝了请求（HTTP 403）。请确认 API Key 有效，或稍后重试。")
            }
            throw SimpleError("CurseForge 搜索失败（HTTP \(response.statusCode)）。")
        }
        let decoded = try response.decode(Response<[CurseForgeMod]>.self)
        let mods: [CurseForgeMod] = decoded.data
        // 总条数优先取响应体 pagination.totalCount；部分网关也放在响应头里，作为兜底
        let totalCount: Int? = decoded.pagination?.totalCount
            ?? ["x-total-count", "pagination-total-count"]
                .lazy
                .compactMap { response.headers[$0] }
                .first { !$0.isEmpty }
                .flatMap { Int($0) }
        return (mods, totalCount)
    }

    /// 发送搜索请求。官方文档的路径是小写 `search`，但部分 CloudFront 边缘节点
    /// 会对小写路径持续返回 403「API Key missing or invalid」（同 Key 请求
    /// `Search`、其他端点均正常）。因此小写失败时自动回退到大写变体。
    private func requestSearch(params: [String: String?]) async throws -> HTTPClient.Response {
        let lowercase = try await HTTPClient.shared.get(
            apiRoot.appending(path: "/v1/mods/search"),
            headers: ["x-api-key": apiKey],
            params: params,
            revalidate: true
        )
        guard lowercase.statusCode == 403 else { return lowercase }
        warn("CurseForge 搜索小写路径返回 403，尝试大写路径")
        return try await HTTPClient.shared.get(
            apiRoot.appending(path: "/v1/mods/Search"),
            headers: ["x-api-key": apiKey],
            params: params,
            revalidate: true
        )
    }

    /// CurseForge 的 modLoaderType 参数值。
    private static func modLoaderType(of loader: ModLoader) -> Int {
        switch loader {
        case .forge: 1
        case .fabric: 4
        case .neoforge: 6
        }
    }

    private func request(
        _ path: String,
        method: String = "GET",
        headers: [String: String?] = [:],
        params: [String: String?]? = nil,
        body: [String: Any]? = nil
    ) async throws -> HTTPClient.Response {
        try requireAPIKey()
        try await semaphore.wait()
        defer { Task { await semaphore.signal() } }
        var headers: [String: String?] = headers
        headers["x-api-key"] = apiKey

        let response = try await HTTPClient.shared.request(
            url: apiRoot.appending(path: path),
            method: method,
            headers: headers,
            body: params ?? body,
            revalidate: true,
            timeout: 30
        )

        return response
    }

    public struct Response<Body: Codable>: Codable {
        public struct Pagination: Codable {
            public let index: Int?
            public let pageSize: Int?
            public let resultCount: Int?
            public let totalCount: Int?
        }

        public let data: Body
        public let pagination: Pagination?
    }
}
