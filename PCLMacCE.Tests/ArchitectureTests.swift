//
//  ArchitectureTests.swift
//  PCLMacCE
//
//  Created by JUANWANG on 2026/10/14.
//

import Testing
import Foundation
import Core

/// `Architecture.architecture(of:)` 的回归测试。
///
/// 背景：ADR-007 重构曾把 thin 二进制的 magic 当作 cputype 传入比较，
/// 导致所有 thin（非 Universal）二进制被判定为 `.unknown`——本机三个 arm64 JDK
/// 全部无法被 Java 搜索识别，启动直接失败。这里用合成的最小 Mach-O 头
/// 锁定两种文件形态的解析语义（不依赖本机装了什么，可在任何机器上跑）。
struct ArchitectureTests {
    // MARK: - 合成 Mach-O 头

    /// 64 位 little-endian 的 thin magic（0xFEEDFACF 的磁盘字节序）。
    private static let thinMagicLE: [UInt8] = [0xCE, 0xFA, 0xED, 0xFE]
    /// fat（Universal）magic（FAT_MAGIC，大端）。
    private static let fatMagicBE: [UInt8] = [0xCA, 0xFE, 0xBA, 0xBE]

    /// cputype 的小端字节序（thin 文件）。
    private static func cpuTypeLE(_ cputype: UInt32) -> [UInt8] {
        withUnsafeBytes(of: cputype.littleEndian) { Array($0) }
    }

    /// 一个 fat_arch 结构（20 字节，全部大端）：cputype + cpusubtype + offset + size + align。
    private static func fatArch(cpuType: UInt32) -> [UInt8] {
        let zero: [UInt8] = [0, 0, 0, 0]
        return withUnsafeBytes(of: cpuType.bigEndian) { Array($0) }
            + zero + zero + zero + zero
    }

    private static let cpuTypeArm64: UInt32 = 0x0100000C
    private static let cpuTypeX64: UInt32 = 0x01000007

    /// 把字节写入临时文件并返回 URL。
    private func writeTemporary(_ bytes: [UInt8]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "architecture-test-\(UUID().uuidString)")
        try Data(bytes).write(to: url)
        return url
    }

    // MARK: - thin 二进制（本次回归的核心）

    @Test func thinArm64() throws {
        let url = try writeTemporary(Self.thinMagicLE + Self.cpuTypeLE(Self.cpuTypeArm64))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(Architecture.architecture(of: url) == .arm64)
    }

    @Test func thinX64() throws {
        let url = try writeTemporary(Self.thinMagicLE + Self.cpuTypeLE(Self.cpuTypeX64))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(Architecture.architecture(of: url) == .x64)
    }

    // MARK: - fat（Universal）二进制

    @Test func fatUniversal() throws {
        let bytes = Self.fatMagicBE
            + [0, 0, 0, 2]                                          // nfat_arch = 2（大端）
            + Self.fatArch(cpuType: Self.cpuTypeArm64)
            + Self.fatArch(cpuType: Self.cpuTypeX64)
        let url = try writeTemporary(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(Architecture.architecture(of: url) == .fatFile)
    }

    @Test func fatArm64Only() throws {
        let bytes = Self.fatMagicBE
            + [0, 0, 0, 1]
            + Self.fatArch(cpuType: Self.cpuTypeArm64)
        let url = try writeTemporary(bytes)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(Architecture.architecture(of: url) == .arm64)
    }

    // MARK: - 边界

    @Test func notExecutableIsUnknown() throws {
        let url = try writeTemporary(Array("hello world".utf8))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(Architecture.architecture(of: url) == .unknown)
    }

    @Test func missingFileIsUnknown() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "architecture-test-missing-\(UUID().uuidString)")
        #expect(Architecture.architecture(of: url) == .unknown)
    }

    /// 真实系统二进制冒烟测试：`/bin/ls` 在 macOS 11+ 均为 Universal。
    @Test func realSystemBinaryIsFat() {
        #expect(Architecture.architecture(of: URL(fileURLWithPath: "/bin/ls")) == .fatFile)
    }
}
