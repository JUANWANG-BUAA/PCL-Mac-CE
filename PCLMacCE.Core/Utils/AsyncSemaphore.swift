//
//  AsyncSemaphore.swift
//  PCLMacCE
//

import Foundation

/// 支持取消的异步信号量。
/// 等待中的任务被取消时抛出 `CancellationError`：被取消的请求不会占用并发名额，
/// 也不会在恢复执行后继续发起上游请求。
public actor AsyncSemaphore {
    private let maxCount: Int
    private var currentCount: Int
    private var waitQueue: [Waiter] = []
    /// 已取消但可能尚未入队的等待者（onCancel 与入队之间存在竞态，用 id 追认）。
    private var cancelledIDs: Set<UUID> = []

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    public init(value: Int) {
        self.maxCount = value
        self.currentCount = value
    }

    /// 获取一个信号；任务被取消时抛出 `CancellationError`。
    public func wait() async throws {
        try Task.checkCancellation()
        if currentCount > 0 {
            currentCount -= 1
        } else {
            let id: UUID = .init()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    // 闭包在当前 actor 上下文内同步执行，可直接入队
                    enqueue(.init(id: id, continuation: continuation))
                }
            } onCancel: {
                Task { await cancel(id: id) }
            }
        }
    }

    public func signal() {
        if let waiter: Waiter = waitQueue.first {
            waitQueue.removeFirst()
            waiter.continuation.resume()
        } else if currentCount < maxCount {
            currentCount += 1
        }
    }

    private func enqueue(_ waiter: Waiter) {
        if cancelledIDs.contains(waiter.id) {
            cancelledIDs.remove(waiter.id)
            waiter.continuation.resume(throwing: CancellationError())
        } else {
            waitQueue.append(waiter)
        }
    }

    private func cancel(id: UUID) {
        if let index = waitQueue.firstIndex(where: { $0.id == id }) {
            let waiter: Waiter = waitQueue.remove(at: index)
            waiter.continuation.resume(throwing: CancellationError())
        } else {
            cancelledIDs.insert(id)
        }
    }
}
