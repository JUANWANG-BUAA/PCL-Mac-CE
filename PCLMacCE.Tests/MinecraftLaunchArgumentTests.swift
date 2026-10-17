//
//  MinecraftLaunchArgumentTests.swift
//  PCLMacCE
//

import Foundation
import Testing
@testable import Core

struct MinecraftLaunchArgumentTests {
    @Test func resolvesOptionalClientIdentityPlaceholders() throws {
        var options: LaunchOptions = .init()
        options.profile = .init(name: "Steve", id: UUID(), properties: [])
        options.accessToken = "test-token"
        options.runningDirectory = URL(fileURLWithPath: "/tmp/pcl-launch-arguments")
        options.manifest = try JSONDecoder.shared.decode(ClientManifest.self, from: Data("{}".utf8))
        options.repository = .init(name: "Test", url: URL(fileURLWithPath: "/tmp/pcl-launch-arguments"))

        let launcher: MinecraftLauncher = .init(options: options)
        let resolved: [String] = launcher.resolveArguments([
            "--clientId", "${clientid}", "--xuid", "${auth_xuid}"
        ])

        #expect(resolved == ["--clientId", "", "--xuid", ""])
        #expect(resolved.allSatisfy { !$0.contains("${") })
    }
}
