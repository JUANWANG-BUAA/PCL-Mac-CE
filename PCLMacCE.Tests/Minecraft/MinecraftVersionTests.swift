//
//  MinecraftVersionTests.swift
//  PCLMacCE
//

import Testing
import Foundation
import Core

struct MinecraftVersionTests {
    @Test func comparesVersionsWithoutNetworkManifest() {
        #expect(MinecraftVersion("1.21.10") == MinecraftVersion("1.21.10"))
        #expect(MinecraftVersion("1.21.10") < MinecraftVersion("1.21.11-pre2"))
        #expect(MinecraftVersion("1.21") > MinecraftVersion("1.20.6"))
    }
}
