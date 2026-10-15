//
//  MyTaskTests.swift
//  PCLMacCE
//

import Testing
import Foundation
import Core

struct MyTaskTests {
    @Test func test() async throws {
        try await MyTask<TestModel>(name: "empty", model: .init()).start()
        _ = await #expect(throws: TaskError.invalidOrdinal(value: -1)) {
            try await MyTask<TestModel>(name: "Invalid ordinal", model: .init(), .init(-1, "", { _, _ in })).start()
        }
        _ = await #expect(throws: TaskError.unknownError) {
            try await MyTask<TestModel>(name: "Error", model: .init(), .init(0, "", { _, _ in throw TaskError.unknownError })).start()
        }

        let task: MyTask<TestModel> = .init(
            name: "Model test", model: .init(),
            .init(0, "下载客户端清单") { _, model in
                model.setValue(1)
                debug("model.value = 1")
            },
            .init(1, "下载散列资源") { _, model in
                model.increment()
                debug("model.value += 1")
            },
            .init(2, "解压本地库") { _, model in
                #expect(model.value == 4)
                debug("model.value is: \(model.value)")
            },
            .init(1, "下载依赖库") { _, model in
                model.increment()
                debug("model.value += 1")
            },
            .init(1, "下载客户端 JAR") { _, model in
                model.increment()
                debug("model.value += 1")
            }
        )
        try await task.start()
    }
}

/// 同一 ordinal 的任务会并发修改载体；用锁保护测试数据，避免数据竞争。
private final class TestModel: TaskModel, @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0
    required init() {}

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func setValue(_ value: Int) {
        lock.lock()
        defer { lock.unlock() }
        storedValue = value
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        storedValue += 1
    }
}
