//
//  InstanceManager.swift
//  PCLMacCE
//

import Foundation

@MainActor
public class InstanceManager: ObservableObject {
    @Published public private(set) var repositories: [UUID: MinecraftRepository]
    @Published public private(set) var currentRepositoryId: UUID

    public var currentRepository: MinecraftRepository { repositories[currentRepositoryId]! }
    public var currentInstance: MinecraftInstance? { currentRepository.currentInstance }

    @Published public var lastLoadError: Error?
    @Published public private(set) var loadTask: Task<Void, Never>?
    private var loadID = UUID()

    public init(repositories: [UUID: MinecraftRepository], currentRepositoryId: UUID?) {
        if repositories.isEmpty {
            let minecraftURL: URL = FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Application Support/minecraft")
            let repository = MinecraftRepository(name: "默认目录", url: minecraftURL)
            self.repositories = [repository.id: repository]
            self.currentRepositoryId = repository.id
        } else {
            self.repositories = repositories
            self.currentRepositoryId = currentRepositoryId.flatMap { repositories[$0] != nil ? $0 : nil }
                ?? repositories.first!.key
        }
    }

    public func switchRepository(to repository: MinecraftRepository) {
        let lastRepository = currentRepository
        currentRepositoryId = repository.id
        if repository.instances == nil {
            startLoad(repository: repository)
        }
        Task(priority: .background) { @MainActor in
            do {
                try lastRepository.saveAllInstances()
            } catch {
                err("保存仓库失败：\(error.localizedDescription)")
            }
        }
    }

    public func switchRepository(to repositoryId: UUID) {
        guard let repository = repositories[repositoryId] else {
            warn("试图切换到一个不存在的仓库 \(repositoryId)")
            return
        }
        switchRepository(to: repository)
    }

    public func switchInstance(to instance: MinecraftInstance, in repository: MinecraftRepository? = nil) {
        switchInstance(to: instance.id, in: repository)
    }

    public func switchInstance(to instanceId: UUID, in repository: MinecraftRepository? = nil) {
        let repository = repository ?? currentRepository
        guard repository.contains(id: instanceId) else {
            warn("试图切换到一个不存在的实例 \(instanceId)")
            return
        }
        if repository.id != currentRepositoryId {
            switchRepository(to: repository)
        }
        repository.currentInstanceId = instanceId
    }

    public func addRepository(_ repository: MinecraftRepository) {
        repositories[repository.id] = repository
    }

    public func removeRepository(_ repository: MinecraftRepository) {
        removeRepository(id: repository.id)
    }

    public func removeRepository(id: UUID) {
        if repositories.count <= 1 { return }
        if id == currentRepositoryId {
            currentRepositoryId = repositories.first(where: { $0.key != currentRepositoryId })!.key
        }
        repositories.removeValue(forKey: id)
    }

    @discardableResult
    public func startLoad(
        repository: MinecraftRepository,
        completion: (@MainActor (Result<Void, Error>) -> Void)? = nil
    ) -> Task<Void, Never> {
        loadTask?.cancel()
        let loadID = UUID()
        self.loadID = loadID
        lastLoadError = nil
        repository.instances = nil
        repository.errorInstances = nil
        let task = Task.detached {
            defer {
                Task { @MainActor in
                    if self.loadID == loadID { self.loadTask = nil }
                }
            }
            do {
                if VersionManifest.shared == nil {
                    try await VersionManifest.load()
                }
            } catch {
                err("加载版本清单失败：\(error)")
            }
            do {
                try await repository.load()
                try Task.checkCancellation()
                if await self.loadID == loadID { await completion?(.success(())) }
            } catch let error where error.isCancellationError {
                if await self.loadID == loadID { await completion?(.failure(error)) }
            } catch {
                log("加载仓库 \(repository.name) 失败：\(error.localizedDescription)")
                if await self.loadID == loadID { await completion?(.failure(error)) }
                await MainActor.run {
                    if self.loadID == loadID { self.lastLoadError = error }
                }
            }
        }
        loadTask = task
        return task
    }
}
