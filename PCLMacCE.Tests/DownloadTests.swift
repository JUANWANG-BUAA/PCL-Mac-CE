//
//  DownloadTests.swift
//  PCLMacCE
//

import Testing
import Foundation
import Core
import SwiftyJSON
import CryptoKit

struct DownloadTests {
    @Test func singleFileDownloadTest() async throws {
        let item: DownloadItem = .init(
            url: URL(string: "https://piston-meta.mojang.com/v1/packages/b8ac7ed26100bd79830df1de207fbeefe7fab62f/1.21.10.json")!,
            destination: URLConstants.tempURL.appending(path: "singleFileDownloadTest"),
            sha1: "b8ac7ed26100bd79830df1de207fbeefe7fab62f"
        )

        try await FileDownloader.shared.download(item)

        // 校验缓存按 size+mtime 判定“文件未变更即已验证”。这里改动 mtime 模拟
        // 文件被外部修改，覆盖“缓存失效后重新哈希并发现校验和不匹配”的路径
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(1)],
            ofItemAtPath: item.destination.path
        )
        await #expect(throws: DownloadError.checksumMismatch) {
            try await FileDownloader.shared.download(
                .init(
                    url: item.url,
                    destination: item.destination,
                    sha1: "da39a3ee5e6b4b0d3255bfef95601890afd80709"
                )
            )
        }

        await #expect(throws: DownloadError.badStatusCode(code: 404)) {
            try await FileDownloader.shared.download(
                .init(
                    url: URL(string: "https://bmclapi2.bangbang93.com/version/11.45.14/json")!,
                    destination: item.destination,
                    sha1: nil
                )
            )
        }
    }

    @Test func multiFileDownloadTest() async throws {
        if ProcessInfo.processInfo.environment["GITHUB_ENV"] != nil {
            print("当前环境为 GitHub Actions，跳过多文件下载测试")
            return
        }
        let data: Data = try await URLSession.shared.data(from: URL(string: "https://piston-meta.mojang.com/v1/packages/48fc0ab195b88bc562d672cdcf7997de42fe9d51/27.json").unwrap()).0
        let assetIndex: AssetIndex = try JSONDecoder.shared.decode(AssetIndex.self, from: data)
        let tempDirectory: URL = URLConstants.tempURL.appending(path: "multiFileDownloadTest")
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: false)
        let root: URL = try URL(string: "https://resources.download.minecraft.net").unwrap()
        let items: [DownloadItem] = assetIndex.objects.map { .init(
            url: root.appending(path: "\($0.hash.prefix(2))/\($0.hash)"), destination: tempDirectory.appending(path: $0.hash), sha1: $0.hash)
        }
        try await FileDownloader.shared.download(files: Array(items.prefix(128))) { print($0 * 100) }
        try FileManager.default.removeItem(at: tempDirectory)
    }

    @Test func mirrorURLTest() {
        let bmclapiRoot = URL(string: "https://bmclapi2.bangbang93.com/")!
        let bmclapiMavenRoot = bmclapiRoot.appending(path: "maven")

        let mojangMetaRoot = URL(string: "https://piston-meta.mojang.com/")!
        let mojangDataRoot = URL(string: "https://piston-data.mojang.com/")!

        let forgeMavenRoot = URL(string: "https://files.minecraftforge.net/maven")!

        let manifestPath = "v1/packages/3457237902814cca3f5c6f20b0c5db1b1f341512/26.2.json"
        #expect(MirrorDownloadSource.shared.candidate(for: mojangMetaRoot.appending(path: manifestPath))?.url
                == bmclapiRoot.appending(path: manifestPath))

        let jarPath = "v1/objects/2dc72797acbc1b63fc16a11c4ac393605f453754/client.jar"
        #expect(MirrorDownloadSource.shared.candidate(for: mojangDataRoot.appending(path: jarPath))?.url
                == bmclapiRoot.appending(path: jarPath))

        let installerPath = "net/minecraftforge/forge/1.20.1-47.4.22/forge-1.20.1-47.4.22-installer.jar"
        #expect(MirrorDownloadSource.shared.candidate(for: forgeMavenRoot.appending(path: installerPath))?.url
                == bmclapiMavenRoot.appending(path: installerPath))

        #expect(MirrorDownloadSource.shared.candidate(for: URL(string: "https://libraries.minecraft.net/")!)?.url == bmclapiMavenRoot)
    }

    @Test func resumesFromPersistedPartAfterInterruptedResponse() async throws {
        let directory: URL = FileManager.default.temporaryDirectory
            .appending(path: "download-resume-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let expected: Data = Data("abcdefghij".utf8)
        InterruptingDownloadURLProtocol.reset()
        let sourceFile: URL = directory.appending(path: "expected.bin")
        try expected.write(to: sourceFile)
        let destination: URL = directory.appending(path: "downloaded.bin")
        let url: URL = try #require(URL(string: "https://example.test/downloaded.bin"))
        let partURL: URL = destination.appendingPathExtension("download")
        try Data("abcd".utf8).write(to: partURL)
        let markerURL: URL = partURL.appendingPathExtension("source")
        let marker: ResumeMetadataFixture = .init(source: url.absoluteString, entityTag: "\"v1\"", lastModified: nil)
        try JSONEncoder().encode(marker).write(to: markerURL)

        let (downloader, session) = makeProtocolDownloader()
        defer { session.invalidateAndCancel() }

        let item: DownloadItem = .init(
            url: url,
            destination: destination,
            sha1: try FileUtils.sha1(of: sourceFile)
        )
        try await downloader.download(item)

        #expect(try Data(contentsOf: destination) == expected)
        #expect(InterruptingDownloadURLProtocol.receivedRanges == ["bytes=4-", "bytes=9-"])
        #expect(InterruptingDownloadURLProtocol.receivedIfRanges == ["\"v1\"", "\"v1\""])
    }

    private func makeProtocolDownloader() -> (FileDownloader, URLSession) {
        let configuration: URLSessionConfiguration = .ephemeral
        configuration.protocolClasses = [InterruptingDownloadURLProtocol.self]
        let delegateQueue: OperationQueue = .init()
        delegateQueue.maxConcurrentOperationCount = 1
        let delegate: DownloadDelegate = .init(delegateQueue: delegateQueue)
        let session: URLSession = .init(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: delegateQueue
        )
        let downloader: FileDownloader = .init(
            session: session,
            sourceManager: .init(policy: .officialFirst, curseforgeApiKey: nil),
            delegate: delegate
        )
        return (downloader, session)
    }
}

// Swift requires these URLProtocol overrides to be class methods.
// swiftlint:disable static_over_final_class
private final class InterruptingDownloadURLProtocol: URLProtocol {
    private static let lock: NSLock = .init()
    private static var requestRanges: [String?] = []
    private static var ifRanges: [String?] = []
    private static var responseCount: Int = 0

    static func reset() {
        lock.lock()
        requestRanges = []
        ifRanges = []
        responseCount = 0
        lock.unlock()
    }

    static var receivedRanges: [String?] {
        lock.lock()
        defer { lock.unlock() }
        return requestRanges
    }

    static var receivedIfRanges: [String?] {
        lock.lock()
        defer { lock.unlock() }
        return ifRanges
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "example.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let range: String? = request.value(forHTTPHeaderField: "Range")
        let start: Int = range?.replacingOccurrences(of: "bytes=", with: "")
            .split(separator: "-").first.flatMap { Int($0) } ?? 0
        Self.lock.lock()
        Self.requestRanges.append(range)
        Self.ifRanges.append(request.value(forHTTPHeaderField: "If-Range"))
        Self.responseCount += 1
        let responseIndex: Int = Self.responseCount
        Self.lock.unlock()

        let body: Data = responseIndex == 1 ? Data("efghi".utf8) : Data("j".utf8)
        let end: Int = responseIndex == 1 ? 8 : 9
        let statusCode: Int = 206
        let headers: [String: String] = [
            "Content-Length": String(body.count),
            "Content-Range": "bytes \(start)-\(end)/10",
            "ETag": "\"v1\""
        ]
        guard let responseURL = request.url,
              let response = HTTPURLResponse(
            url: responseURL,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}

private struct ResumeMetadataFixture: Codable {
    let source: String
    let entityTag: String?
    let lastModified: String?
}
// swiftlint:enable static_over_final_class
