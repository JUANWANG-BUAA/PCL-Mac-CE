//
//  LauncherConfigPersistenceTests.swift
//  PCLMacCE.Tests
//

import Foundation
import Testing
@testable import PCLMacCE
import Core

struct LauncherConfigPersistenceTests {
    @Test func saveAndReloadAtIsolatedPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appending(path: "config.json")
        let config = LauncherConfig()
        config.launchCount = 42
        config.theme = .liquidGlass
        try LauncherConfig.save(config, to: url)
        let reloaded = try JSONDecoder.shared.decode(LauncherConfig.self, from: Data(contentsOf: url))
        #expect(reloaded.launchCount == 42)
        #expect(reloaded.theme == .liquidGlass)

        config.launchCount = 43
        try LauncherConfig.save(config, to: url)
        let updated = try JSONDecoder.shared.decode(LauncherConfig.self, from: Data(contentsOf: url))
        #expect(updated.launchCount == 43)
    }

}
