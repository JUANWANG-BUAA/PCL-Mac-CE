//
//  CrashAnalyzerTests.swift
//  PCLMacCE.Tests
//

import Foundation
import Testing
@testable import PCLMacCE

struct CrashAnalyzerTests {
    @Test func identifiesOutOfMemory() {
        let diagnosis = CrashAnalyzer.analyze(
            logText: "Exception in thread \"main\" java.lang.OutOfMemoryError: Java heap space",
            crashReportText: nil
        )
        #expect(diagnosis.title == "内存不足")
        #expect(diagnosis.isIdentified)
    }

    @Test func identifiesJavaVersionMismatch() {
        let diagnosis = CrashAnalyzer.analyze(
            logText: "java.lang.UnsupportedClassVersionError has been compiled by a more recent version of the Java Runtime",
            crashReportText: nil
        )
        #expect(diagnosis.title == "Java 版本不匹配")
    }

    @Test func identifiesModCrashFromReport() {
        let diagnosis = CrashAnalyzer.analyze(
            logText: nil,
            crashReportText: """
            ---- Minecraft Crash Report ----
            // Why did you do that?

            Mod List:
            fabric-api-0.90.0.jar
            """
        )
        #expect(diagnosis.title == "很可能是模组引发了崩溃")
    }

    @Test func identifiesMissingClass() {
        let diagnosis = CrashAnalyzer.analyze(
            logText: "java.lang.NoClassDefFoundError: net/example/Missing",
            crashReportText: nil
        )
        #expect(diagnosis.title == "缺失文件或依赖")
    }

    @Test func identifiesDiskFull() {
        let diagnosis = CrashAnalyzer.analyze(
            logText: "[Render thread/ERROR]: Failed to save level: java.io.IOException: No space left on device",
            crashReportText: nil
        )
        #expect(diagnosis.title == "磁盘空间不足")
    }

    @Test func fallsBackToUnknown() {
        let diagnosis = CrashAnalyzer.analyze(logText: "some random crash", crashReportText: nil)
        #expect(diagnosis.title == "未能识别崩溃原因")
        #expect(!diagnosis.isIdentified)
    }
}
