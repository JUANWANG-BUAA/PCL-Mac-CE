import Foundation
import Testing
@testable import PCLMacCE

struct UpdateModelTests {
    private let hash = String(repeating: "a", count: 64)

    private func release(tag: String, digest: String?, prerelease: Bool = false) throws -> UpdateModel {
        let digestField = digest.map { ", \"digest\": \"\($0)\"" } ?? ""
        let json = """
        {
          "tag_name": "\(tag)", "name": "\(tag)", "body": "Changes",
          "html_url": "https://github.com/JUANWANG-BUAA/PCL-Mac-CE/releases/tag/\(tag)",
          "draft": false, "prerelease": \(prerelease),
          "assets": [{"name": "PCLMacCE-\(tag).zip", "size": 1024,
            "browser_download_url": "https://github.com/JUANWANG-BUAA/PCL-Mac-CE/releases/download/\(tag)/PCLMacCE-\(tag).zip"\(digestField)}]
        }
        """
        return try JSONDecoder().decode(UpdateModel.self, from: Data(json.utf8))
    }

    @Test func acceptsOnlyNewerStableVersionWithDigest() throws {
        #expect(try release(tag: "v1.2.1", digest: "sha256:\(hash)")
            .installableVersion(currentVersion: "1.2.0")?.sha256 == hash)
        #expect(try release(tag: "v1.2.0", digest: "sha256:\(hash)")
            .installableVersion(currentVersion: "1.2.0") == nil)
        #expect(try release(tag: "v1.1.9", digest: "sha256:\(hash)")
            .installableVersion(currentVersion: "1.2.0") == nil)
        #expect(try release(tag: "v1.2.1", digest: "sha256:\(hash)", prerelease: true)
            .installableVersion(currentVersion: "1.2.0") == nil)
        #expect(try release(tag: "v1.2.1", digest: nil)
            .installableVersion(currentVersion: "1.2.0") == nil)
    }
}
