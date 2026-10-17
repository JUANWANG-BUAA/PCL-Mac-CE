//
//  FileVerificationCache.swift
//  PCLMacCE
//

import Foundation

struct FileFingerprint: Equatable, Sendable {
    let size: Int64
    let modificationTime: Double
    let deviceNumber: Int64?
    let fileNumber: Int64?
}

/// 文件完整性校验结果缓存。
///
/// 记录「上一次哈希校验通过时的文件大小与修改时间」；命中（size 与 mtime 均未变）时
/// 跳过整文件哈希。这把启动前的资源补全从全量读盘哈希降为一次 stat 扫描——
/// 数百 MB 的 libraries/assets 在每次启动时都会被重新校验，是启动慢的主要来源之一。
///
/// 折中：无法检测不改变文件元数据的损坏（如位翻转）；文件发生任何写入都会改变
/// mtime，重新触发完整校验。加载时自动清理已不存在的条目。
public final class FileVerificationCache: @unchecked Sendable {
    private struct Entry: Codable {
        let size: Int64
        let mtime: Double
        let deviceNumber: Int64?
        let fileNumber: Int64?
        let checksums: [String: String]?
    }

    private let lock: NSLock = .init()
    private let fileURL: URL
    private var entries: [String: Entry] = [:]
    private var isLoaded: Bool = false
    private var dirty: Bool = false

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// 从磁盘加载缓存；文件不存在时静默跳过。线程安全，可多次调用。
    public func load() {
        lock.lock()
        defer { lock.unlock() }
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.shared.decode([String: Entry].self, from: data) else {
            return
        }
        // 清理已不存在的文件对应的条目，避免长期增长
        let fileManager = FileManager.default
        entries = decoded.filter { fileManager.fileExists(atPath: $0.key) }
        if decoded.count != entries.count {
            dirty = true
        }
    }

    /// 该路径的当前状态是否与上次校验通过时一致；文件不存在返回 `false`。
    public func isVerified(_ url: URL, checksums: [String: String]) -> Bool {
        let path: String = url.standardizedFileURL.path
        guard let fingerprint = fingerprint(for: url) else {
            return false
        }
        let expectedChecksums: [String: String] = Self.normalized(checksums)
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[path] else { return false }
        return entry.size == fingerprint.size
            && entry.mtime == fingerprint.modificationTime
            && entry.deviceNumber == fingerprint.deviceNumber
            && entry.fileNumber == fingerprint.fileNumber
            && entry.checksums == expectedChecksums
    }

    func fingerprint(for url: URL) -> FileFingerprint? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64,
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return .init(
            size: size,
            modificationTime: modificationDate.timeIntervalSince1970,
            deviceNumber: (attributes[.systemNumber] as? NSNumber)?.int64Value,
            fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.int64Value
        )
    }

    /// 记录当前文件状态，供已完成外部校验的调用方使用。
    public func markVerified(_ url: URL, checksums: [String: String]) {
        guard let fingerprint = fingerprint(for: url) else { return }
        markVerified(url, checksums: checksums, ifUnchangedSince: fingerprint)
    }

    /// 仅当哈希前后文件身份与元数据一致时，记录一次校验通过。
    func markVerified(_ url: URL, checksums: [String: String], ifUnchangedSince fingerprint: FileFingerprint) {
        let path: String = url.standardizedFileURL.path
        guard self.fingerprint(for: url) == fingerprint else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        entries[path] = .init(
            size: fingerprint.size,
            mtime: fingerprint.modificationTime,
            deviceNumber: fingerprint.deviceNumber,
            fileNumber: fingerprint.fileNumber,
            checksums: Self.normalized(checksums)
        )
        dirty = true
    }

    /// 移除一条记录（校验失败或文件被删除后调用）。
    public func remove(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        if entries.removeValue(forKey: url.standardizedFileURL.path) != nil {
            dirty = true
        }
    }

    /// 原子写回磁盘；内容无变化时不产生 IO。
    public func flush() {
        lock.lock()
        defer { lock.unlock() }
        guard dirty else { return }
        do {
            let data: Data = try JSONEncoder.shared.encode(entries)
            try data.write(to: fileURL, options: .atomic)
            dirty = false
        } catch {
            err("写入文件校验缓存失败：\(error.localizedDescription)")
        }
    }

    private static func normalized(_ checksums: [String: String]) -> [String: String] {
        checksums.reduce(into: [:]) { result, entry in
            result[entry.key.lowercased()] = entry.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
}
