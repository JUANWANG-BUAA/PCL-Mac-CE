//
//  JavaSearchTests.swift
//  PCLMacCE
//

import Testing
import Foundation
import Core

struct JavaSearchTests {
    @Test func testSearch() throws {
        let runtimes = try JavaSearcher.search()
        for runtime in runtimes {
            print("\(runtime.type) \(runtime.majorVersion) (\(runtime.version)) \(runtime.architecture) \(runtime.executableURL)")
            // 一致性：能被搜索器加载的 Java，其可执行文件必须能被架构解析识别
            // （thin 二进制解析回归时，这里会立刻失败而不是静默返回空列表）
            #expect(Architecture.architecture(of: runtime.executableURL) != .unknown)
            #expect(runtime.majorVersion > 0)
        }
    }
}
