//
//  ResourceSearchTests.swift
//  PCLMacCE.Tests
//

import Testing
import Foundation
import Core
@testable import PCLMacCE

struct ResourceSearchTests {
    @Test func sortMapsToBothAPIs() {
        #expect(ResourceSearchSort.relevance.modrinthIndex == "relevance")
        #expect(ResourceSearchSort.downloads.modrinthIndex == "downloads")
        #expect(ResourceSearchSort.popularity.modrinthIndex == "follows")
        #expect(ResourceSearchSort.updated.modrinthIndex == "updated")

        // CurseForge: 1 Featured / 6 TotalDownloads / 2 Popularity / 3 LastUpdated
        #expect(ResourceSearchSort.relevance.curseForgeSortField == 1)
        #expect(ResourceSearchSort.downloads.curseForgeSortField == 6)
        #expect(ResourceSearchSort.popularity.curseForgeSortField == 2)
        #expect(ResourceSearchSort.updated.curseForgeSortField == 3)
        #expect(Set(ResourceSearchSort.allCases.map(\.curseForgeSortField)).count == 4)
    }

    @Test func filtersDefaultIsUnfiltered() {
        let filters = ResourcesSearchViewModel.Filters.default
        #expect(filters.gameVersion == nil)
        #expect(filters.loader == nil)
        #expect(filters.sort == .relevance)
    }

    @Test @MainActor func loaderFilterOnlyAppliesToModsAndModpacks() {
        #expect(ResourcesSearchViewModel(type: .mod).supportsLoaderFilter)
        #expect(ResourcesSearchViewModel(type: .modpack).supportsLoaderFilter)
        #expect(!ResourcesSearchViewModel(type: .resourcepack).supportsLoaderFilter)
        #expect(!ResourcesSearchViewModel(type: .shader).supportsLoaderFilter)
    }

    @Test func curseForgeMixedGameVersionsExcludeLoaderAndRendererTags() throws {
        // 来自 CurseForge 的真实混合数组形态
        let json = """
        {
          "id": 1, "modId": 2, "fileName": "shader.zip",
          "hashes": [{"value": "abc", "algo": 1}],
          "isAvailable": true,
          "downloadUrl": "https://edge.forgecdn.net/files/1/1/shader.zip",
          "gameVersions": ["1.20.1", "1.20", "Fabric", "Iris", "OptiFine", "Quilt", "Forge"],
          "releaseType": 1
        }
        """
        let file = try JSONDecoder.shared.decode(CurseForgeModFile.self, from: Data(json.utf8))
        #expect(file.minecraftVersions == ["1.20.1", "1.20"])
        #expect(file.loaders == [.fabric, .forge])
        #expect(file.isCompatible(withGameVersion: "1.20.1", loader: .fabric))
        #expect(file.isCompatible(withGameVersion: "1.20.1", loader: .forge))
        #expect(!file.isCompatible(withGameVersion: "1.20.1", loader: .neoforge))
        #expect(!file.isCompatible(withGameVersion: "1.20.1", loader: nil))
    }

    @Test func curseForgeRequiredDependenciesAreExtracted() throws {
        let json = """
        {
          "id": 10, "modId": 20, "fileName": "a.jar",
          "hashes": [], "isAvailable": true,
          "downloadUrl": "https://edge.forgecdn.net/files/10/10/a.jar",
          "gameVersions": ["1.20.1", "Forge"],
          "dependencies": [
            {"modId": 30, "relationType": 3},
            {"modId": 31, "relationType": 2},
            {"modId": 32, "relationType": 3}
          ]
        }
        """
        let file = try JSONDecoder.shared.decode(CurseForgeModFile.self, from: Data(json.utf8))
        #expect(file.requiredDependencyModIds == [30, 32])
    }
}
