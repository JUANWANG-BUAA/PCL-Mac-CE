# Mojang 元数据与清单解析

端点清单见[接口总表](inventory.md)，这一章讲**拿到之后怎么解析**——容错边界都在这里。

## 版本清单 `VersionManifest`

`Core/Models/VersionManifest.swift`

| 行为 | 说明 | 行 |
|---|---|---|
| 进程内单例 | `static var shared: VersionManifest?`（**可变全局**，不是 let） | `:13` |
| 获取 | `load(revalidate:)`，URL 由 `DownloadSourceManager.versionManifestURL()` 决定 | `:102-119` |
| 缓存文件 | `…/PCL.Mac.Refactor/Caches/version_manifest.json` | `:104` |
| 写盘条件 | 仅当内存单例为空或与响应不等时写；写失败只记 err 不影响返回 | `:109-116` |
| 失效策略 | **无 TTL**，靠 HTTP `revalidate`（ETag/Last-Modified）；本地文件只是冷启动预热副本 | — |
| 启动时序 | `AppDelegate.swift:90-98` 先读缓存填 `shared` → `:100-101` 异步拉最新 | — |
| 其他调用点 | `Core/Managers/InstanceManager.swift:100`（不 revalidate）、`ViewModels/MinecraftDownloadPageViewModel.swift:29`（按参数） | — |
| 反查索引 | `versions` + 按 id 的 `versionMap`，`version(for:)`/`contains(_:)` 为 O(1) | `:16-17,29,88,91` |
| 别名归一 | `Pre-Release` → `-pre` | `:57` |
| 愚人节版本 | 白名单 + Europe/Stockholm 月日 + 非标准快照启发式 | `:68-82` |

## 客户端清单 `ClientManifest`

`Core/Models/ClientManifest.swift` —— 这是整个项目**容错要求最高**的模型，因为要吃的来源不统一（Mojang 官方、Fabric profile、Forge install_profile 合成、以及用户手拷的非标准实例）。

### 可选字段矩阵

| 字段 | 是否必填 | 缺省行为 | 行 |
|---|---|---|---|
| `id` | 可选 | 缺省用 `UUID().uuidString.lowercased()` | `:96` |
| `assets` | 可选 | nil | `:18,93` |
| `assetIndex` | 可选 | nil | `:19,94` |
| `downloads` | 可选 | nil | `:20,95` |
| `mainClass` | 可选（**v1.1.1 由必填改可选**） | 合并时回退父清单 | `:25,124,414` |
| `inheritsFrom` | 可选 | nil | `:27,125` |
| `version`（非标准字段） | 可选 | 用于版本反查 | `:30,126` |
| `type` | **v1.1.1 已删除** | — | 提交 `af358ee` |
| `javaVersion` | 可选 | `jre-legacy` / 8 | `:98` |
| `libraries` | 可选 | `[]` | `:100` |
| `logging` | 可选 | 解析失败回退内置 `client-1.12.xml`（含硬编码 piston-data URL 与 sha1） | `:115-123` |

### arguments 的三分支

```
有 minecraftArguments（1.12-）→ 合成 jvm 参数 + 注入 OldVersionFlag   :73-83,13
否则有 arguments             → game/jvm 各自 decodeIfPresent          :84-87
两者都无                      → 空数组                                 :88-90
```

### libraries 去重

- 开关：`ClientManifest.deduplicateLibraries`（`:14`），由 flag `deduplicateLibraries` 控制，**默认开**（`Managers/FlagsManager.swift:14`）。
- 实例内去重：`:101-113` —— `reversed()` 后"保留最后出现"，用 `HashableLibrary` 集合过滤，再 `reversed()` 复原顺序。
- 去重键：`groupId / artifactId / classifier / isNatives / rules`（`:420-434`）。
- 合并去重：`merge(to:)` `:399-402`，且要求 `isRulesSatisfied` 且首次插入。
- 现状原因：Fabric/Forge 合成清单里同一库常出现多次，重复项会让 classpath 变长甚至冲突；#213 先做 libraries 去重，#216 把它包成 flag 以便出问题可关。

## 实例识别链

`Core/Services/MinecraftInstanceLoader.swift`

| 步骤 | 说明 | 行 |
|---|---|---|
| 实例级配置 | 版本目录下的隐藏文件 `.clconfig.json` | `:14`，读 `:141-152` |
| 实例级元数据 | `.clmetadata.json`（uuid + version） | `:15,198-201` |
| 配置解码失败 | 回退 `.default` 并置 dirty（不报错） | `:74-78` |
| 版本判定 | 先看 `metadata.version` 是否在 `VersionManifest` 里，否则进 `detectVersion` | `:59-66` |
| `detectVersion` | 清单 `manifest.version` → jar 内 `version.json` → 联网 SHA-1 反查 | `:154-179` |
| 全失败 | 静默吞掉，版本回退为**目录名** | `:67-69,86,175` |

> 一个容易忽略的现状：`:59-66` 用了 `?? true`，所以 **`VersionManifest` 还没加载完时倾向认为"版本在清单里"，从而跳过反查**。冷启动瞬间加载实例列表，识别质量会略低于之后。

联网反查那一步依赖已下线的 `cylorine.studio`，详见[自有后端](own-backend.md#2-版本反查-version_lookup)。

## 仓库与实例模型

| 元素 | 位置 | 说明 |
|---|---|---|
| `.minecraft` 目录抽象 | `Core/Minecraft/MinecraftRepository.swift` | 282 行，多仓库支持；`LauncherConfig.minecraftRepositories` 持久化 |
| 实例配置 | `Core/Models/Minecraft/MinecraftInstance.swift:45-64` | 只有 `jvmHeapSize`(必填, 默认 4096) / `javaURL` / `jvmArguments` **三个字段** |
| 实例管理 | `Core/Managers/InstanceManager.swift` | 扫描、保存；`saveAllInstances` 由退出流程触发（`App/AppDelegate.swift:180-181`） |
| 版本抽象 | `Core/Minecraft/MinecraftVersion.swift` | — |

**现状要点**：实例配置里**没有账号字段**，所以无法给某个实例绑定不同账号，全局只有一个"当前账号"。见[账号模型](../auth/account-model.md#五实例级账号绑定不存在)。
