//
//  LaunchPrecheck.swift
//  PCLMacCE
//

import Foundation

public enum LaunchPrecheck {
    public static func check(
        for instance: MinecraftInstance,
        with options: LaunchOptions,
        hasMicrosoftAccount: Bool
    ) -> [Entry] {
        var entries: [Entry] = []
        entries += checkJava(instance: instance, currentJava: options.javaRuntime)
        entries += checkAccount(options.profile, hasMicrosoftAccount: hasMicrosoftAccount)
        return entries
    }

    private static func checkJava(instance: MinecraftInstance, currentJava: JavaRuntime) -> [Entry] {
        var entries: [Entry] = []
        let minVersion: Int = instance.manifest.javaVersion.majorVersion
        let actualVersion: Int = currentJava.majorVersion
        if actualVersion < minVersion {
            log("当前 Java 版本（\(actualVersion)）低于最低 Java 版本（\(minVersion)）")
            entries.append(.javaVersionTooLow(min: minVersion))
        }
        if let maxVersion = JavaSearcher.maximumJavaVersion(for: instance.version), actualVersion > maxVersion {
            log("当前 Java 版本（\(actualVersion)）高于该实例的兼容上限（\(maxVersion)）")
            entries.append(.javaVersionTooHigh(max: maxVersion))
        }
        return entries
    }

    private static func checkAccount(_ profile: PlayerProfile, hasMicrosoftAccount: Bool) -> [Entry] {
        var entries: [Entry] = []
        if !hasMicrosoftAccount {
            entries.append(.noMicrosoftAccount)
        }
        return entries
    }

    public enum Entry {
        case javaVersionTooLow(min: Int)
        /// Java 版本高于该游戏版本的常见兼容上界，可能以 UnsupportedClassVersionError 等方式崩溃。
        case javaVersionTooHigh(max: Int)
        case noMicrosoftAccount
    }
}
