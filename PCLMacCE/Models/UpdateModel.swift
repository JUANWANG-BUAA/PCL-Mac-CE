//
//  UpdateModel.swift
//  PCLMacCE
//

import Foundation

/// Published GitHub Release. The ZIP must have a SHA-256 digest.
struct UpdateModel: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL
        let size: Int
        let digest: String?

        enum CodingKeys: String, CodingKey {
            case name, size, digest
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case name, body, draft, prerelease, assets
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }

    struct Version {
        let tagName: String
        let name: String
        let summary: String
        let releaseURL: URL
        let downloadURL: URL
        let size: Int
        let sha256: String
    }

    func installableVersion(currentVersion: String) -> Version? {
        guard !draft, !prerelease,
              let remote = Self.parseVersion(tagName),
              let current = Self.parseVersion(currentVersion),
              Self.isNewer(remote, than: current),
              let asset = assets.first(where: { $0.name == "PCLMacCE-\(tagName).zip" }),
              asset.size > 0,
              let digest = asset.digest,
              digest.hasPrefix("sha256:") else { return nil }
        let hash = String(digest.dropFirst("sha256:".count))
        guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }),
              asset.browserDownloadURL.scheme == "https",
              asset.browserDownloadURL.host == "github.com" else { return nil }
        return Version(tagName: tagName, name: name ?? tagName,
                       summary: String((body ?? "").prefix(500)),
                       releaseURL: htmlURL,
                       downloadURL: asset.browserDownloadURL,
                       size: asset.size,
                       sha256: hash)
    }

    private static func parseVersion(_ text: String) -> [Int]? {
        let parts = (text.hasPrefix("v") ? String(text.dropFirst()) : text).split(separator: ".")
        guard parts.count == 3 else { return nil }
        let numbers = parts.compactMap { Int($0) }
        return numbers.count == 3 ? numbers : nil
    }

    private static func isNewer(_ remote: [Int], than current: [Int]) -> Bool {
        for (new, old) in zip(remote, current) where new != old {
            return new > old
        }
        return false
    }
}
