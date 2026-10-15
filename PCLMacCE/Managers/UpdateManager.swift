import Foundation
import AppKit
import Core
import ZIPFoundation

class UpdateManager {
    static let shared = UpdateManager()
    static let releaseURL = URL(string: "https://github.com/JUANWANG-BUAA/PCL-Mac-CE/releases")!
    private static let latestURL = URL(string: "https://api.github.com/repos/JUANWANG-BUAA/PCL-Mac-CE/releases/latest")!

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

    func installUpdate(_ version: UpdateModel.Version) async throws {
        let destination = URLConstants.tempURL.appending(path: "launcher-update-\(UUID().uuidString).zip")
        let extraction = URLConstants.tempURL.appending(path: "launcher-update-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.removeItem(at: extraction)
        }
        let download = DownloadItem(url: version.downloadURL, destination: destination,
                                    checksums: ["sha256": version.sha256])
        try await FileDownloader.shared.download(download, preferMirror: false)
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
        _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: newBundle,
                                                   backupItemName: "PCLMacCE.app.backup",
                                                   options: [.usingNewMetadataOnly])
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundleURL.path]
        try process.run()
        await NSApplication.shared.terminate(nil)
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
