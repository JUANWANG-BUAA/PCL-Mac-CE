//
//  Architecture.swift
//  PCL.Mac
//

import Foundation

public enum Architecture: String, CustomStringConvertible {
    case arm64, x64, fatFile, unknown

    public init(rawValue: String) {
        switch rawValue {
        case "arm64", "aarch64": self = .arm64
        case "x64", "x86_64": self = .x64
        default: self = .unknown
        }
    }

    public var description: String {
        switch self {
        case .arm64: "ARM64"
        case .x64: "x86_64"
        case .fatFile: "Universal"
        case .unknown: "Unknown"
        }
    }

    /// 获取文件的架构。
    /// - Parameter url: 文件的 `URL`。
    /// - Returns: 文件的架构。如果不是可执行文件或无法识别，返回 `.unknown`。
    public static func architecture(of url: URL) -> Architecture {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? handle.close() }

        // 先读 magic 判断是否为 fat（Universal）二进制，注意此处按主机序比较（历史实现如此）
        guard let magic = readUInt32(from: handle) else { return .unknown }
        if fatMagicNumbers.contains(magic) {
            return architectureFromFat(handle)
        }
        // thin 二进制的 cputype 是 magic 紧随其后的 4 字节——magic 本身不是 cputype。
        // （曾误把 magic 直接传入 forCPUType，导致所有 thin 二进制被判为 unknown：
        //   本机 Homebrew / Mojang / Corretto 的 arm64 JDK 全部无法被识别。）
        guard let cputype = readUInt32(from: handle) else { return .unknown }
        return architecture(forCPUType: cputype)
    }

    /// 解析 fat（Universal）二进制：依次读取各架构描述，判断包含的架构。
    private static func architectureFromFat(_ handle: FileHandle) -> Architecture {
        guard let rawCount = readUInt32(from: handle) else { return .unknown }
        let archCount = rawCount.bigEndian

        var foundX64 = false
        var foundArm64 = false
        for _ in 0..<archCount {
            // 每个 fat_arch 结构固定 20 字节，前 4 字节为 cputype（大端）
            guard let archData = try? handle.read(upToCount: 20), archData.count == 20 else { return .unknown }
            let cputype = archData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            switch cputype {
            case cpuTypeX64: foundX64 = true
            case cpuTypeArm64: foundArm64 = true
            default: break
            }
        }

        switch (foundX64, foundArm64) {
        case (true, true): return .fatFile
        case (_, true): return .arm64
        case (true, _): return .x64
        default: return .unknown
        }
    }

    /// 将单个 cputype 映射为架构。
    private static func architecture(forCPUType cputype: UInt32) -> Architecture {
        switch cputype {
        case cpuTypeArm64: return .arm64
        case cpuTypeX64: return .x64
        default: return .unknown
        }
    }

    /// 从文件句柄读取 4 字节整数（主机序）。
    private static func readUInt32(from handle: FileHandle) -> UInt32? {
        guard let data = try? handle.read(upToCount: 4), data.count == 4 else { return nil }
        return data.withUnsafeBytes { $0.load(as: UInt32.self) }
    }

    /// fat 二进制的 magic 数字（大小端写法均视为 fat）。
    private static let fatMagicNumbers: Set<UInt32> = [0xBEBAFECA, 0xBFBAFECA, 0xCAFEBABE, 0xCAFEBABF]
    /// CPU_TYPE_X86_64
    private static let cpuTypeX64: UInt32 = 0x1000007
    /// CPU_TYPE_ARM64
    private static let cpuTypeArm64: UInt32 = 0x100000C

    public static func systemArchitecture() -> Architecture {
        #if arch(arm64)
        return .arm64
        #elseif arch(x86_64)
        return .x64
        #endif
    }
}
