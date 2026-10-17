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
    /// 已从队列取出并交付名额、但等待任务尚未恢复执行的等待者。
    /// 取消与 signal 竞态时，可把已经交付的名额转交给下一个等待者。
    private var grantedIDs: Set<UUID> = []

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
            if Task.isCancelled {
                currentCount += 1
                throw CancellationError()
            }
        } else {
            let id: UUID = .init()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    // continuation 闭包在 actor 隔离上下文内同步执行。
                    // 取消若先于入队发生，直接抛出，避免留下孤儿 ID。
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else {
                        waitQueue.append(.init(id: id, continuation: continuation))
                    }
                }
            } onCancel: {
                Task { await cancel(id: id) }
            }
            if Task.isCancelled {
                reclaimGrantedPermit(for: id)
                throw CancellationError()
            }
            grantedIDs.remove(id)
        }
    }

    public func signal() {
        if let waiter: Waiter = waitQueue.first {
            waitQueue.removeFirst()
            grantedIDs.insert(waiter.id)
            waiter.continuation.resume()
        } else if currentCount < maxCount {
            currentCount += 1
        }
    }

    private func cancel(id: UUID) {
        if let index = waitQueue.firstIndex(where: { $0.id == id }) {
            let waiter: Waiter = waitQueue.remove(at: index)
            waiter.continuation.resume(throwing: CancellationError())
        } else if grantedIDs.remove(id) != nil {
            reclaimPermit()
        }
    }

    private func reclaimGrantedPermit(for id: UUID) {
        guard grantedIDs.remove(id) != nil else { return }
        reclaimPermit()
    }

    private func reclaimPermit() {
        if let waiter: Waiter = waitQueue.first {
            waitQueue.removeFirst()
            grantedIDs.insert(waiter.id)
            waiter.continuation.resume()
        } else if currentCount < maxCount {
            currentCount += 1
        }
    }
}
