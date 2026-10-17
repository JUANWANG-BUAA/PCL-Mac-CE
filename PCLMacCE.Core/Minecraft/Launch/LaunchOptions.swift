//
//  LaunchOptions.swift
//  PCLMacCE
//

import Foundation

public struct LaunchOptions {
    public var profile: PlayerProfile!
    public var accessToken: String!
    public var javaRuntime: JavaRuntime!
    public var runningDirectory: URL!
    public var manifest: ClientManifest!
    public var repository: MinecraftRepository!
    public var memory: UInt64 = 4096
    public var mainClass: String!
    public var extraJvmArguments: [String] = []
    public var demo: Bool = false
    /// 自定义窗口分辨率；宽高任一为 `nil` 时不指定，使用游戏内设置。
    public var windowWidth: Int?
    public var windowHeight: Int?
    /// 启动时是否强制全屏（写入实例 options.txt）。
    public var fullscreen: Bool = false

    // Authlib Injector
    public var authlibInjectorPath: String?
    public var authServerURL: URL?
    public var prefetchedMeta: String?

    public func validate() throws {
        if profile == nil || accessToken == nil { throw LaunchError.missingAccount }
        if javaRuntime == nil { throw LaunchError.missingJava }
        if runningDirectory == nil { throw LaunchError.missingRunningDirectory }
        if manifest == nil { throw LaunchError.missingManifest }
        if repository == nil { throw LaunchError.missingRepository }
        if mainClass == nil { throw LaunchError.missingMainClass}
    }

    public init() {}
}
