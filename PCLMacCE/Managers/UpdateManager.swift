import Foundation
import AppKit
import Core
import ZIPFoundation

class UpdateManager {
    static let shared = UpdateManager()
    static let releaseURL = URL(string: "https://github.com/JUANWANG-BUAA/PCL-Mac-CE/releases")!
    private static let latestURL = URL(string: "https://api.github.com/repos/JUANWANG-BUAA/PCL-Mac-CE/releases/latest")!

    /// 已下载并通过校验的更新包；应用（替换并重启）与准备（下载校验）分离，
    /// 以便自动更新在用户确认重启时机后再执行替换。
    struct PreparedUpdate {
        let version: UpdateModel.Version
        let newBundleURL: URL
        let extractionDirectory: URL

        /// 用新版本替换当前应用并重启启动器。
        func apply() async throws {
            defer { discard() }
            _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: newBundleURL,
                                                       backupItemName: "PCLMacCE.app.backup",
                                                       options: [.usingNewMetadataOnly])
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-n", Bundle.main.bundleURL.path]
            try process.run()
            await NSApplication.shared.terminate(nil)
        }

        /// 放弃本次已准备的更新（用户选择稍后重启时清理临时文件）。
        func discard() {
            try? FileManager.default.removeItem(at: extractionDirectory)
        }
    }

    func checkUpdates() async throws -> UpdateModel.Version? {
        if Metadata.debugMode || Metadata.bundleVersion == 0 { return nil }
        let response = try await HTTPClient.shared.get(Self.latestURL,
                                                        headers: ["Accept": "application/vnd.github+json"],
                                                        revalidate: true)
        if response.statusCode == 404 { return nil }
        guard response.statusCode == 200 else {
            throw SimpleError("GitHub 更新检查失败（HTTP \(response.statusCode)）。")
        }
        return try response.decode(UpdateModel.self).installableVersion(currentVersion: Metadata.appVersion)
    }

    /// 下载更新包并完成全部校验（sha256、Bundle 身份、签名团队），不替换应用。
    func prepareUpdate(_ version: UpdateModel.Version, progressHandler: (@MainActor (Double) -> Void)? = nil) async throws -> PreparedUpdate {
        let destination = URLConstants.tempURL.appending(path: "launcher-update-\(UUID().uuidString).zip")
        let extraction = URLConstants.tempURL.appending(path: "launcher-update-\(UUID().uuidString)")
        do {
            let download = DownloadItem(url: version.downloadURL, destination: destination,
                                        checksums: ["sha256": version.sha256])
            try await FileDownloader.shared.download(download, preferMirror: false, progressHandler: progressHandler)
            try FileManager.default.createDirectory(at: extraction, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: destination, to: extraction)
            let newBundle = extraction.appending(path: "PCLMacCE.app")
            guard FileManager.default.fileExists(atPath: newBundle.path),
                  Bundle(url: newBundle)?.bundleIdentifier == Bundle.main.bundleIdentifier,
                  Bundle(url: newBundle)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                      == String(version.tagName.dropFirst()) else {
                throw SimpleError("更新包应用身份不匹配，请从项目 Release 页面手动安装。")
            }
            try verifySignature(of: newBundle)
            return .init(version: version, newBundleURL: newBundle, extractionDirectory: extraction)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.removeItem(at: extraction)
            throw error
        }
    }

    /// 一步完成下载、校验、替换并重启（交互式手动更新使用）。
    func installUpdate(_ version: UpdateModel.Version) async throws {
        let prepared: PreparedUpdate = try await prepareUpdate(version)
        try await prepared.apply()
    }

    private func verifySignature(of bundle: URL) throws {
        guard let currentTeam = try signingTeam(of: Bundle.main.bundleURL),
              let updateTeam = try signingTeam(of: bundle),
              currentTeam == updateTeam else {
            throw SimpleError("更新包签名团队与当前应用不一致，请从项目 Release 页面手动安装。")
        }
    }

    private func signingTeam(of bundle: URL) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", "--verbose=2", bundle.path]
        let output = Pipe()
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw SimpleError("更新包签名验证失败，请从项目 Release 页面手动安装。")
        }
        let info = Process()
        info.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        info.arguments = ["--display", "--verbose=4", bundle.path]
        let infoOutput = Pipe()
        info.standardError = infoOutput
        try info.run()
        info.waitUntilExit()
        guard info.terminationStatus == 0 else { return nil }
        let data = infoOutput.fileHandleForReading.readDataToEndOfFile()
        guard let details = String(data: data, encoding: .utf8) else { return nil }
        return details.split(separator: "\n").first(where: { $0.hasPrefix("TeamIdentifier=") })
            .map { String($0.dropFirst("TeamIdentifier=".count)) }
    }
}
