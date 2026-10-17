//
//  ModLoaderInstallTask.swift
//  PCLMacCE
//

import Foundation
import SwiftyJSON

/// 获取 Mod 加载器在某游戏版本下的可用版本列表。
public enum ModLoaderVersions {
    public struct Version: Identifiable, Sendable {
        public let id: String
        public let isBeta: Bool

        public init(id: String) {
            self.id = id
            // 稳定版判断逻辑：https://github.com/PCL-Community/PCL2-CE/blob/45773cb9c69e677a3ae334c3d1f55f08468d623a/Plain%20Craft%20Launcher%202/Modules/Minecraft/ModDownload.vb#L1047
            self.isBeta = id.contains("alpha")
        }
    }

    /// 获取指定加载器在某游戏版本下的可用版本列表（新版本在前）。
    public static func fetch(type: ModLoader, minecraftVersion: String) async throws -> [Version] {
        guard let url = switch type {
        case .fabric:
            DownloadSourceManager.shared.fabricVersionListURL(for: minecraftVersion)
        case .forge:
            DownloadSourceManager.shared.forgeVersionListURL(for: minecraftVersion)
        case .neoforge:
            DownloadSourceManager.shared.neoforgeVersionListURL(for: minecraftVersion)
        } else {
            throw SimpleError("当前下载源不提供 \(type) 的版本列表。")
        }
        let versions: [Version] = switch type {
        case .fabric:
            try await HTTPClient.shared.get(url).json().arrayValue
                .map { Version(id: $0["loader"]["version"].stringValue) }
        case .forge:
            try await HTTPClient.shared.get(url).json().arrayValue
                .map { Version(id: $0["version"].stringValue) }
        case .neoforge:
            try await HTTPClient.shared.get(url).json().arrayValue
                .map { json in
                    let version: String = json["version"].stringValue
                    return Version(id: version.hasPrefix("1.20.1-") ? String(version.dropFirst("1.20.1-".count)) : version)
                }
        }
        return versions.sorted { $0.id.compare($1.id, options: .numeric) == .orderedDescending }
    }
}

/// 为已有实例补装 / 更换 Mod 加载器（Fabric / Forge / NeoForge）。
public enum ModLoaderInstallTask {
    /// 创建补装任务。复用全新安装的加载器子任务，安装完成后重载实例并回调。
    /// - Parameters:
    ///   - instance: 目标实例（其清单将被加载器清单替换，旧清单保留在 `.parent/`）。
    ///   - loader: 目标加载器与版本。
    ///   - repository: 实例所在仓库。
    ///   - onCompleted: 安装完成回调，参数为重载后的实例（modLoader 已更新）。
    public static func create(
        for instance: MinecraftInstance,
        loader: MinecraftInstallTask.Loader,
        in repository: MinecraftRepository,
        onCompleted: (@MainActor (MinecraftInstance) -> Void)? = nil
    ) -> MyTask<MinecraftInstallTask.Model> {
        let model: MinecraftInstallTask.Model = .init(
            name: instance.name, version: instance.version, repository: repository
        )
        model.manifest = instance.manifest

        var subTasks: [MyTask<MinecraftInstallTask.Model>.SubTask] = []
        MinecraftInstallTask.appendModLoaderSubTasks(
            into: &subTasks, modLoader: loader, version: instance.version, repository: repository
        )
        subTasks.append(
            .init(9, "__completion", display: false) { _, model in
                let newInstance = try await MinecraftInstanceLoader.load(from: model.runningDirectory)
                await MainActor.run {
                    onCompleted?(newInstance)
                }
            }
        )
        return .init(name: "安装 \(loader.type) - \(instance.name)", model: model, subTasks)
    }
}
