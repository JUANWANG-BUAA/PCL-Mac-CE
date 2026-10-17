//
//  ModpackPathTests.swift
//  PCLMacCE.Tests
//

import Foundation
import Testing
@testable import Core

struct ModpackPathTests {
    @Test func acceptsRelativeResourcePath() throws {
        let root = URL(fileURLWithPath: "/tmp/pcl-modpack-test")
        #expect(try ModpackImportTask.validatedDestination(for: "mods/example.jar", in: root)
                == root.appending(path: "mods/example.jar"))
    }

    @Test func rejectsSymlinkEscapingInstance() throws {
        let base = FileManager.default.temporaryDirectory.appending(path: "modpack-path-test-\(UUID().uuidString)")
        let root = base.appending(path: "instance")
        let outside = base.appending(path: "outside")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createSymbolicLink(at: root.appending(path: "mods"), withDestinationURL: outside)
        #expect(throws: (any Error).self) {
            try ModpackImportTask.validatedDestination(for: "mods/evil.jar", in: root)
        }
    }

    @Test(arguments: ["../outside", "mods/../../outside", "/tmp/outside", "mods//file.jar", "./file.jar", "mods\\file.jar", ""])
    func rejectsEscapingOrAmbiguousPath(_ path: String) {
        #expect(throws: (any Error).self) {
            try ModpackImportTask.validatedDestination(for: path, in: URL(fileURLWithPath: "/tmp/pcl-modpack-test"))
        }
    }

    @Test func failedCurseForgeMetadataFetchRemainsRetryable() async {
        let client: CurseForgeAPIClient = .init(apiKey: "")
        let file: ModpackIndex.CurseForgeFile = .init(client: client, url: nil, projectId: 1, fileId: 1)

        await #expect(throws: SimpleError.self) {
            try await file.fetchInfo()
        }
        #expect(!file.infoFetched)
    }
}
