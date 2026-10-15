//
//  TaskManager.swift
//  PCL.Mac
//

import Foundation
import Combine
import Core

@MainActor
public class TaskManager: ObservableObject {
    public static let shared: TaskManager = .init()

    @Published public private(set) var tasks: [AnyMyTask] = []
    @Published public private(set) var downloadSpeed: Int64 = 0
    private var executorTasks: [UUID: Task<Void, Error>] = [:]
    private var cancellables: [AnyCancellable] = []

    /// 开始执行一个任务。
    /// - Parameters:
    ///   - task: 待执行的任务。
    ///   - display: 是否显示与弹出 hint。
    ///   - completion: 任务完成回调。
    /// - Returns: 执行此任务的 Swift `Task`。
    @discardableResult
    public func execute<Model>(task: MyTask<Model>, display: Bool = true, completion: ((Error?) -> Void)? = nil) -> Task<Void, Error> {
        let id: UUID = task.id
        tasks.append(.init(task, display: display))
        // MyTask 的 Model 是跨子任务共享的可变载体（MyTask 设计如此），
        // 在 Swift 6 完全迁移前以此声明担保跨隔离传递（见 ADR-003）。
        nonisolated(unsafe) let unsafeTask = task
        let executorTask: Task<Void, Error> = Task {
            var e: Error?
            do {
                try await unsafeTask.start()
            } catch {
                e = error
            }
            let error = e
            if display {
                if let error, !error.isCancellationError {
                    _ = await MessageBoxManager.shared.showTextAsync(
                        title: "任务执行失败",
                        content: "任务 \(unsafeTask.name) 执行失败：\(error.localizedDescription)\n\n若要寻求帮助，请将完整日志发送给他人，而不是发送关于此页面的图片。",
                        level: .error
                    )
                } else if error == nil {
                    hint("任务 \(unsafeTask.name) 执行完成", type: .finish)
                }
            }
            await MainActor.run {
                completion?(error)
                self.clean(for: id)
            }
            if let error { throw error }
        }
        executorTasks[id] = executorTask
        return executorTask
    }

    /// 取消执行正在执行的任务.
    /// - Parameter id: 任务的 `id`。
    public func cancel(_ id: UUID) {
        log("正在取消任务 \(id)")
        if let task = executorTasks[id] {
            task.cancel()
            clean(for: id)
        }
    }

    @MainActor
    private func clean(for id: UUID) {
        tasks.removeAll(where: { $0.id == id })
        executorTasks.removeValue(forKey: id)

        if tasks.isEmpty, AppRouter.shared.last == .tasks {
            AppRouter.shared.removeLast()
        }
    }

    private init() {
        DownloadSpeedManager.shared.$currentSpeed
            .receive(on: DispatchQueue.main)
            .assign(to: \.downloadSpeed, on: self)
            .store(in: &cancellables)
    }
}
