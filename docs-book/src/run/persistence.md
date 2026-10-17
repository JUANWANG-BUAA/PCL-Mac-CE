# 配置持久化与 flags

## 三层存储

| 层 | 位置 | 内容 |
|---|---|---|
| 全局配置 | `~/Library/Application Support/PCLMacCE/config.json` | 启动器设置与账号元数据，不含账号令牌 |
| 实例级 | 每个版本目录下的 `.clconfig.json` + `.clmetadata.json` | 该实例的 JVM/Java/参数 + uuid/version |
| 账号令牌 | macOS Keychain；Keychain 不可用时为 `config.tokens.json` | 文件应急路径权限为 `0600`，仍是明文 |
| 应用密钥 | `Secrets.local.properties`、环境变量或注释模板 | CurseForge Key 不由 CI 注入、不随发行包配置 |

**没有数据库，也没有 `UserDefaults` 使用**；设置保存在 JSON，账号凭据由 Keychain 保存。

## `LauncherConfig` 全部字段

`App/LauncherConfig.swift:49-63`，解码全部 `decodeIfPresent` + 默认值（`:67-92`）：

| 字段 | 默认 | 用途 | 行 |
|---|---|---|---|
| `minecraftRepositories: [MinecraftRepository]` | `[]` | 多个 `.minecraft` 目录 | 49 |
| `currentRepositoryId: UUID?` | nil | 当前仓库 | 50 |
| `currentInstance: String?` | nil | 当前实例 id | 51 |
| `accounts: [Account]` | `[]` | 经 `AccountWrapper` 编解码 | 52,73,99 |
| `currentAccountId: UUID?` | nil，非法则回退 `accounts[0]` | 当前账号 | 53,74-81 |
| `hasMicrosoftAccount: Bool` | false | **单向 sticky，永不复位** | 55,83 |
| `launchCount: Int` | 0 | 正版劝导弹窗阈值 | 56,84 |
| `hasEnteredLauncher: Bool` | false | — | 57,85 |
| `ignoreLauncherUpdates: Bool` | false | "不再提示" | 59,87 |
| `autoInstallLauncherUpdates: Bool` | true | 下载后自动安装更新 | — |
| `downloadConcurrency: Int?` | nil | 下载并发上限；nil 跟随下载源建议 | — |
| `downloadSourcePolicy` | `.officialFirst` | 镜像策略 | 60,88 |
| `homepageType` | `.empty`（可选 `.demo`） | 主页类型（#215） | 61,89,136-145 |
| `enabledFlags: Set<FeatureFlag>?` | nil → 用 flags 默认 | 实验开关 | 62,90,109 |
| `customJavaRuntimes: [URL]` | `[]` | 手动添加的 Java（#243） | 63,91 |
| `theme: AppTheme` | `.classic` | 当前外观主题 | — |

编码时只有 `enabledFlags` 用 `encodeIfPresent`，其余恒编（`:94-111`）；`CodingKeys` 在 `:118-134`。

## 读写时机

| 动作 | 位置 | 现状 |
|---|---|---|
| 读 | `App/LauncherConfig.swift` | 首次访问 `shared` 时惰性加载；解码后恢复 Keychain/应急令牌，并迁移旧版 JSON 中的明文令牌 |
| 解码失败 | 同上 | 先将原文件原子备份到 `config.bak.json`；备份失败时阻止自动覆盖，备份成功后才恢复默认配置 |
| 写 | `LauncherConfig.save()` | 账号变更、设置变更和令牌刷新后即时写入；应用退出时再次保存配置 |
| 实例保存 | `AppDelegate.applicationWillTerminate` → `InstanceManager.saveAllInstances` | 退出时批量写 `.clconfig.json` |

### 这条设计的现实后果

1. 会调用保存入口的账号、主题、更新和下载设置会立即写盘；其他运行期状态在保存前仍可能仅驻留内存。
2. 整个配置作为一个 JSON 解码，单个账号字段格式错误仍可能令整份配置加载失败；应用会先保全原文件，且备份失败时禁止自动覆盖。

## 实例级配置

`Core/Models/Minecraft/MinecraftInstance.swift:45-64`：

| 字段 | 必填 | 默认 |
|---|---|---|
| `jvmHeapSize: UInt64` | 是 | 4096 |
| `javaURL: URL?` | 否 | nil（跟随全局 Java） |
| `jvmArguments: [String]` | 否 | `[]` |

读写在 `Core/Services/MinecraftInstanceLoader.swift`：常量 `:14`（`.clconfig.json`）、`:15`（`.clmetadata.json`），读 `:141-152`，解码失败回退 `.default` 并置 dirty `:74-78`，写 `:280-305`。

**注意：实例配置里没有账号字段**，所以无法为实例绑定不同账号（见[账号模型](../auth/account-model.md#实例级账号绑定不存在)）。

## 设置导入 / 导出：**不存在**

v1.1.1 没有 `LauncherConfig` 的导入导出功能（全仓库无 `importConfig` / `exportConfig`）。现有的"导出"只有：

- 导出日志 → `~/Desktop/PCL.Mac-logs-{时间}.zip`（`ViewModels/SettingsViewModel.swift:21-25`、`Views/Settings/OtherSettingsPage.swift:16-22`）
- 导出崩溃报告（`Managers/MinecraftLaunchManager.swift:95-105,120-153`）

> 网上能搜到的"设置导入导出真正可用 / JSON 配置文件导入导出"，同样是白枫那个项目的发布说明，不是本仓库。

## flags 系统

`Managers/FlagsManager.swift`（#216 引入，用于"实验性更改与风险修复"的开关）

| flag | 默认 | 实际控制 | 行 |
|---|---|---|---|
| `deduplicateLibraries` | **开** | `ClientManifest.deduplicateLibraries` → 清单库去重算法（`Core/Models/ClientManifest.swift:14,101-113`） | `:50-53` |

（`multiplayer` flag 已随联机功能移除，ADR-011。）

- 定义 `enum FeatureFlag: String, Codable, CaseIterable`（`:60-63`）；默认集合 `defaultFlags = [.deduplicateLibraries]`（`:14`）。
- 生命周期：`AppDelegate.swift:73` 用 `LauncherConfig.shared.enabledFlags` 构造 `FlagsManager.shared`（**可变全局**）；退出时 `AppDelegate.swift:184` 回灌并保存。
- UI 入口：设置页「调试 → 功能开关」两个复选框 + 顶部黄色警示（`Views/Settings/OtherSettingsPage.swift:35,38-39,58-63`）。

**现状结论**：这套 flags **不是** feature flag 平台，只是全局布尔开关。它的设计意图是给"风险修复"留退路（比如去重逻辑出问题可以关掉），目前只剩 `deduplicateLibraries` 一个。
