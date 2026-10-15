//
//  ModpackViewModel.swift
//  PCLMacCE
//

import Foundation
import Core

@MainActor
class ModpackViewModel: ObservableObject {
    private let instanceManager: InstanceManager

    init(instanceManager: InstanceManager) {
        self.instanceManager = instanceManager
    }

    @MainActor
    public func importModpack(at url: URL, repository: MinecraftRepository) async {
        guard let curseforgeApiKey = Secrets.shared.curseforgeApiKey else {
            hint("缺少 CurseForge API Key，无法开始整合包导入，请尝试从官方渠道重新下载 PCLMacCE！", type: .critical)
            return
        }

        let service = ModpackImportService(curseforgeClient: .init(apiKey: curseforgeApiKey), modpackURL: url)
        do {
            let index = try service.load()
            guard await confirmModpackInfo(index) else { return }
            guard let name = await MessageBoxManager.shared.showInputAsync(
                title: "导入整合包 - 输入实例名",
                initialContent: index.name
            ) else { return }

            let completion: @MainActor (MinecraftInstance) -> Void = { instance in
                self.instanceManager.switchInstance(to: instance, in: repository)
            }
            // 两个任务工厂返回不同的任务模型类型，需分别创建与执行
            if index.format == .simple {
                let task = try service.createSimpleImportTask(name: name, repository: repository, completion: completion)
                TaskManager.shared.execute(task: task)
            } else {
                let task = try service.createImportTask(name: name, repository: repository, completion: completion)
                TaskManager.shared.execute(task: task)
            }
            AppRouter.shared.append(.tasks)
        } catch let error as ModpackImportService.LoadError {
            handleLoadError(error)
        } catch let error as ModpackImportService.ImportError {
            handleImportError(error)
        } catch {
            // 除上述两个类型化错误外，导入过程中的文件系统等错误会落到这里
            handleUnknownError(error)
        }
    }

    /// 展示整合包信息并请求用户确认；返回用户是否继续。
    private func confirmModpackInfo(_ index: ModpackIndex) async -> Bool {
        await MessageBoxManager.shared.showTextAsync(
            title: "整合包信息",
            content: "格式：\(index.format)\n名称：\(index.name)\n版本：\(index.version)\n作者：\(index.author ?? "未知")\n描述：\(index.description ?? "空")\n依赖：\(index.dependencyInfo)\n\n是否继续安装？",
            level: .info,
            .no(),
            .yes(label: "继续")
        ) == 1
    }

    /// 处理整合包加载阶段的分类错误。
    private func handleLoadError(_ error: ModpackImportService.LoadError) {
        switch error {
        case .extractFailed:
            MessageBoxManager.shared.showText(
                title: "解压整合包失败",
                content: "\(error.localizedDescription)",
                level: .error
            )
        case .unsupportedModLoader(let name):
            MessageBoxManager.shared.showText(
                title: "不支持的模组加载器",
                content: "很抱歉，PCLMacCE 暂时不支持安装这个整合包使用的 \(name) 加载器……",
                level: .error
            )
        case .unknownFormat:
            MessageBoxManager.shared.showText(
                title: "不支持的整合包格式",
                content: "很抱歉，PCLMacCE 目前只支持导入 Modrinth、CurseForge、MCBBS 和普通压缩包格式的整合包，不支持这个整合包使用的格式……",
                level: .error
            )
        default:
            handleUnknownError(error)
        }
    }

    /// 处理整合包导入阶段的分类错误。
    private func handleImportError(_ error: ModpackImportService.ImportError) {
        switch error {
        case .invalidName(let underlying):
            hint("该名称无效：\(underlying.localizedDescription)", type: .critical)
        case .extractFailed:
            MessageBoxManager.shared.showText(
                title: "解压整合包失败",
                content: "\(error.localizedDescription)",
                level: .error
            )
        default:
            handleUnknownError(error)
        }
    }

    /// 展示未知错误弹窗。
    private func handleUnknownError(_ error: Error) {
        MessageBoxManager.shared.showText(
            title: "发生未知错误",
            content: "\(error.localizedDescription)\n\n若要寻求帮助，请将完整日志报告发送给他人，而不是发送关于此页面的图片。",
            level: .error
        )
    }
}
