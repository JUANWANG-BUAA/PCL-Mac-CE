//
//  AccountTokenStore.swift
//  PCLMacCE
//

import Foundation
import Security

/// 账号令牌的安全存储抽象：生产环境使用 macOS Keychain，测试可注入内存实现。
public protocol AccountTokenStore: AnyObject {
    func saveSecret(_ value: String, for key: String) throws
    func readSecret(for key: String) throws -> String?
    func deleteSecret(for key: String) throws
}

/// 基于 macOS Keychain 的账号令牌存储。
/// 访问令牌属于高价值凭据（微软 OAuth refresh token 可接管账号），不能明文写入 config.json。
public final class KeychainTokenStore: AccountTokenStore {
    private let service: String

    public init(service: String = "PCLMacCE.accountTokens") {
        self.service = service
    }

    public func saveSecret(_ value: String, for key: String) throws {
        let data: Data = .init(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // 启动器可能在开机后未解锁时刷新令牌，AfterFirstUnlock 兼顾可用性与安全
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        var status: OSStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw SimpleError("写入 Keychain 失败（状态码 \(status)）。")
        }
    }

    public func readSecret(for key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw SimpleError("读取 Keychain 数据失败：内容不是 UTF-8 字符串。")
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw SimpleError("读取 Keychain 失败（状态码 \(status)）。")
        }
    }

    public func deleteSecret(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status: OSStatus = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SimpleError("删除 Keychain 条目失败（状态码 \(status)）。")
        }
    }
}

/// 测试与预览环境使用的内存令牌存储。
public final class InMemoryTokenStore: AccountTokenStore {
    private var secrets: [String: String] = [:]
    private let lock: NSLock = .init()

    public init() {}

    public func saveSecret(_ value: String, for key: String) {
        lock.lock()
        secrets[key] = value
        lock.unlock()
    }

    public func readSecret(for key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return secrets[key]
    }

    public func deleteSecret(for key: String) {
        lock.lock()
        secrets.removeValue(forKey: key)
        lock.unlock()
    }
}
