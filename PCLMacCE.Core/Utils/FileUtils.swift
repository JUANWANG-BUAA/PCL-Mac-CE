//
//  FileUtils.swift
//  PCLMacCE
//

import Foundation
import CryptoKit

public enum FileUtils {
    /// 通用文件哈希获取。
    /// - Parameters:
    ///   - url: 文件的 URL。
    ///   - hashFunction: 零参构造的哈希函数类型 (如 `SHA256.self`)。
    /// - Returns: 哈希结果的 hex 字符串。
    public static func hash<H: HashFunction>(of url: URL, using hashFunction: H.Type) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let handle: FileHandle = try .init(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher: H = .init()
        while try autoreleasepool(invoking: {
            try Task.checkCancellation()
            if let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty {
                hasher.update(data: data)
                return true
            } else {
                return false
            }
        }) { }
        let digest: H.Digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// SHA-1
    public static func sha1(of url: URL) throws -> String {
        try hash(of: url, using: Insecure.SHA1.self)
    }

    /// SHA-256
    public static func sha256(of url: URL) throws -> String {
        try hash(of: url, using: SHA256.self)
    }

    /// SHA-512
    public static func sha512(of url: URL) throws -> String {
        try hash(of: url, using: SHA512.self)
    }

    public static func checkFile(at url: URL, with checksums: [String: String]) throws -> Bool {
        guard !checksums.isEmpty else { return true }

        var expected: [String: String] = [:]
        for (algorithm, value) in checksums {
            let normalizedAlgorithm: String = algorithm.lowercased()
            guard ["md5", "sha1", "sha256", "sha512"].contains(normalizedAlgorithm),
                  expected[normalizedAlgorithm] == nil else {
                return false
            }
            expected[normalizedAlgorithm] = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        let handle: FileHandle = try .init(forReadingFrom: url)
        defer { try? handle.close() }

        var md5Hasher: Insecure.MD5? = expected["md5"] == nil ? nil : .init()
        var sha1Hasher: Insecure.SHA1? = expected["sha1"] == nil ? nil : .init()
        var sha256Hasher: SHA256? = expected["sha256"] == nil ? nil : .init()
        var sha512Hasher: SHA512? = expected["sha512"] == nil ? nil : .init()

        while try autoreleasepool(invoking: {
            try Task.checkCancellation()
            guard let data = try handle.read(upToCount: 1024 * 1024), !data.isEmpty else { return false }
            md5Hasher?.update(data: data)
            sha1Hasher?.update(data: data)
            sha256Hasher?.update(data: data)
            sha512Hasher?.update(data: data)
            return true
        }) { }

        let actual: [String: String] = [
            "md5": md5Hasher.map { hex($0.finalize()) },
            "sha1": sha1Hasher.map { hex($0.finalize()) },
            "sha256": sha256Hasher.map { hex($0.finalize()) },
            "sha512": sha512Hasher.map { hex($0.finalize()) }
        ].compactMapValues { $0 }
        return expected.allSatisfy { actual[$0.key] == $0.value }
    }

    public static func check(_ item: DownloadItem) throws -> Bool {
        guard let checksums = item.checksums else { return true }
        return try checkFile(at: item.destination, with: checksums)
    }

    /// 校验下载项对应的本地文件，命中校验缓存（size+mtime 未变）时跳过整文件哈希。
    /// 校验通过会写入缓存；失败会从缓存移除。
    public static func checkCached(_ item: DownloadItem, using cache: FileVerificationCache) throws -> Bool {
        guard let checksums = item.checksums else { return true }
        guard !checksums.isEmpty else { return true }
        if cache.isVerified(item.destination, checksums: checksums) { return true }
        let fingerprint: FileFingerprint? = cache.fingerprint(for: item.destination)
        let passed: Bool = try checkFile(at: item.destination, with: checksums)
        if passed {
            if let fingerprint {
                cache.markVerified(item.destination, checksums: checksums, ifUnchangedSince: fingerprint)
            }
        } else {
            cache.remove(item.destination)
        }
        return passed
    }

    public static func isExecutable(at url: URL) -> Bool {
        return Architecture.architecture(of: url) != .unknown
    }

    private static func hex<D: Sequence>(_ digest: D) -> String where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
