//
//  InstanceConfigViewModel.swift
//  PCLMacCE
//

import Foundation
import Core

@MainActor
class InstanceConfigViewModel: ObservableObject {
    @Published public var instance: MinecraftInstance
    @Published public var jvmHeapSize: String = ""
    @Published public var jvmArguments: String = ""
    @Published public var javaDescription: String = "无"

    public var description: String {
        if let modLoader: ModLoader = instance.modLoader {
            return "\(instance.version.description)，\(modLoader)"
        }
        return instance.version.description
    }

    public var icon: ImageResource {
        if let modLoader: ModLoader = instance.modLoader {
            return modLoader.icon
        }
        return .iconGrassBlock
    }

    public let id: String
    private let instanceManager: InstanceManager

    public init(instanceManager: InstanceManager, id: String) {
        self.instanceManager = instanceManager
        self.id = id
        self.instance = instanceManager.currentRepository.instance(named: id)! // TODO: 改为安全解包
        self.jvmHeapSize = instance.config.jvmHeapSize.description
        self.jvmArguments = instance.config.jvmArguments.joinedToArgumentLine()
        do {
            self.javaDescription = try instance.config.javaURL.map({ try JavaSearcher.load(from: $0) })?.description ?? "无"
        } catch {}
    }

    public func javaList() -> [JavaRuntime] {
        return JavaManager.shared.javaRuntimes
            .filter { $0.executableURL != instance.config.javaURL }
            .sorted { $0.version > $1.version }
    }

    @MainActor
    public func setHeapSize(_ heapSize: UInt64) {
        // 限制在合理范围内：过小无法启动，过大超过物理内存
        let maxMB: UInt64 = UInt64(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
        let clamped: UInt64 = min(max(heapSize, Self.minHeapSizeMB), maxMB)
        if clamped != heapSize {
            hint("内存分配已限制在 \(Self.minHeapSizeMB)–\(maxMB) MB", type: .critical)
            jvmHeapSize = clamped.description
        }
        instance.config.jvmHeapSize = clamped
        instance.markDirty()
    }

    /// 内存分配下限（MB）。
    private static let minHeapSizeMB: UInt64 = 512

    @MainActor
    public func setJvmArguments(_ arguments: String) {
        instance.config.jvmArguments = arguments.splitToArguments()
        instance.markDirty()
    }

    @MainActor
    public func switchJava(to runtime: JavaRuntime) throws {
        if runtime.majorVersion < instance.manifest.javaVersion.majorVersion {
            throw Error.invalidJavaVersion(min: instance.manifest.javaVersion.majorVersion)
        }
        instance.config.javaURL = runtime.executableURL
        instance.markDirty()
        javaDescription = runtime.description
    }

    public enum Error: Swift.Error {
        case invalidJavaVersion(min: Int)
    }
}
