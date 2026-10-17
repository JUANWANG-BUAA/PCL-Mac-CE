//
//  WindowSettingsTests.swift
//  PCLMacCE.Tests
//

import Testing
import Foundation
import Core

struct WindowSettingsTests {
    /// 构造只含 has_custom_resolution 规则的参数清单。
    private func manifest(allowResolutionArgument: Bool) throws -> ClientManifest {
        let json = """
        {
          "arguments": {
            "game": [
              {"rules": [{"action": "\(allowResolutionArgument ? "allow" : "disallow")",
                          "features": {"has_custom_resolution": true}}],
               "value": ["--width", "${resolution_width}", "--height", "${resolution_height}"]}
            ],
            "jvm": ["-cp", "${classpath}"]
          },
          "assetIndex": {"id": "1.18", "sha1": "d31a2e85ae149dd1b1a7070b22cb8887892fda6c", "size": 1,
                         "totalSize": 1, "url": "https://piston-meta.mojang.com/v1/packages/d31a2e85ae149dd1b1a7070b22cb8887892fda6c/1.18.json"},
          "assets": "1.18", "id": "test",
          "downloads": {"client": {"sha1": "2e9a3e3107cca00d6bc9c97bf7d149cae163ef21", "size": 1,
                                  "url": "https://piston-data.mojang.com/v1/objects/2e9a3e3107cca00d6bc9c97bf7d149cae163ef21/client.jar"}},
          "libraries": [],
          "mainClass": "net.minecraft.client.main.Main"
        }
        """
        return try JSONDecoder.shared.decode(ClientManifest.self, from: Data(json.utf8))
    }

    /// 统计通过规则筛选后实际会注入的参数（与实际启动逻辑一致）。
    private func resolvedGameArguments(_ manifest: ClientManifest, options: LaunchOptions) -> [String] {
        return manifest.gameArguments.flatMap { $0.rules.allSatisfy { $0.test(with: options) } ? $0.value : [] }
    }

    @Test func customResolutionRuleOnlyPassesWhenBothDimensionsSet() throws {
        let allowManifest = try manifest(allowResolutionArgument: true)
        var options = LaunchOptions()
        // 未设置分辨率：has_custom_resolution 规则不通过，不注入 --width/--height
        #expect(resolvedGameArguments(allowManifest, options: options).isEmpty)
        options.windowWidth = 1280
        options.windowHeight = 720
        #expect(resolvedGameArguments(allowManifest, options: options).count == 4)

        let disallowManifest = try manifest(allowResolutionArgument: false)
        #expect(resolvedGameArguments(disallowManifest, options: options).isEmpty)
    }

    @Test func configDecodesLegacyWithoutWindowFields() throws {
        let legacy = #"{"jvmHeapSize": 2048, "jvmArguments": ["-Dfoo=1"]}"#
        let config = try JSONDecoder.shared.decode(MinecraftInstance.Config.self, from: Data(legacy.utf8))
        #expect(config.jvmHeapSize == 2048)
        #expect(config.windowWidth == nil)
        #expect(config.windowHeight == nil)
        #expect(config.fullscreen == false)
        #expect(config.customResolution == nil)
    }

    @Test func customResolutionValidatesRange() {
        var config = MinecraftInstance.Config(jvmHeapSize: 4096, javaURL: nil)
        config.windowWidth = 1280
        config.windowHeight = 720
        #expect(config.customResolution?.width == 1280)
        #expect(config.customResolution?.height == 720)
        // 只设置一个维度或越界时视为未设置
        config.windowHeight = nil
        #expect(config.customResolution == nil)
        config.windowWidth = 100
        config.windowHeight = 720
        #expect(config.customResolution == nil)
    }
}
