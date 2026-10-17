//
//  MinecraftLaunchManager.swift
//  PCLMacCE
//

import Foundation
@preconcurrency import Core
import Combine
import ZIPFoundation
import AppKit

@MainActor
class MinecraftLaunchManager: ObservableObject {
    public static let shared: MinecraftLaunchManager = .init()

    @Published public var isLaunching: Bool = false
    @Published public var progress: Double = 0
    @Published public var currentStage: String?
    @Published public var instanceName: String?
    @Published public var gameProcess: Process?
    public var isRunning: Bool { gameProcess != nil }
    public let loadingViewModel: MyLoadingViewModel = .init(text: "正在启动游戏")

    private var task: MyTask<MinecraftLaunchTask.Model>? {
        didSet {
            isLaunching = task != nil
            subscribeToTask()
        }
    }
    private var cancellables: [AnyCancellable] = []

    /// 开始启动游戏。
    /// - Parameters:
    ///   - instance: 目标游戏实例。
    ///   - account: 使用的账号。
    ///   - repository: 实例所在的游戏仓库。
    @MainActor
    public func launch(
        _ instance: MinecraftInstance,
        using account: Account,
        in repository: MinecraftRepository
    ) {
        if isLaunching { return }
        self.loadingViewModel.text = "正在启动游戏"
        let task: MyTask<MinecraftLaunchTask.Model> = MinecraftLaunchTask.create(
            for: instance, using: account, in: repository
        ) { [weak self] launcher, process in
            guard let self else { return }
            self.gameProcess = process
            process.terminationHandler = { [weak self] process in
                log("游戏进程已退出，退出代码：\(process.terminationStatus)")
                // 0 = 正常退出；9/15 及 128+n 是被 SIGKILL/SIGTERM/SIGINT 信号终止，均视为用户主动操作
                if ![0, 9, 15, 128 + 9, 128 + 15].contains(process.terminationStatus) {
                    log("游戏非正常退出")
                    let options = launcher.options
                    let logURL = launcher.logURL
                    Task { @MainActor in
                        self?.onGameCrash(instance: instance, options: options, logURL: logURL)
                    }
                } else {
                    do {
                        try FileManager.default.removeItem(at: launcher.logURL)
                    } catch {
                        warn("清理游戏日志失败：\(error.localizedDescription)")
                    }
                }
                Task { @MainActor in
                    self?.cancel()
                    self?.gameProcess = nil
                }
            }
            self.loadingViewModel.text = "已启动游戏"
        }
        TaskManager.shared.execute(task: task, display: false) { _ in
            self.task = nil
            self.currentStage = nil
            self.instanceName = nil
            self.progress = 0
        }
        self.instanceName = instance.name
        self.task = task
    }

    /// 取消当前启动任务。
    @MainActor
    public func cancel() {
        if let task {
            TaskManager.shared.cancel(task.id)
        }
    }

    public func stop() {
        if let gameProcess {
            gameProcess.terminate()
            self.gameProcess = nil
        }
    }

    private func onGameCrash(instance: MinecraftInstance, options: LaunchOptions, logURL: URL) {
        hint("检测到 Minecraft 发生崩溃，正在分析崩溃原因……", type: .critical)
        let crashReportsDirectory: URL = instance.url.appending(path: "crash-reports")
        Task.detached(priority: .userInitiated) {
            // 日志与崩溃报告的读取和匹配都在后台执行，避免大日志卡住界面
            let diagnosis: CrashAnalyzer.Diagnosis = await CrashAnalyzer.analyze(
                logURL: logURL, crashReportsDirectory: crashReportsDirectory
            )
            let suggestionText: String = diagnosis.isIdentified
                ? diagnosis.suggestions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                : "可以尝试导出崩溃报告并发给他人协助分析。"
            await MainActor.run {
                MessageBoxManager.shared.showText(
                    title: "Minecraft 发生崩溃",
                    content: "你的游戏发生了一些问题，无法继续运行。\n\n初步分析：\(diagnosis.title)\n\n\(suggestionText)\n\n若要寻求帮助，请点击“导出崩溃报告”并将导出的文件发给他人，而不是发送关于此页面的图片！！！",
                    level: .error,
                    .no(label: "返回"),
                    .yes(label: "导出崩溃报告")
                ) { result in
                    if result == 1 {
                        self.exportCrashReportFlow(instance: instance, options: options, logURL: logURL)
                    }
                }
            }
        }
    }

    /// 弹出保存面板并在后台导出崩溃报告。
    private func exportCrashReportFlow(instance: MinecraftInstance, options: LaunchOptions, logURL: URL) {
        let dateFormatter: DateFormatter = .init()
        dateFormatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        let fileName: String = "崩溃报告-\(dateFormatter.string(from: .now)).zip"
        let panel = NSSavePanel()
        panel.title = "选择报告位置"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = fileName
        let handleSave: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url: URL = panel.url else { return }
            hint("正在导出崩溃报告……")
            // 报告打包与压缩是磁盘 IO，放后台执行，避免大日志导出时冻结界面
            Task.detached(priority: .userInitiated) {
                do {
                    try Self.exportCrashReport(for: instance, to: url, with: fileName, options: options, logURL: logURL)
                    log("导出崩溃报告成功")
                    await MainActor.run { hint("导出崩溃报告成功！", type: .finish) }
                } catch {
                    err("导出崩溃报告失败：\(error.localizedDescription)")
                    await MainActor.run { hint("导出崩溃报告失败：\(error.localizedDescription)", type: .critical) }
                }
            }
        }
        if let window = NSApplication.shared.keyWindow ?? NSApplication.shared.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handleSave)
        } else {
            panel.begin(completionHandler: handleSave)
        }
    }

    private nonisolated static func exportCrashReport(for instance: MinecraftInstance, to destination: URL, with fileName: String, options: LaunchOptions, logURL: URL) throws {
        let reportURL: URL = URLConstants.tempURL.appending(path: fileName)
        try FileManager.default.createDirectory(at: reportURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: reportURL) }

        let launcherInfo: LauncherInfo = .init(
            launcher: "PCL Mac CE",
            launcherVersion: Metadata.appVersion,
            minecraftVersion: instance.version.id,
            javaVersion: options.javaRuntime.version,
            javaArchitecture: options.javaRuntime.architecture.rawValue,
            instanceName: instance.name
        )

        try JSONEncoder.shared.encode(launcherInfo).write(to: reportURL.appending(path: "launcher-info.json"))

        if FileManager.default.fileExists(atPath: logURL.path) {
            try FileManager.default.copyItem(at: logURL, to: reportURL.appending(path: "game-log.log"))
        }

        let crashReportDirectory: URL = instance.url.appending(path: "crash-reports")
        if FileManager.default.fileExists(atPath: crashReportDirectory.path) {
            let crashReports: [URL] = try FileManager.default.contentsOfDirectory(
                at: crashReportDirectory, includingPropertiesForKeys: [.contentModificationDateKey]
            )
            if let latestCrashReport: URL = crashReports
                .filter({ (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false })
                .max(by: { lhs, rhs in
                    let lDate: Date? = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    let rDate: Date? = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                    return (lDate ?? .distantPast) < (rDate ?? .distantPast)
                }) {
                try FileManager.default.copyItem(at: latestCrashReport, to: reportURL.appending(path: "crash-report.txt"))
            }
        }
        try FileManager.default.zipItem(at: reportURL, to: destination, shouldKeepParent: false)
    }

    private func subscribeToTask() {
        cancellables.removeAll()
        guard let task else { return }
        task.$currentTaskOrdinal
            .map { [weak self] ordinal in
                guard let ordinal else {
                    return nil
                }
                return self?.stageString(for: ordinal)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentStage, on: self)
            .store(in: &cancellables)

        task.$progress
            .receive(on: DispatchQueue.main)
            .assign(to: \.progress, on: self)
            .store(in: &cancellables)
    }

    private func stageString(for ordinal: Int) -> String {
        switch ordinal {
        case 0: "检查 Java"
        case 1: "刷新账号"
        case 2: "预检查"
        case 3: "检查资源完整性"
        case 4: "检查 Authlib Injector"
        case 5: "启动游戏"
        case 6: "等待游戏窗口出现"
        default: "\(ordinal)"
        }
    }

    private init() {}

    private struct LauncherInfo: Codable {
        public let launcher: String
        public let launcherVersion: String
        public let minecraftVersion: String
        public let javaVersion: String
        public let javaArchitecture: String
        public let instanceName: String
    }
}
