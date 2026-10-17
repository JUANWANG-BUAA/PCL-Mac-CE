//
//  JavaManager.swift
//  PCLMacCE
//

import Foundation

public final class JavaManager: ObservableObject {
    public static var shared: JavaManager!

    @Published public private(set) var javaRuntimes: [JavaRuntime]
    private var customJavaRuntimes: [URL]
    /// 初始搜索任务；供需要完整列表的调用方等待搜索完成。
    private var initialSearchTask: Task<Void, Never>?

    public init(customJavaRuntimes: [URL]) {
        self.customJavaRuntimes = customJavaRuntimes
        self.javaRuntimes = []
    }

    /// 开始初始 Java 搜索。全盘搜索可能耗时较长，放到后台执行以避免阻塞启动；
    /// 创建 `JavaManager` 后应调用一次本方法，搜索完成后列表会自动更新。
    @MainActor
    public func startInitialSearch() {
        guard initialSearchTask == nil else { return }
        let customRuntimes: [URL] = customJavaRuntimes
        initialSearchTask = Task { [weak self] in
            let result: [JavaRuntime]? = await Task.detached(priority: .userInitiated) {
                do {
                    let runtimes: [JavaRuntime] = try JavaSearcher.search(customJavaRuntimes: customRuntimes)
                    Self.logSearchResult(runtimes)
                    return runtimes
                } catch {
                    err("搜索 Java 失败：\(error.localizedDescription)")
                    return nil
                }
            }.value
            if let runtimes = result {
                self?.javaRuntimes = runtimes
            }
        }
    }

    /// 等待初始 Java 搜索完成。启动游戏等依赖完整 Java 列表的流程应先调用此方法。
    @MainActor
    public func waitForInitialSearch() async {
        _ = await initialSearchTask?.value
    }

    /// 重新搜索环境中的 Java，并在主线程上更新列表。
    @MainActor
    public func research() async throws {
        let customRuntimes: [URL] = customJavaRuntimes
        let runtimes: [JavaRuntime] = try await Task.detached(priority: .userInitiated) {
            try JavaSearcher.search(customJavaRuntimes: customRuntimes)
        }.value
        self.javaRuntimes = runtimes
        Self.logSearchResult(runtimes)
    }

    @MainActor
    public func addCustomRuntime(_ runtime: JavaRuntime) -> Bool {
        if javaRuntimes.contains(runtime) { return false }
        javaRuntimes.append(runtime)
        customJavaRuntimes.append(runtime.executableURL)
        return true
    }

    @MainActor
    @discardableResult
    public func removeCustomRuntime(_ executableURL: URL) -> Bool {
        guard let index = javaRuntimes.firstIndex(where: { $0.executableURL == executableURL }) else {
            return false
        }
        javaRuntimes.remove(at: index)
        customJavaRuntimes.removeAll(where: { $0 == executableURL })
        return true
    }

    private static func logSearchResult(_ runtimes: [JavaRuntime]) {
        log("Java 搜索完成，共 \(runtimes.count) 个：")
        for javaRuntime in runtimes {
            let type: String = .init(describing: javaRuntime.type).padding(toLength: 4, withPad: " ", startingAt: 0)
            let version: String = .init(describing: javaRuntime.version).padding(toLength: 10, withPad: " ", startingAt: 0)
            let arch: String = .init(describing: javaRuntime.architecture).padding(toLength: 8, withPad: " ", startingAt: 0)
            let impl: String = (javaRuntime.implementor ?? "").padding(toLength: 24, withPad: " ", startingAt: 0)
            log("\(type) \(version)\t\(arch)\t\(impl)\t\(javaRuntime.executableURL.path)")
        }
    }
}
