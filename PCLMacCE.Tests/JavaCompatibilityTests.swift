//
//  JavaCompatibilityTests.swift
//  PCLMacCE.Tests
//

import Testing
import Foundation
import Core

struct JavaCompatibilityTests {
    @Test func upperBoundByGameVersion() {
        // 1.16.5 及更早：上界 Java 16
        #expect(JavaSearcher.maximumJavaVersion(for: .init("1.12.2")) == 16)
        #expect(JavaSearcher.maximumJavaVersion(for: .init("1.16.5")) == 16)
        // 1.17–1.20.4：上界 Java 21
        #expect(JavaSearcher.maximumJavaVersion(for: .init("1.17.1")) == 21)
        #expect(JavaSearcher.maximumJavaVersion(for: .init("1.20.1")) == 21)
        #expect(JavaSearcher.maximumJavaVersion(for: .init("1.20.4")) == 21)
        // 较新版本不设上界
        #expect(JavaSearcher.maximumJavaVersion(for: .init("1.21")) == nil)
        #expect(JavaSearcher.maximumJavaVersion(for: .init("26.1")) == nil)
    }

    @Test func versionOrderingAroundBoundary() {
        // 1.16.5 <= 1.17 且 1.7.2 边界不应互相误判
        #expect(MinecraftVersion("1.16.5") < MinecraftVersion("1.17"))
        #expect(!(MinecraftVersion("1.20.5") <= MinecraftVersion("1.20.4")))
        #expect(MinecraftVersion("1.7.2") < MinecraftVersion("1.8"))
    }
}
