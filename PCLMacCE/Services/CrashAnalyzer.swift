//
//  CrashAnalyzer.swift
//  PCLMacCE
//

import Foundation
import Core

/// 崩溃原因的初步识别（v1）：基于游戏日志与崩溃报告的关键字模式匹配。
/// 不追求精确归因，目标是把最常见的几类问题用一句话解释清楚，并给出可操作建议。
enum CrashAnalyzer {
    struct Diagnosis {
        /// 一句话的原因标题（如“内存不足”）。
        let title: String
        /// 可操作的建议列表。
        let suggestions: [String]
        /// 是否识别出了明确原因。
        var isIdentified: Bool { !suggestions.isEmpty }
    }

    /// 分析崩溃原因。读取游戏日志末尾与最新崩溃报告的开头，两者各截取一部分以控制内存占用。
    /// - Parameters:
    ///   - logURL: 本次启动的游戏日志。
    ///   - crashReportsDirectory: 实例的 crash-reports 目录。
    static func analyze(logURL: URL?, crashReportsDirectory: URL?) async -> Diagnosis {
        let logText: String? = logURL.flatMap { readTail(of: $0, bytes: 256 * 1024) }
        let crashReportText: String? = await latestCrashReport(in: crashReportsDirectory)
            .flatMap { readHead(of: $0, bytes: 256 * 1024) }
        return analyze(logText: logText, crashReportText: crashReportText)
    }

    /// 单个崩溃模式：命中 `matchAny` 中任意关键字，或同时存在 `matchAll` 的全部关键字即匹配。
    private struct Pattern {
        let matchAny: [String]
        var matchAll: [String] = []
        let title: String
        let suggestions: [String]

        func matches(_ text: String) -> Bool {
            if matchAny.contains(where: text.contains) { return true }
            return !matchAll.isEmpty && matchAll.allSatisfy(text.contains)
        }
    }

    /// 按建议的具体程度从高到低排列，命中即停止。
    private static let patterns: [Pattern] = [
        Pattern(
            matchAny: ["outofmemoryerror", "out of memory"],
            title: "内存不足",
            suggestions: [
                "在实例设置中调大内存分配（大型整合包通常需要 4GB 以上）",
                "关闭其他占用内存的应用后重试",
                "如果内存已经很大，尝试移除部分模组"
            ]
        ),
        Pattern(
            matchAny: ["unsupportedclassversionerror"],
            title: "Java 版本不匹配",
            suggestions: [
                "这个实例或其中的模组需要不同版本的 Java：老版本游戏（1.16 及更早）需要 Java 8~17，新版本需要 Java 17+",
                "在实例设置中切换 Java 后重新启动"
            ]
        ),
        Pattern(
            matchAny: ["mod list:", "net.fabricmc", "org.spongepowered", "net.minecraftforge"],
            title: "很可能是模组引发了崩溃",
            suggestions: [
                "查看崩溃报告中的 Mod List 与异常堆栈，定位最近添加的模组",
                "移除或更新可疑模组后再试",
                "一次性添加了很多模组时，可以分批添加来定位问题"
            ]
        ),
        Pattern(
            matchAny: ["noclassdeffounderror", "classnotfoundexception"],
            title: "缺失文件或依赖",
            suggestions: [
                "游戏文件可能损坏，或某些模组缺少前置依赖",
                "在任务中对该实例重新执行一次安装/补全资源",
                "确认模组的前置模组都已安装且版本匹配"
            ]
        ),
        Pattern(
            matchAny: ["failed to create window", "failed to create opengl window"],
            title: "游戏窗口创建失败",
            suggestions: [
                "断开外接显示器或调整显示器配置后重试",
                "删除实例目录下的 options.txt 以重置视频设置"
            ]
        ),
        Pattern(
            matchAny: ["glfw error", "opengl", "gl_invalid"],
            title: "图形渲染问题",
            suggestions: [
                "更新 macOS 与显卡驱动后重试",
                "在实例设置中尝试降低渲染距离与画质选项",
                "光影包对显卡要求较高，可先关闭光影测试"
            ]
        ),
        Pattern(
            matchAny: ["no space left on device"],
            title: "磁盘空间不足",
            suggestions: [
                "清理磁盘空间后重新启动游戏"
            ]
        ),
        Pattern(
            matchAny: ["invalid session"],
            matchAll: ["authlib", "failed"],
            title: "账号验证问题",
            suggestions: [
                "重新登录当前账号后再启动",
                "使用离线模式时无法加入需要正版验证的服务器"
            ]
        )
    ]

    /// 纯文本分析入口（供测试）。
    static func analyze(logText: String?, crashReportText: String?) -> Diagnosis {
        let text: String = ((logText ?? "") + "\n" + (crashReportText ?? "")).lowercased()
        for pattern in patterns where pattern.matches(text) {
            return .init(title: pattern.title, suggestions: pattern.suggestions)
        }
        return .init(title: "未能识别崩溃原因", suggestions: [])
    }

    /// 读取文件末尾的指定字节数（按 UTF-8 容错解码）。
    private static func readTail(of url: URL, bytes: Int) -> String? {
        guard let handle: FileHandle = try? .init(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let fileSize: UInt64 = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? UInt64) ?? 0
        guard fileSize > 0 else { return nil }
        let start: UInt64 = fileSize > UInt64(bytes) ? fileSize - UInt64(bytes) : 0
        guard (try? handle.seek(toOffset: start)) != nil else { return nil }
        let data: Data = (try? handle.read(upToCount: bytes)) ?? Data()
        return String(data: data, encoding: .utf8) ?? String(data: data.dropFirst(data.count / 4), encoding: .utf8)
    }

    /// 读取文件开头的指定字节数。
    private static func readHead(of url: URL, bytes: Int) -> String? {
        guard let handle: FileHandle = try? .init(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data: Data = (try? handle.read(upToCount: bytes)) ?? Data()
        return String(data: data, encoding: .utf8)
    }

    /// 找到 crash-reports 目录中修改时间最新的崩溃报告。
    private static func latestCrashReport(in directory: URL?) async -> URL? {
        guard let directory,
              let files: [URL] = try? FileManager.default.contentsOfDirectory(
                  at: directory, includingPropertiesForKeys: [.contentModificationDateKey]
              ) else { return nil }
        return files
            .filter { $0.lastPathComponent.hasPrefix("crash-") }
            .max { lhs, rhs in
                let lDate: Date = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let rDate: Date = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return lDate < rDate
            }
    }
}
