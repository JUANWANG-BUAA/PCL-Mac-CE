import Foundation
import Testing
@testable import Core

struct AuditRegressionTests {
    @MainActor
    @Test func missingSelectedRepositoryFallsBackToAvailableRepository() {
        let repository = MinecraftRepository(
            name: "Test",
            url: FileManager.default.temporaryDirectory.appending(path: "pcl-repository-test")
        )
        let manager = InstanceManager(
            repositories: [repository.id: repository],
            currentRepositoryId: UUID()
        )
        #expect(manager.currentRepositoryId == repository.id)
        #expect(manager.currentRepository.id == repository.id)
    }

    @Test func unknownChecksumCannotVerifyDownloadedFile() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "pcl-checksum-test-\(UUID().uuidString)")
        try Data("known payload".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(try FileUtils.checkFile(at: file, with: ["unknown": "anything"]) == false)
        #expect(try FileUtils.checkFile(at: file, with: ["sha1": FileUtils.sha1(of: file)]) == true)
    }
}
