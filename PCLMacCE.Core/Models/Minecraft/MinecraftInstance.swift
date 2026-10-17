//
//  MinecraftInstance.swift
//  PCLMacCE
//

import Foundation

public class MinecraftInstance: Hashable, Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let version: MinecraftVersion
    public let modLoader: ModLoader?
    public let manifest: ClientManifest

    public var config: Config

    public var dirty: Bool

    public var name: String { url.lastPathComponent }
    public var manifestURL: URL { url.appending(path: "\(name).json") }

    public init(id: UUID, url: URL, version: MinecraftVersion, modLoader: ModLoader?, manifest: ClientManifest, config: Config, dirty: Bool = false) {
        self.id = id
        self.url = url
        self.version = version
        self.modLoader = modLoader
        self.manifest = manifest
        self.config = config
        self.dirty = dirty
    }

    public func markDirty() { self.dirty = true }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: MinecraftInstance, rhs: MinecraftInstance) -> Bool {
        return lhs.id == rhs.id
    }

    public struct Config: Codable {
        public var jvmHeapSize: UInt64
        public var javaURL: URL?
        public var jvmArguments: [String]
        /// 自定义游戏窗口宽度；与高度同时有值时才生效，否则使用游戏内设置。
        public var windowWidth: Int?
        public var windowHeight: Int?
        /// 启动时强制全屏（写入 options.txt 的 fullscreen 项）。
        public var fullscreen: Bool

        public static let `default`: Config = .init(jvmHeapSize: 4096, javaURL: nil)

        public init(
            jvmHeapSize: UInt64,
            javaURL: URL?,
            jvmArguments: [String] = [],
            windowWidth: Int? = nil,
            windowHeight: Int? = nil,
            fullscreen: Bool = false
        ) {
            self.jvmHeapSize = jvmHeapSize
            self.javaURL = javaURL
            self.jvmArguments = jvmArguments
            self.windowWidth = windowWidth
            self.windowHeight = windowHeight
            self.fullscreen = fullscreen
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.jvmHeapSize = try container.decode(UInt64.self, forKey: .jvmHeapSize)
            self.javaURL = try container.decodeIfPresent(URL.self, forKey: .javaURL)
            self.jvmArguments = try container.decodeIfPresent([String].self, forKey: .jvmArguments) ?? []
            // 旧版本配置文件没有以下字段：缺省表示跟随游戏内设置
            self.windowWidth = try container.decodeIfPresent(Int.self, forKey: .windowWidth)
            self.windowHeight = try container.decodeIfPresent(Int.self, forKey: .windowHeight)
            self.fullscreen = try container.decodeIfPresent(Bool.self, forKey: .fullscreen) ?? false
        }

        /// 自定义分辨率；宽高任一缺失或非法时为 nil。
        public var customResolution: (width: Int, height: Int)? {
            guard let windowWidth, let windowHeight,
                  windowWidth >= 320, windowHeight >= 240,
                  windowWidth <= 7680, windowHeight <= 4320 else {
                return nil
            }
            return (windowWidth, windowHeight)
        }
    }
}

public extension JavaSearcher {
    /// 该实例可用的 Java 版本上界。
    /// Mojang 官方清单只给出最低版本，但高版本 Java 会以 `UnsupportedClassVersionError`
    /// 或反射/模块系统变更让老版本游戏直接崩溃，因此需要上界约束。
    static func maximumJavaVersion(for version: MinecraftVersion) -> Int? {
        // 1.16.5 及更早：Java 17 会因模块访问限制与老版 ASM 崩溃，上界取 16
        if version <= .init("1.16.5") { return 16 }
        // 1.17 开始官方要求 Java 16+，1.18 起要求 17+；20.x 起兼容 21
        if version <= .init("1.20.4") { return 21 }
        return nil
    }

    static func pick(for instance: MinecraftInstance) -> JavaRuntime? {
        let systemArch: Architecture = .systemArchitecture()
        let instanceNeedsX64 = instance.version < .init("1.7.2")
        let minimumVersion: Int = instance.manifest.javaVersion.majorVersion
        let maximumVersion: Int? = maximumJavaVersion(for: instance.version)

        func score(of javaRuntime: JavaRuntime) -> Int {
            var score = 0
            if javaRuntime.architecture == (instanceNeedsX64 ? .x64 : systemArch) { score += 3 }
            if javaRuntime.majorVersion == minimumVersion { score += 2 }
            // 超出上界的 Java 虽然能装，但大概率无法启动：显著降权
            if let maximumVersion, javaRuntime.majorVersion > maximumVersion { score -= 10 }
            if javaRuntime.type == .jdk { score += 1 }
            return score
        }

        let javaRuntimes = JavaManager.shared.javaRuntimes.lazy
            .filter { $0.majorVersion >= minimumVersion && !(systemArch == .x64 && $0.architecture == .arm64) }
            .filter { !(instanceNeedsX64 && $0.architecture != .x64)  }

        return javaRuntimes.max(by: { score(of: $0) < score(of: $1) })
    }
}
