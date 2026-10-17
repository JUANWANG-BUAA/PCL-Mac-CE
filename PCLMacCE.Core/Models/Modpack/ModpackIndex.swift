//
//  ModpackIndex.swift
//  PCLMacCE
//

import Foundation

public struct ModpackIndex {
    public protocol File {
        func fetchInfo() async throws

        var url: URL? { get }
        var path: String? { get }
        var checksums: [String: String]? { get }
    }

    public enum Format: CustomStringConvertible {
        case modrinth, curseforge, mcbbs, simple

        public var description: String {
            switch self {
            case .modrinth: "Modrinth"
            case .curseforge: "CurseForge"
            case .mcbbs: "MCBBS"
            case .simple: "包含 .minecraft 目录的压缩包"
            }
        }
    }

    public let format: Format

    public let name: String
    public let version: String
    public let author: String?
    public let description: String?

    public let minecraftVersion: MinecraftVersion!
    public let modLoader: (ModLoader, String)?
    public let files: [File]
    public let overridesDirectories: [String]

    public var dependencyInfo: String {
        guard let minecraftVersion else {
            return "未知"
        }
        var info = "Minecraft \(minecraftVersion)"
        if let modLoader {
            info += ", \(modLoader.0.description) \(modLoader.1)"
        }
        return info
    }
}

public extension ModpackIndex {
    struct RegularFile: File {
        public let url: URL?
        public let path: String?
        public let checksums: [String: String]?

        public init(url: URL, path: String, checksums: [String: String]) {
            self.url = url
            self.path = path
            self.checksums = checksums
        }

        public func fetchInfo() async throws { }
    }

    class CurseForgeFile: File {
        private let client: CurseForgeAPIClient
        private let providedURL: URL?
        private let projectId: Int
        private let fileId: Int

        private var cachedMod: CurseForgeMod?
        private var cachedModFile: CurseForgeModFile?
        private var infoFetched: Bool = false

        public init(client: CurseForgeAPIClient, url: URL?, projectId: Int, fileId: Int) {
            self.client = client
            self.providedURL = url
            self.projectId = projectId
            self.fileId = fileId
        }

        public convenience init(client: CurseForgeAPIClient, file: CurseForgeModpackIndex.File) {
            self.init(client: client, url: file.url, projectId: file.projectId, fileId: file.fileId)
        }

        public var url: URL? {
            if let providedURL {
                return providedURL
            }
            return cachedModFile?.downloadURL
        }

        public var path: String? {
            guard let cachedMod, let cachedModFile, let type = cachedMod.projectType else { return nil }
            guard let directory = type.saveDirectory else { return nil }
            return "\(directory)/\(cachedModFile.fileName)"
        }

        public var checksums: [String: String]? {
            return cachedModFile?.checksums
        }

        public func fetchInfo() async throws {
            if infoFetched { return }
            infoFetched = true

            guard !client.apiKeyIsEmpty else {
                throw SimpleError("未配置 CurseForge API Key，无法解析整合包文件信息。请在「设置 → 下载」中配置。")
            }
            guard let mod = try await client.mod(id: projectId) else {
                throw SimpleError("资源 \(projectId) 不存在")
            }
            guard let file = try await client.modFile(modId: projectId, fileId: fileId) else {
                throw SimpleError("资源文件 \(projectId)/\(fileId) 不存在")
            }
            cachedMod = mod
            cachedModFile = file
        }

        /// 该文件的必需依赖工程 ID（`fetchInfo()` 之后可用）。
        var requiredDependencyModIds: [Int32] {
            return cachedModFile?.requiredDependencyModIds ?? []
        }

        /// 工程 ID（`fetchInfo()` 之前即可用）。
        var projectIdValue: Int32 {
            return Int32(projectId)
        }

        /// 为依赖工程选择与整合包上下文（游戏版本 + 加载器）匹配的最新文件。
        /// - Parameters:
        ///   - projectId: 依赖的工程 ID。
        ///   - minecraftVersion: 整合包目标游戏版本。
        ///   - loader: 整合包的 Mod 加载器。
        func resolveDependency(projectId: Int32, minecraftVersion: MinecraftVersion, loader: ModLoader?) async throws -> CurseForgeFile? {
            let files: [CurseForgeModFile] = try await client.files(modId: Int(projectId))
            let gameVersion: String = minecraftVersion.id
            guard let candidate = files.first(where: { file in
                file.available
                    && file.minecraftVersions.contains(gameVersion)
                    && (loader.map { file.loaders.contains($0) } ?? true)
            }) else {
                return nil
            }
            return CurseForgeFile(
                client: client, url: nil,
                projectId: Int(projectId), fileId: Int(candidate.id)
            )
        }
    }
}
