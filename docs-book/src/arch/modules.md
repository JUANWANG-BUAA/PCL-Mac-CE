# 模块清单

按 target → 目录 → 职责组织。文件数取自 `dev @ 9c69717` 实测。

## `PCL.Mac.Core`（83 文件，零 SwiftUI 依赖，单独 MIT 许可）

| 目录 | 文件 | 职责 | 代表文件 |
|---|---|---|---|
| `Models/` | 21 | 数据模型与编解码 | `ClientManifest.swift`（清单解析容错）、`VersionManifest.swift`（版本清单+缓存）、`PlayerProfile.swift`、`Account/{Account,MicrosoftAccount,YggdrasilAccount,OfflineAccount}.swift`、`Modrinth/ModrinthProject.swift`、`CurseForge/CurseForgeMod.swift`、`Minecraft/MinecraftInstance.swift`、`AuthlibInjectorArtifacts.swift`、`MojangJavaManifest.swift`、`ForgeInstallProfile.swift`、`Modpack/*` |
| `Services/` | 24 | 对外 HTTP 客户端与领域服务 | `MicrosoftAuthService.swift`、`MinecraftProfileService.swift`、`YggdrasilService.swift`、`CLAPIClient.swift`、`ModrinthAPIClient.swift`、`CurseForgeAPIClient.swift`、`MinecraftInstanceLoader.swift`、`ForgeInstallService.swift`、`NeoforgeInstallService.swift`、`JavaSearcher.swift`、`ModpackImportService.swift`、`Resource/*`、`Download/*`、`Cache/ResourceCache.swift` |
| `Minecraft/` | 6 | 启动装配与仓库抽象 | `Launch/MinecraftLauncher.swift`（拼 argv）、`Launch/LaunchOptions.swift`、`Launch/LaunchPrecheck.swift`、`Launch/LogManager.swift`、`MinecraftRepository.swift`、`MinecraftVersion.swift` |
| `Task/` | 6 | 可取消长任务框架与安装任务 | `MyTask.swift`、`AnyMyTask.swift`、`TaskModel.swift`、`MinecraftInstallTask.swift`、`JavaInstallTask.swift`、`ModpackImportTask.swift` |
| `Utils/` | 14 | 网络、文件、校验、元信息 | `HTTPClient.swift`、`FileUtils.swift`（SHA1/256/512 校验）、`URLConstants.swift`（**全是本地路径，无一个 URL**）、`UUIDUtils.swift`、`Metadata.swift`、`LocaleUtils.swift`、`PropertiesLoader.swift`、`NativesMapper.swift`、`Architecture.swift`、`AsyncSemaphore.swift`、`Errors.swift` |
| `Extensions/` | 10 | 语言扩展 | `String+Template.swift`（`${}` 占位符替换）、`String+SHA1.swift`、`JSONCoder+Shared.swift`、`Archive+EntryExtract.swift`、`URL+Utils.swift`、`Encodable+Dictionary.swift` |
| `Managers/` | 2 | 跨会话资源管理 | `InstanceManager.swift`、`JavaManager.swift` |

**注意 `Download/` 是唯一成体系的子系统**：`FileDownloader` + `DownloadDelegate` + `DownloadItem` + `DownloadSpeedManager` + `Source/{DownloadSource,DownloadSourceManager}`。详见[网络层与镜像源体系](../api/network-layer.md)。

## `PCL.Mac`（95 文件，应用 target）

| 目录 | 文件 | 职责 | 代表文件 |
|---|---|---|---|
| `App/` | 7 | 生命周期与全局装配 | `AppDelegate.swift`（**启动时序与唯一落盘时机**）、`App.swift`、`AppWindow.swift`、`AppRouter.swift`、`RootView.swift`、`LauncherConfig.swift`（15 字段配置单例）、`Secrets.swift`（读 `Secrets.properties` / 环境变量） |
| `Views/` | 27 | 页面与侧栏，按功能分 5 组 | `Launch/`（主页、实例列表、实例设置、侧栏）、`Download/`（原版游戏、加载器选项、资源搜索、资源安装）、`Settings/`、`More/`（关于、百宝箱）、`Tasks/`；顶层 `ContentView.swift`、`TitleBarView.swift`、`Sidebar.swift`、`MessageBoxView.swift` |
| `Components/` | 19 | 自绘控件库（`My*` 前缀） | `MyCard`、`MyButton`、`MyList`、`MyNavigationList`、`MySelect`、`MyComboBox`、`MySearchBox`、`MyTextField`、`MyTip`、`MyLoading`、`MyTag`、`MyExtraTextButton`、`PaginatedContainer`、`PlayerAvatar`、`NetworkImage`、`WindowButton`、`RightRoundedRectangle` |
| `ViewModels/` | 15 | MVVM 的 VM 层 | `AccountViewModel.swift`（登录编排 + 皮肤读取）、`ToolboxViewModel.swift`、`SettingsViewModel.swift`、`LaunchViewModel.swift`、`Instance/*` 四个、`MinecraftDownloadPageViewModel`、`MinecraftInstallOptionsViewModel`、`ResourceInstallViewModel`、`ResourcesSearchViewModel`、`ModpackViewModel`、`JavaSettingsViewModel`、`MyLoadingViewModel` |
| `Managers/` | 8 | 有状态的全局服务 | `FlagsManager.swift`（实验开关）、`UpdateManager.swift` + `UpdateService` 配合、`TaskManager.swift`、`MessageBoxManager.swift`、`HintManager.swift`、`MinecraftLaunchManager.swift`（崩溃报告）、`FileDropHandler.swift`、`EasterEggManager.swift` |
| `Models/` | 7 | UI 侧模型 | `UpdateModel.swift`（自更新 JSON 契约）、`MessageBoxModel`、`HintModel`、`ResourceDisplayModel`、`ProjectListItemModel`、`ProjectVersionModel`、`ListItem` |
| `Services/` | 2 | 应用侧服务 | `UpdateService.swift`（更新流程编排）、`CapeSelection.swift`（披风） |
| `Task/` | 1 | 启动任务管线 | `MinecraftLaunchTask.swift`（**刷新账号 → 注入 authlib-injector → 正版预检 → 交给 Core 拼 argv**） |
| `Extensions/` | 3 | UI 扩展 | `Localizable.swift`（账号类型等中文名）、`ColorExtension.swift`、`Environments.swift` |
| `Resources`（非 Swift） | — | 打包资源 | `Resources/Secrets.properties`（**模板，键全注释**，CI 写入真实值）、`Assets.xcassets` |

## 跨 target 的命名陷阱

`Managers/`、`Task/`、`Services/`、`Models/`、`Extensions/` 在 Core 和 App **两侧都存在**，且语义不同：

- `Core/Managers` = 实例与 Java 仓库管理；`App/Managers` = UI 生命周期相关的有状态服务
- `Core/Task` = 安装类任务 + 任务协议框架；`App/Task` = 只有启动任务一个文件
- `Core/Utils/Metadata.swift` = Info.plist 读取；`App/Models/UpdateModel.swift` 才是更新契约

## 测试现状

`PCL.Mac.Tests/` 8 文件 / 285 行 / 11 用例，集中在模型解码与下载源选择：`Minecraft/ClientManifestTests.swift`、`Minecraft/MinecraftVersionTests.swift`、`Models/MojangJavaModelsTest.swift`、`DownloadTests.swift` 等。

两个必须知道的现状：

1. 部分用例**直接打真实网络**（`DownloadTests.swift:16,36,49,56,65-71,85` 里含 `bmclapi2`、`files.minecraftforge.net`、`resources.download`、`piston-data`、`libraries.minecraft.net`），断网即失败。
2. 账号、鉴权、启动装配这三块**零测试覆盖**——恰好是本手册里风险最集中的地方。
