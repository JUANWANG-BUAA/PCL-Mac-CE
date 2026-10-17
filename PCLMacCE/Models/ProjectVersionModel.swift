//
//  ProjectVersionModel.swift
//  PCLMacCE
//

import Foundation
import Core

struct ProjectVersionModel: Identifiable {
    struct Dependency: Identifiable {
        public let id: UUID = .init()
        public let versionId: String?
        public let projectId: String
        public let project: ProjectListItemModel
    }

    /// 中性的主要文件描述：Modrinth 与 CurseForge 的安装流程共用。
    struct File {
        public let name: String
        public let url: URL
        public let sha1: String?

        public init(name: String, url: URL, sha1: String?) {
            self.name = name
            self.url = url
            self.sha1 = sha1
        }
    }

    public let id: String
    public let name: String
    public let version: String
    public let downloads: String
    public let datePublished: String
    public let requiredDependencies: [Dependency]
    /// CurseForge 文件级别的必需依赖 ID，供安装时解析兼容文件。
    public let requiredCurseForgeDependencyIds: [Int32]
    /// 元数据批量查询未返回的依赖 ID；安装时仍会尝试解析。
    public let unresolvedCurseForgeDependencyIds: [Int32]
    public let type: ModrinthVersion.VersionType
    public let primaryFile: File?
    public let gameVersion: String
    public let loader: ModLoader?
}
