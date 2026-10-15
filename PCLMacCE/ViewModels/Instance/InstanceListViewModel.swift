//
//  InstanceListViewModel.swift
//  PCLMacCE
//

import Foundation
import Core
import Combine

@MainActor
class InstanceListViewModel: ObservableObject {
    @Published public private(set) var vanillaInstances: [MinecraftInstance]?
    @Published public private(set) var moddedInstances: [MinecraftInstance]?
    @Published public private(set) var errorInstances: [ErrorInstance]?
    @Published public private(set) var loading: Bool = false

    public var instanceCount: Int? {
        guard let vanillaInstances, let moddedInstances else { return nil }
        return vanillaInstances.count + moddedInstances.count
    }

    public let repository: MinecraftRepository
    public let loadingViewModel: MyLoadingViewModel = .init(text: "加载中")
    private let instanceManager: InstanceManager
    private var cancellables: Set<AnyCancellable> = []

    public init(instanceManager: InstanceManager, repositoryId: UUID) {
        self.instanceManager = instanceManager
        if let repository = instanceManager.repositories[repositoryId] {
            self.repository = repository
        } else {
            err("未找到仓库 \(repositoryId)，已回退到当前仓库。")
            self.repository = instanceManager.currentRepository
        }

        self.vanillaInstances = repository.instances.map { Self.processInstanceList(Array($0.values), modded: false) }
        self.moddedInstances = repository.instances.map { Self.processInstanceList(Array($0.values), modded: true) }
        self.errorInstances = repository.errorInstances

        self.repository.$instances
            .map { $0.map { Self.processInstanceList(Array($0.values), modded: false) } }
            .receive(on: DispatchQueue.main)
            .assign(to: \.vanillaInstances, on: self)
            .store(in: &cancellables)

        self.repository.$instances
            .map { $0.map { Self.processInstanceList(Array($0.values), modded: true) } }
            .receive(on: DispatchQueue.main)
            .assign(to: \.moddedInstances, on: self)
            .store(in: &cancellables)

        self.repository.$errorInstances
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorInstances, on: self)
            .store(in: &cancellables)
    }

    /// 重新加载实例列表。
    public func reload() {
        loadingViewModel.reset()
        loading = true
        instanceManager.startLoad(repository: repository) { result in
            self.loading = false
            if case .failure(let error) = result {
                self.loadingViewModel.fail(with: "加载失败：\(error.localizedDescription)")
            }
        }
    }

    public func rename(to newName: String) {
        repository.name = newName
    }

    public func removeRepository() {
        instanceManager.removeRepository(repository)
    }

    private static func compareInstance(lhs: MinecraftInstance, rhs: MinecraftInstance) -> Bool {
        lhs.version > rhs.version
    }

    private static func processInstanceList(_ instances: [MinecraftInstance], modded: Bool) -> [MinecraftInstance] {
        Array(instances)
            .filter { modded ? $0.modLoader != nil : $0.modLoader == nil }
            .sorted(by: Self.compareInstance(lhs:rhs:))
    }
}
