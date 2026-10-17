//
//  MinecraftDownloadPage.swift
//  PCLMacCE
//

import SwiftUI
import Core
import SwiftyJSON

struct MinecraftDownloadPage: View {
    @EnvironmentObject private var viewModel: MinecraftDownloadPageViewModel
    @StateObject private var loadingModel: MyLoadingViewModel = .init(text: "加载中")
    /// 版本号关键词过滤；为空时显示全部分类。
    @State private var versionFilter: String = ""
    private static let dateFormatter: DateFormatter = {
        let formatter: DateFormatter = .init()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    var body: some View {
        CardContainer {
            if viewModel.loaded {
                MySearchBox(placeholder: "搜索版本号（如 1.12.2、23w）") { keyword in
                    versionFilter = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if versionFilter.isEmpty {
                    latestVersionsCard
                }
                categoryCard(.release)
                    .cardIndex(1)
                categoryCard(.snapshot)
                    .cardIndex(2)
                categoryCard(.old)
                    .cardIndex(3)
                categoryCard(.aprilFool)
                    .cardIndex(4)
            } else {
                MyLoading(viewModel: loadingModel)
            }
        }
        .onChange(of: viewModel.errorMessage) { errorMessage in
            syncLoadingState(errorMessage)
        }
        .onAppear {
            // 页面出现前可能已加载失败：onChange 不会对初始值触发，需显式同步一次
            syncLoadingState(viewModel.errorMessage)
        }
    }

    /// 把 ViewModel 的错误状态同步到加载视图（含重试入口）。
    private func syncLoadingState(_ errorMessage: String?) {
        if let errorMessage {
            loadingModel.fail(with: "加载失败：\(errorMessage)") {
                viewModel.reload()
            }
        } else {
            loadingModel.reset()
        }
    }

    var latestVersionsCard: some View {
        Group {
            if let latestRelease = viewModel.latestRelease {
                MyCard("最新版本", foldable: false) {
                    VStack(spacing: 0) {
                        VersionView(latestRelease, description: "最新正式版，发布于 \(Self.dateFormatter.string(from: latestRelease.releaseTime))")
                        if let latestSnapshot = viewModel.latestSnapshot {
                            VersionView(latestSnapshot, description: "最新快照版，发布于  \(Self.dateFormatter.string(from: latestSnapshot.releaseTime))")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func categoryCard(_ category: MinecraftVersion.VersionType) -> some View {
        let allVersions: [VersionManifest.Version] = viewModel.versionMap[category] ?? []
        let versions: [VersionManifest.Version] = versionFilter.isEmpty
            ? allVersions
            : allVersions.filter { $0.id.localizedCaseInsensitiveContains(versionFilter) }
        // 过滤时隐藏没有匹配项的分类，避免一屏空白卡片
        if versionFilter.isEmpty || !versions.isEmpty {
            MyCard("\(category.localizedName)（\(versions.count)）") {
                LazyVStack(spacing: 0) {
                    ForEach(versions, id: \.id) { version in
                        VersionView(
                            version,
                            description: version.type == .aprilFool
                                ? viewModel.aprilFoolVersionDescription(version.id)
                                : Self.dateFormatter.string(from: version.releaseTime)
                        )
                    }
                }
            }
        }
    }
}

private struct VersionView: View {
    @EnvironmentObject private var viewModel: InstanceManager

    private static let dateFormatter: DateFormatter = {
        let formatter: DateFormatter = .init()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()
    private let version: VersionManifest.Version
    private let description: String

    init(_ version: VersionManifest.Version, description: String) {
        self.version = version
        self.description = description
    }

    var body: some View {
        MyListItem(.init(image: version.type.icon, name: version.id, description: description))
        .onTapGesture {
            AppRouter.shared.append(.minecraftInstallOptions(version: version))
        }
    }
}
