//
//  InstallationTransactionTests.swift
//  PCLMacCE.Tests
//

import Foundation
import Testing
@testable import Core

struct InstallationTransactionTests {
    @Test func losingDirectoryReservationCannotDeleteWinner() throws {
        let root: URL = FileManager.default.temporaryDirectory.appending(path: "instance-reservation-\(UUID().uuidString)")
        let instanceDirectory: URL = root.appending(path: "versions/Existing")
        defer { try? FileManager.default.removeItem(at: root) }

        let firstReservation: InstallationDirectoryReservation = .init(url: instanceDirectory)
        try firstReservation.create()
        let existingFile: URL = instanceDirectory.appending(path: "user-data.txt")
        try Data("keep".utf8).write(to: existingFile)

        let secondReservation: InstallationDirectoryReservation = .init(url: instanceDirectory)
        #expect(throws: (any Error).self) { try secondReservation.create() }
        try secondReservation.removeIfOwned()

        #expect(FileManager.default.fileExists(atPath: existingFile.path))
        #expect(try String(contentsOf: existingFile, encoding: .utf8) == "keep")
        try firstReservation.removeIfOwned()
        #expect(!FileManager.default.fileExists(atPath: instanceDirectory.path))
    }

    @Test func preexistingInstanceDirectoryCannotBeClaimed() throws {
        let root: URL = FileManager.default.temporaryDirectory.appending(path: "instance-reservation-\(UUID().uuidString)")
        let instanceDirectory: URL = root.appending(path: "versions/Existing")
        try FileManager.default.createDirectory(at: instanceDirectory, withIntermediateDirectories: true)
        let existingFile: URL = instanceDirectory.appending(path: "user-data.txt")
        try Data("keep".utf8).write(to: existingFile)
        defer { try? FileManager.default.removeItem(at: root) }

        let reservation: InstallationDirectoryReservation = .init(url: instanceDirectory)
        #expect(throws: (any Error).self) { try reservation.create() }
        try reservation.removeIfOwned()

        #expect(try String(contentsOf: existingFile, encoding: .utf8) == "keep")
    }

    @Test func reservationCleansOnlyItsOwnIncompleteInstance() throws {
        let root: URL = FileManager.default.temporaryDirectory.appending(path: "instance-reservation-\(UUID().uuidString)")
        let instanceDirectory: URL = root.appending(path: "versions/New")
        defer { try? FileManager.default.removeItem(at: root) }

        let reservation: InstallationDirectoryReservation = .init(url: instanceDirectory)
        try reservation.create()
        try reservation.createIncompleteMarker()
        #expect(FileManager.default.fileExists(atPath: instanceDirectory.appending(path: ".incomplete").path))

        try reservation.removeIfOwned()

        #expect(!FileManager.default.fileExists(atPath: instanceDirectory.path))
    }

    @Test func installationDirectoryIsCreatedBeforeManifestDownloadStage() throws {
        let repository: MinecraftRepository = .init(
            name: "Test",
            url: FileManager.default.temporaryDirectory.appending(path: "installation-stage-\(UUID().uuidString)")
        )
        let task: MyTask<MinecraftInstallTask.Model> = MinecraftInstallTask.create(
            name: "New",
            version: .init("1.20.1"),
            repository: repository,
            modLoader: nil
        )
        let preStage: Int = try #require(task.subTasks.first(where: { $0.name == "__pre" })?.ordinal)
        let manifestStage: Int = try #require(task.subTasks.first(where: { $0.name == "下载客户端 JSON 文件" })?.ordinal)

        #expect(preStage < manifestStage)
    }
}
