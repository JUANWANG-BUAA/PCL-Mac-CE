//
//  FileDropHandler.swift
//  PCLMacCE
//

import Foundation
@preconcurrency import Core

enum FileDropHandler {
    @MainActor
    static func handle(_ url: URL, instanceManager: InstanceManager) async {
        if ModpackImportService.isModpack(url) {
            let viewModel = ModpackViewModel(instanceManager: instanceManager)
            await viewModel.importModpack(at: url, repository: instanceManager.currentRepository)
            return
        }

        let resourceLoadService = ResourceLoadService(
            remoteLookupService: .init(curseforgeClient: .init(apiKey: Secrets.shared.curseforgeApiKey ?? "")),
            cache: .shared
        )
        do {
            guard let resource = try await resourceLoadService.load(at: url) else {
                hint("无法识别 \(url.lastPathComponent) 的类型！", type: .critical)
                return
            }
            guard let instance = instanceManager.currentInstance else {
                hint("请先选择一个实例！", type: .critical)
                return
            }
            if resource.type == .mod && instance.modLoader == nil {
                hint("该实例不支持安装模组！", type: .critical)
                return
            }
            guard let directoryName = resource.type.saveDirectory else {
                hint("暂不支持导入此类资源！", type: .critical)
                return
            }

            let destinationDirectory = instance.url.appending(path: directoryName)
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: destinationDirectory.appending(path: url.lastPathComponent))
            hint("添加\(resource.type.localizedName) \(resource.name) 成功！", type: .finish)
        } catch {
            err("导入 \(url.lastPathComponent) 失败：\(error.localizedDescription)")
            hint("导入失败：\(error.localizedDescription)", type: .critical)
        }
    }
}
