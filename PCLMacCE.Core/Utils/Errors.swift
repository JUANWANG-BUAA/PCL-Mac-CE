//
//  Errors.swift
//  PCLMacCE
//

import Foundation

public enum DownloadError: LocalizedError, Equatable {
    case fileExists
    case checksumMismatch
    case badStatusCode(code: Int)
    case invalidContentRange
    case resumeRejected
    case destinationConflict
    case unknownError

    public var errorDescription: String? {
        switch self {
        case .fileExists:
            "目标文件已存在。"
        case .checksumMismatch:
            "文件校验未通过。"
        case .badStatusCode(let code):
            "错误的响应码：\(code)。"
        case .invalidContentRange:
            "服务器返回了无效的分段响应。"
        case .resumeRejected:
            "服务器拒绝续传，正在从头重试。"
        case .destinationConflict:
            "多个下载项指向同一目标文件，但校验信息不一致。"
        case .unknownError:
            "发生未知错误。"
        }
    }
}

public enum LaunchError: Error {
    case missingJava
    case missingRunningDirectory
    case missingManifest
    case missingAccount
    case missingRepository
    case missingMainClass
}

public enum TaskError: Error, Equatable {
    case invalidOrdinal(value: Int)
    case unknownError
}

public enum UUIDError: Error, Equatable {
    case invalidUUIDFormat
}

public enum JavaError: LocalizedError {
    case invalidURL
    case failedToParseReleaseFile
    case missingExecutableFile
    case failedToParseVersionNumber(version: String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "无效的 Java URL。"
        case .failedToParseReleaseFile:
            "解析 release 文件失败。"
        case .missingExecutableFile:
            "未找到可执行文件。"
        case .failedToParseVersionNumber(let version):
            "解析版本号 \(version) 失败。"
        }
    }
}

public struct SimpleError: LocalizedError {
    private let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    public var errorDescription: String? { reason }
}
