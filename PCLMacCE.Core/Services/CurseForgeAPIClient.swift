//
//  CurseForgeAPIClient.swift
//  PCLMacCE
//

import Foundation
import SwiftyJSON

public class CurseForgeAPIClient {
    private let semaphore: AsyncSemaphore = .init(value: 8)
    private let apiRoot: URL
    private let apiKey: String

    public init(apiRoot: URL = APIEndpoints.CurseForge.apiRoot, apiKey: String) {
        self.apiRoot = apiRoot
        self.apiKey = apiKey
    }

    /// API Key 是否为空（为空时 CurseForge 相关功能不可用）。
    public var apiKeyIsEmpty: Bool { apiKey.isEmpty }

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

    /// 获取指定项目的全部文件（按时间倒序）。
    public func files(modId: Int) async throws -> [CurseForgeModFile] {
        let response = try await request("/v1/mods/\(modId)/files")
        guard (200..<300).contains(response.statusCode) else {
            throw SimpleError("获取 CurseForge 文件列表失败（HTTP \(response.statusCode)）。")
        }
        return try response.decode(Response<[CurseForgeModFile]>.self).data
    }

    /// 搜索 CurseForge 项目。Minecraft 的 gameId 固定为 432。
    /// - Returns: 搜索结果与总条数（总条数来自响应头，缺失时为 `nil`）。
    public func search(
        type: ResourceType,
        _ query: String?,
        forVersion gameVersion: String?,
        loader: ModLoader? = nil,
        pageIndex: Int = 0,
        pageSize: Int = 40
    ) async throws -> (mods: [CurseForgeMod], totalCount: Int?) {
        try await semaphore.wait()
        defer { Task { await semaphore.signal() } }
        var params: [String: String?] = [
            "gameId": "432",
            "classId": String(CurseForgeMod.classId(for: type)),
            "pageSize": String(pageSize),
            "index": String(pageIndex * pageSize),
            "sortField": "2", // 按最后更新时间排序
            "sortOrder": "desc",
            "searchFilter": (query ?? "").isEmpty ? nil : query
        ]
        if let gameVersion {
            params["gameVersion"] = gameVersion
        }
        if let loader {
            params["modLoaderType"] = String(Self.modLoaderType(of: loader))
        }
        let response = try await HTTPClient.shared.get(
            apiRoot.appending(path: "/v1/mods/search"),
            headers: ["x-api-key": apiKey],
            params: params,
            revalidate: true
        )
        guard (200..<300).contains(response.statusCode) else {
            throw SimpleError("CurseForge 搜索失败（HTTP \(response.statusCode)）。")
        }
        let mods: [CurseForgeMod] = try response.decode(Response<[CurseForgeMod]>.self).data
        // 总条数来自响应头；不同网关的头名不一致，两个都尝试，缺失时由调用方启发式估计
        let totalCount: Int? = ["x-total-count", "pagination-total-count"]
            .lazy
            .compactMap { response.headers[$0] }
            .first { !$0.isEmpty }
            .flatMap { Int($0) }
        return (mods, totalCount)
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
        body: [String: Any]? = nil
    ) async throws -> HTTPClient.Response {
        try await semaphore.wait()
        defer { Task { await semaphore.signal() } }
        var headers: [String: String?] = headers
        headers["x-api-key"] = apiKey

        let response = try await HTTPClient.shared.request(
            url: apiRoot.appending(path: path),
            method: method,
            headers: headers,
            body: body,
            revalidate: true,
            timeout: 30
        )

        return response
    }

    public struct Response<Body: Codable>: Codable {
        public let data: Body
    }
}
