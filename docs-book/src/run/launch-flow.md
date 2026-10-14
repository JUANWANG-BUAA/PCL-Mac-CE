# 游戏启动流程

## 任务管线

`PCL.Mac/Task/MinecraftLaunchTask.swift:30-36` 定义 7 个步骤，按序执行、可取消、有进度：

| # | 步骤 | 函数 | 说明 |
|---|---|---|---|
| 0 | 检查 Java | `checkJava` | 未配置 / 不满足要求 / 需 Rosetta 转译 三种情况各有强制弹窗（`:105,120,125`） |
| 1 | 刷新账号 | `refreshAccount` | `shouldRefresh()` → 失败可"继续"（`:140-177`），详见[正版登录链路](../auth/microsoft-chain.md) |
| 2 | 预检查 | `precheck` | 走 `Core/Minecraft/Launch/LaunchPrecheck.swift` |
| 3 | 检查资源完整性 | `checkResources` | — |
| 4 | 检查 Authlib Injector | `checkAuthlibInjector` | **仅第三方账号**，见[第三方登录](../auth/yggdrasil-offline.md) |
| 5 | 启动游戏 | `launch` | 交给 `MinecraftLauncher` |
| 6 | 等待游戏窗口出现 | `waitForWindow` | `display: false`，不显示在进度列表里 |

步骤 1 的失败处理是现状里最值得注意的产品策略：**令牌刷新失败不会阻断启动**，弹窗给"否 / 继续"，选继续就把已失效的 accessToken 塞进启动参数（`:163-176`）。

## 正版预检

`MinecraftLaunchTask.swift:194-236`：

- 中国大陆 IP（`LocaleUtils.isInChinaMainland(strict: false)`，`:200`）→ 按 `launchCount` 阈值弹"考虑一下正版？"劝导（`:200-215`），且 `hasMicrosoftAccount` 一旦为真就永久静音（`:196`）。
- 非大陆 IP → 可被切为**试玩模式** `options.demo = true`（`:228-230`）。
- `LaunchPrecheck.checkAccount` 收下了 `options.profile` 却**完全不用**（`Core/Minecraft/Launch/LaunchPrecheck.swift:33-39`）→ 预检与账号类型、令牌状态实际是脱钩的。

## 参数装配（token 进 JVM 的唯一边界）

`Core/Minecraft/Launch/MinecraftLauncher.swift`

**注入方式：直接 `Process.arguments`（`:68`），没有 argfile、没有环境变量、没有 stdin。**

参数拼装顺序（`:54-67`）：

```
-Xmx{memory}                                    :55
manifest.jvmArguments（按 rules 过滤）            :56
options.extraJvmArguments（用户自定义，#231）      :57
-javaagent:<authlib-injector.jar>=<authServerURL> :58-64
-Dauthlibinjector.yggdrasil.prefetched=<base64>   :58-64
mainClass                                         :65
manifest.gameArguments（按 rules 过滤）            :66
→ 统一做 ${} 占位符替换                             :67
```

### 占位符供给表（`:25-43`）

| key | 值来源 | 备注 |
|---|---|---|
| `auth_player_name` | `options.profile.name` | — |
| `auth_uuid` | `UUIDUtils.string(of: profile.id, withHyphens: false)` | 无连字符 |
| **`auth_access_token`** | `options.accessToken` | 正版 MC token / 第三方 Yggdrasil token / 离线随机 UUID |
| `auth_session` | 同上 | 同一 token 填两个占位符 |
| `user_type` | **硬编码 `"msa"`** | 离线与第三方账号也报 `msa` |
| `user_properties` | **硬编码 `"{}"`** | 正版也不填 textures |
| `version_type` | 硬编码 `"PCL.Mac"` | — |
| `launcher_name` / `launcher_version` | `PCL.Mac` / `Metadata.appVersion` | — |
| `natives_directory`、`library_directory`、`assets_root`、`assets_index_name`、`classpath_separator`、`version_name`、`game_directory` | 路径推导 | `assets_index_name` 缺省 `"legacy"` |
| `classpath` | 运行时补（`:49`） | — |

### 替换机制与其缺口

替换实现 `Core/Extensions/String+Template.swift:9-15`：对字典 key 逐个 `replacingOccurrences(of: "${key}")`。**字典里没有的 key 会以字面量 `${...}` 原样传给 JVM。**

对照本仓库测试 fixture 里的真实清单（`PCL.Mac.Tests/Minecraft/ClientManifestTests.swift:14`）：

```
--accessToken ${auth_access_token}   ← 正常注入
--uuid ${auth_uuid}                  ← 正常注入
--clientId ${clientid}               ← 字典里没有这个 key
--xuid ${auth_xuid}                  ← 字典里没有这个 key
```

`--clientId` / `--xuid` 是 1.20.2+ 清单字段，**既不在 values 字典、也没有 rules 保护**，会以未替换的字面量进入 argv。

其余未供给的占位符是被 rule 正确兜住的：`resolution_width/height` 因 `has_custom_resolution` 被强制丢弃（`ClientManifest.swift:351-358`，与 quickplay 系列一起标了 `// not implemented`）。

**另一处待验证**：1.12- 走老字段 `minecraftArguments`（`ClientManifest.swift:73-83` 按空格 split），老式清单的占位符是 `${access_token}` 与 `${profile_name}`，而字典里只有 `auth_access_token` / `auth_player_name` → 这些老版本的 `--accessToken` 可能不被替换。列入[未确认清单](../risk/unverified.md)。

## 日志与崩溃报告

| 项 | 位置 | 现状 |
|---|---|---|
| 游戏输出重定向 | `MinecraftLauncher.swift:69` 起 `Pipe`；临时日志 `URLConstants.tempURL/game-log-<uuid>.log`（`:24`） | — |
| 启动器日志 | `Core/Minecraft/Launch/LogManager.swift:51-59`，5 代轮转 `Log1-5.log`（`:78-84`）；INFO 同时 `print`（`:48`），WARN/ERROR 进 `os.Logger`（`:45-46`） | 含完整 argv，脱敏仅等值替换 accessToken（`:74`） |
| 崩溃报告 | `Managers/MinecraftLaunchManager.swift:120-153`：`launcher-info.json`（`:125-132`，不含 token）+ `game-log.log` + 最新 `crash-reports/*.txt` | 可一键导出 zip |

## 联机与启动的关系

联机房主启动游戏走同一套 `MinecraftLaunchTask`，但玩家名与房间身份取全局当前账号（`ViewModels/MultiplayerViewModel.swift:254-259`），并把 `127.0.0.1:{serverPort}` 复制进剪贴板供玩家手动连接。详见[联机与 EasyTier](multiplayer.md)。
