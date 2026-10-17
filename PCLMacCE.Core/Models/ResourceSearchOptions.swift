//
//  ResourceSearchOptions.swift
//  PCLMacCE
//

import Foundation

/// 资源搜索排序方式（Modrinth 与 CurseForge 共用的用户语义）。
public enum ResourceSearchSort: String, CaseIterable, Sendable, CustomStringConvertible {
    /// 相关度（默认）。
    case relevance
    /// 总下载量。
    case downloads
    /// 热度（Modrinth 关注数 / CurseForge Popularity）。
    case popularity
    /// 最近更新。
    case updated

    public var description: String {
        switch self {
        case .relevance: "相关度"
        case .downloads: "下载量"
        case .popularity: "热度"
        case .updated: "最近更新"
        }
    }

    /// Modrinth `/v2/search` 的 `index` 参数值。
    public var modrinthIndex: String {
        switch self {
        case .relevance: "relevance"
        case .downloads: "downloads"
        case .popularity: "follows"
        case .updated: "updated"
        }
    }

    /// CurseForge `/v1/mods/search` 的 `sortField` 参数值。
    public var curseForgeSortField: Int {
        switch self {
        case .relevance: 1   // Featured
        case .downloads: 6   // TotalDownloads
        case .popularity: 2  // Popularity
        case .updated: 3     // LastUpdated
        }
    }
}
