//
//  InstanceConfigViewModel.swift
//  PCLMacCE
//

import Foundation
import Core

@MainActor
class InstanceConfigViewModel: ObservableObject {
    /// 目标实例；实例被删除或尚未加载完成时为 nil（页面显示占位状态）。
    @Published public var instance: MinecraftInstance?
    @Published public var jvmHeapSize: String = ""
    @Published public var jvmArguments: String = ""
    @Published public var javaDescription: String = "无"

    public var description: String {
        guard let instance else { return "实例不存在或尚未加载" }
        if let modLoader: ModLoader = instance.modLoader {
            return "\(instance.version.description)，\(modLoader)"
        }
        return instance.version.description
    }

    public var icon: ImageResource {
        guard let modLoader: ModLoader = instance?.modLoader else { return .iconGrassBlock }
        return modLoader.icon
    }

    public let id: String
    private let instanceManager: InstanceManager
    private var saveTask: Task<Void, Never>?

    public init(instanceManager: InstanceManager, id: String) {
        self.instanceManager = instanceManager
        self.id = id
        // 优先当前仓库；实例列表与配置页可能处于不同仓库上下文，故回退到全部仓库查找
        let instance = instanceManager.currentRepository.instance(named: id)
            ?? instanceManager.repositories.values.compactMap { $0.instance(named: id) }.first
        if instance == nil {
            err("实例 \(id) 不存在或尚未加载，配置页显示占位状态。")
        }
        self.instance = instance
        self.jvmHeapSize = instance?.config.jvmHeapSize.description ?? ""
        self.jvmArguments = instance?.config.jvmArguments.joinedToArgumentLine() ?? ""
        do {
            self.javaDescription = try instance?.config.javaURL.map({ try JavaSearcher.load(from: $0) })?.description ?? "无"
        } catch {}
    }

    public func javaList() -> [JavaRuntime] {
        return JavaManager.shared.javaRuntimes
            .filter { $0.executableURL != instance?.config.javaURL }
            .sorted { $0.version > $1.version }
    }

    /// 用重载后的实例替换当前实例（补装加载器完成后调用）。
    public func replaceInstance(_ updated: MinecraftInstance) {
        self.instance = updated
        self.jvmHeapSize = updated.config.jvmHeapSize.description
        self.jvmArguments = updated.config.jvmArguments.joinedToArgumentLine()
        do {
            self.javaDescription = try updated.config.javaURL.map({ try JavaSearcher.load(from: $0) })?.description ?? "无"
        } catch {}
    }

    /// 重命名实例；返回重载后的实例，失败时抛出。
    public func rename(to newName: String) async throws -> MinecraftInstance {
        guard let instance else { throw SimpleError("实例不存在。") }
        let renamed: MinecraftInstance = try await instanceManager.currentRepository.renameInstance(instance, to: newName)
        replaceInstance(renamed)
        return renamed
    }

    @MainActor
    public func setHeapSize(_ heapSize: UInt64) {
        guard let instance else { return }
        // 限制在合理范围内：过小无法启动，过大超过物理内存
        let maxMB: UInt64 = UInt64(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
        let clamped: UInt64 = min(max(heapSize, Self.minHeapSizeMB), maxMB)
        if clamped != heapSize {
            hint("内存分配已限制在 \(Self.minHeapSizeMB)–\(maxMB) MB", type: .critical)
            jvmHeapSize = clamped.description
        }
        instance.config.jvmHeapSize = clamped
        instance.markDirty()
        scheduleSave()
    }

    /// 内存分配下限（MB）。
    private static let minHeapSizeMB: UInt64 = 512

    @MainActor
    public func setJvmArguments(_ arguments: String) {
        guard let instance else { return }
        instance.config.jvmArguments = arguments.splitToArguments()
        instance.markDirty()
        scheduleSave()
    }

    @MainActor
    public func switchJava(to runtime: JavaRuntime) throws {
        guard let instance else { return }
        if runtime.majorVersion < instance.manifest.javaVersion.majorVersion {
            throw Error.invalidJavaVersion(min: instance.manifest.javaVersion.majorVersion)
        }
        // 上界仅警告（不阻止）：某些兼容层或特殊场景下用户可能需要更高版本
        if let maxVersion = JavaSearcher.maximumJavaVersion(for: instance.version),
           runtime.majorVersion > maxVersion {
            hint("注意：这个实例通常需要 Java \(maxVersion) 或更低，所选版本可能无法启动。", type: .critical)
        }
        instance.config.javaURL = runtime.executableURL
        instance.markDirty()
        javaDescription = runtime.description
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(seconds: 0.5)
                try Task.checkCancellation()
                self?.savePendingChanges()
            } catch {}
        }
    }

    public func savePendingChanges() {
        saveTask?.cancel()
        saveTask = nil
        guard let instance, instance.dirty else { return }
        do {
            try MinecraftInstanceLoader.save(instance)
            instance.dirty = false
        } catch {
            err("保存实例设置失败：\(error.localizedDescription)")
            hint("保存实例设置失败：\(error.localizedDescription)", type: .critical)
        }
    }

    public enum Error: Swift.Error {
        case invalidJavaVersion(min: Int)
    }
}
