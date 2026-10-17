//
//  CurseForgeMod.swift
//  PCLMacCE
//

import Foundation

public struct CurseForgeMod: Codable {
    public struct LatestFilesIndex: Codable {
        public let gameVersion: String
        public let fileId: Int32
        public let modLoader: Int?
    }

    public let id: Int32
    public let name: String
    public let summary: String
    public let logo: CurseForgeModAsset
    public let classId: Int?
    public let slug: String?
    public let downloadCount: Int?
    public let dateModified: Date?
    public let latestFilesIndexes: [LatestFilesIndex]?

    private enum CodingKeys: String, CodingKey {
        case id, name, summary, logo, classId, slug, downloadCount, dateModified, latestFilesIndexes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int32.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        self.logo = try container.decode(CurseForgeModAsset.self, forKey: .logo)
        self.classId = try? container.decode(Int.self, forKey: .classId)
        self.slug = try? container.decode(String.self, forKey: .slug)
        self.downloadCount = try? container.decode(Int.self, forKey: .downloadCount)
        // CurseForge 返回带毫秒的 ISO8601 时间（2023-04-05T12:34:56.789Z），
        // 共享解码器的 .iso8601 策略无法解析，按字符串读取后宽容解析
        self.dateModified = (try? container.decode(String.self, forKey: .dateModified)).flatMap(FlexibleISO8601.parse)
        self.latestFilesIndexes = try? container.decode([CurseForgeMod.LatestFilesIndex].self, forKey: .latestFilesIndexes)
    }

    public var projectType: ResourceType? {
        switch classId {
        case 12: .resourcepack
        case 6: .mod
        case 4471: .modpack
        case 6552: .shader
        default: nil
        }
    }

    /// 搜索接口使用的分类 ID（Minecraft gameId 固定为 432）。
    public static func classId(for type: ResourceType) -> Int {
        switch type {
        case .mod: 6
        case .modpack: 4471
        case .resourcepack: 12
        case .shader: 6552
        }
    }
}

/// 兼容带/不带毫秒的 ISO8601 日期解析。
enum FlexibleISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let formatter: ISO8601DateFormatter = .init()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let standard: ISO8601DateFormatter = .init()

    static func parse(_ text: String) -> Date? {
        return withFraction.date(from: text) ?? standard.date(from: text)
    }
}

public struct CurseForgeModAsset: Codable {
    public let id: Int32
    public let title: String
    public let url: URL?
    public let thumbnailURL: URL?

    private enum CodingKeys: String, CodingKey {
        case id, title, url, thumbnailURL = "thumbnailUrl"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int32.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try? container.decode(URL.self, forKey: .url)
        self.thumbnailURL = try? container.decode(URL.self, forKey: .thumbnailURL)
    }
}

public struct CurseForgeModFile: Codable {
    public struct FileHash: Codable {
        public let value: String
        public let algo: Int
    }

    /// 文件依赖。`relationType`：1 = 内置库，2 = 可选依赖，3 = 必需依赖，
    /// 4 = 工具，5 = 不兼容，6 = 包含在整合包中。
    public struct Dependency: Codable {
        public let modId: Int32
        public let relationType: Int32

        private enum CodingKeys: String, CodingKey {
            case modId, relationType
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.modId = try container.decode(Int32.self, forKey: .modId)
            self.relationType = try container.decodeIfPresent(Int32.self, forKey: .relationType) ?? 0
        }
    }

    public let id: Int32
    public let modId: Int32
    public let available: Bool
    public let fileName: String
    public let hashes: [FileHash]
    public let downloadURL: URL
    /// 混合列表：既有游戏版本（`1.20.1`）也有加载器名（`Fabric`）。
    public let gameVersions: [String]
    public let releaseType: Int?
    public let fileDate: Date?
    public let dependencies: [Dependency]

    /// 必需依赖的工程 ID（relationType == 3）。
    public var requiredDependencyModIds: [Int32] {
        return dependencies.filter { $0.relationType == 3 }.map(\.modId)
    }

    /// 从 gameVersions 中解析出的 Mod 加载器。
    public var loaders: [ModLoader] {
        return gameVersions.compactMap { ModLoader(rawValue: $0.lowercased()) }
    }

    /// 已知的非游戏版本 token（加载器或渲染器名），用于从 gameVersions 中剔除。
    /// CurseForge 的 gameVersions 是混合数组：游戏版本与加载器/渲染器标签混在一起。
    private static let nonGameVersionTokens: Set<String> = [
        "forge", "fabric", "neoforge", "quilt", "liteloader", "rift",
        "iris", "optifine", "optifabric", "canvas", "sodium", "oculus",
        "shaders", "client", "server", "data pack", "datapack", "mc"
    ]

    /// 从 gameVersions 中过滤出的游戏版本。
    /// 只保留看起来像 Minecraft 版本号的项，避免把 Iris / OptiFine 等标签
    /// 当成游戏版本生成伪版本分组。
    public var minecraftVersions: [String] {
        return gameVersions.filter { token in
            let lower = token.lowercased()
            guard !Self.nonGameVersionTokens.contains(lower) else { return false }
            guard ModLoader(rawValue: lower) == nil else { return false }
            // 正式版（1.20.1 / 26.1）与快照（23w13a / 1.20-pre1 / 26.1-snapshot-1）
            return token.first?.isNumber == true
        }
    }

    public var checksums: [String: String] {
        return hashes.reduce(into: [:]) { result, hash in
            switch hash.algo {
            case 1: result["sha1"] = hash.value
            case 2: result["md5"] = hash.value
            default: break
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, modId, fileName, hashes, gameVersions, releaseType, fileDate, dependencies
        case available = "isAvailable", downloadURL = "downloadUrl"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int32.self, forKey: .id)
        self.modId = try container.decode(Int32.self, forKey: .modId)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.hashes = try container.decode([CurseForgeModFile.FileHash].self, forKey: .hashes)
        self.available = try container.decode(Bool.self, forKey: .available)
        self.gameVersions = (try? container.decode([String].self, forKey: .gameVersions)) ?? []
        self.releaseType = try? container.decode(Int.self, forKey: .releaseType)
        self.fileDate = (try? container.decode(String.self, forKey: .fileDate)).flatMap(FlexibleISO8601.parse)
        self.dependencies = (try? container.decode([Dependency].self, forKey: .dependencies)) ?? []
        let fallbackURL: URL = APIEndpoints.CurseForge.forgeCDN
            .appending(path: "files/\(id / 1000)/\(id % 1000)/\(fileName)")
        self.downloadURL = try container.decodeIfPresent(URL.self, forKey: .downloadURL) ?? fallbackURL
    }
}
