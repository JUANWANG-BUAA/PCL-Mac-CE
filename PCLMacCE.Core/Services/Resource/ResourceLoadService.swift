//
//  ResourceLoadService.swift
//  PCLMacCE
//

import Foundation
import ZIPFoundation

public class ResourceLoadService {
    private let preferredType: ResourceType?
    private let remoteLookupService: ResourceRemoteLookupService
    private let cache: ResourceCache
    private let validPathExtensions = ["zip", "jar", "disabled"]
    private let parsers: [ResourceParser.Type] = [
        ModParser.self,
        ResourcepackParser.self,
        ShaderParser.self
    ]

    public init(preferredType: ResourceType? = nil, remoteLookupService: ResourceRemoteLookupService, cache: ResourceCache) {
        self.preferredType = preferredType
        self.remoteLookupService = remoteLookupService
        self.cache = cache
    }

    /// 将单个资源文件加载为 `Resource` 结构体。
    /// - Returns: 一个 `Resource`，若无法识别资源则返回 `nil`。
    /// - Throws: `LoadError`
    public func load(at fileURL: URL) async throws(LoadError) -> Resource? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            throw .fileNotExists
        }
        guard isDirectory.boolValue == false else { throw .foundDirectory }

        let sha1: String
        do {
            sha1 = try cache.sha1(for: fileURL) { try FileUtils.sha1(of: fileURL) }
        } catch {
            throw .readError(underlying: error)
        }

        if let cached = cache.resource(forHash: sha1) { return cached }

        let remoteInfo: ResourceRemoteLookupService.RemoteResourceInfo?
        do {
            remoteInfo = try await remoteLookupService.lookup(hash: sha1)
        } catch {
            err("加载 \(fileURL.lastPathComponent) 的远端资源信息失败：\(error.localizedDescription)")
            remoteInfo = nil
        }

        if let resource = try parseFile(at: fileURL, remoteInfo: remoteInfo, sha1: sha1) {
            cache.store(resource, forHash: sha1)
            return resource
        }
        return nil
    }

    /// 遍历目录中的资源文件，并将它们加载为 `Resource` 结构体。
    /// - Parameter directoryURL: 目录的 `URL`。
    /// - Returns: `[URL: Resource]` 字典，包含所有加载成功的模组。
    /// - Throws: `LoadError`
    public func loadResources(in directoryURL: URL) async throws(LoadError) -> [URL: Resource] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) else {
            return [:]
        }
        guard isDirectory.boolValue == true else { throw .foundFile }

        var stats: LoadStats = .init()
        defer { debug("资源目录加载完成，共 \(stats.total) 个文件，\(stats.cached) 个命中缓存，\(stats.loaded) 个加载成功，\(stats.unsupported) 个无法识别，\(stats.failed) 个加载失败") }

        var result: [URL: Resource] = [:]
        var hashes: [URL: String] = [:]
        try scanCachedResources(in: directoryURL, result: &result, hashes: &hashes, stats: &stats)

        if hashes.isEmpty {
            return result
        }

        let remoteLookupResult: [String: ResourceRemoteLookupService.RemoteResourceInfo]
        do {
            remoteLookupResult = try await remoteLookupService.lookup(hashes: Array(Set(hashes.values)).sorted())
        } catch {
            err("加载远端资源信息失败：\(error.localizedDescription)")
            remoteLookupResult = [:]
        }

        var parsedByHash: [String: Resource] = [:]
        for (fileURL, hash) in hashes {
            if let resource = parsedByHash[hash] {
                result[fileURL] = resource
                stats.loaded += 1
                continue
            }
            do {
                guard let resource = try parseFile(at: fileURL, remoteInfo: remoteLookupResult[hash], sha1: hash) else {
                    stats.unsupported += 1
                    warn("无法识别 \(fileURL.lastPathComponent) 的类型")
                    continue
                }
                result[fileURL] = resource
                parsedByHash[hash] = resource
                stats.loaded += 1
                cache.store(resource, forHash: hash)
            } catch {
                err("处理资源 \(fileURL.lastPathComponent) 失败：\(error.localizedDescription)")
                stats.failed += 1
            }
        }

        return result
    }

    /// 加载统计。
    private struct LoadStats {
        var total = 0
        var cached = 0
        var loaded = 0
        var unsupported = 0
        var failed = 0
    }

    /// 扫描目录文件：命中本地缓存的直接入结果，未命中的记录哈希待远端查询。
    private func scanCachedResources(
        in directoryURL: URL,
        result: inout [URL: Resource],
        hashes: inout [URL: String],
        stats: inout LoadStats
    ) throws(LoadError) {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { throw .failedToCreateEnumerator }

        for case let fileURL as URL in enumerator {
            let isRegular: Bool = (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            guard validPathExtensions.contains(fileURL.pathExtension) && isRegular else { continue }
            stats.total += 1
            do {
                try autoreleasepool {
                    let hash = try cache.sha1(for: fileURL) { try FileUtils.sha1(of: fileURL) }
                    if let resource = cache.resource(forHash: hash) {
                        stats.cached += 1
                        result[fileURL] = resource
                    } else {
                        hashes[fileURL] = hash
                    }
                }
            } catch {
                err("处理文件 \(fileURL.lastPathComponent) 失败：\(error.localizedDescription)")
            }
        }
    }

    public enum LoadError: LocalizedError {
        case fileNotExists
        case foundDirectory
        case foundFile
        case failedToCreateEnumerator
        case readError(underlying: Error)
        case extractError(underlying: Error)

        public var errorDescription: String? {
            switch self {
            case .fileNotExists:
                "指定的资源文件不存在。"
            case .foundDirectory:
                "期望获得文件，但找到了一个文件夹。"
            case .foundFile:
                "期望获得文件夹，但找到了一个文件。"
            case .failedToCreateEnumerator:
                "创建文件遍历器失败。"
            case .readError(let underlying):
                "读取文件失败：\(underlying.localizedDescription)"
            case .extractError(let underlying):
                "解压文件失败：\(underlying.localizedDescription)"
            }
        }
    }

    private func parseFile(at url: URL, remoteInfo: ResourceRemoteLookupService.RemoteResourceInfo?, sha1: String) throws(LoadError) -> Resource? {
        let archive: Archive
        do {
            archive = try .init(url: url, accessMode: .read)
        } catch {
            throw .extractError(underlying: error)
        }

        var fileType: ResourceType?
        var parseResult: ResourceParseResult?

        let preferredParsers = parsers.filter { $0.type == preferredType }
        let otherParsers = parsers.filter { $0.type != preferredType }
        for parser in preferredParsers + otherParsers {
            if parser.canHandle(fileURL: url, archive: archive),
               let result = parser.parse(fileURL: url, archive: archive, remoteInfo: remoteInfo) {
                debug("成功解析 \(url.lastPathComponent)，类型：\(parser.type)")
                fileType = parser.type
                parseResult = result
                break
            }
        }

        guard let fileType, let parseResult else { return nil }

        let icon: Resource.Icon?
        if let iconPath = parseResult.iconPath, let entry = archive[iconPath] {
            do {
                let iconData = try archive.extract(entry)
                let hash = try cache.store(iconData, relativePath: iconPath, fileHash: sha1)
                icon = .archiveEntry(path: iconPath, globalHash: hash)
            } catch {
                err("写入图标缓存失败：\(error.localizedDescription)")
                icon = nil
            }
        } else if let iconURL = remoteInfo?.icon {
            icon = .network(url: iconURL)
        } else {
            icon = nil
        }

        return .init(
            type: fileType,
            name: parseResult.name,
            version: parseResult.version,
            description: parseResult.description,
            icon: icon,
            loaders: parseResult.loaders,
            tags: remoteInfo?.tags ?? [],
            sources: (remoteInfo?.source).map { [$0] } ?? []
        )
    }
}
