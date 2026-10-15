# 安全与健壮性发现

按严重度排序，保留原审计编号，并标注已修复或仍待处理的风险。

## 高危

| # | 发现 | 位置 | 现状原因 / 说明 |
|---|---|---|---|
| H1 | **登录令牌仍明文落盘**，且应用关闭沙盒 → 同用户进程仍能读取令牌 | `App/LauncherConfig.swift`、`PCLMacCE.entitlements` | 配置及备份已收紧为 `0600`，但尚未迁入 Keychain |
| H2 | **ATS 全局放行** `NSAllowsArbitraryLoads = true` + 代码显式允许 `http` | `PCL.Mac/Info.plist:6-10`、`ViewModels/AccountViewModel.swift:241` | 为兼容用户自建明文 Yggdrasil 服务器；代价是**全 app**（含微软登录）失去 TLS 强制 |
| H3 | ALI 头仍可指定外部凭据端点 | `YggdrasilService.swift`、`AccountViewModel.swift` | 跨主机或 HTTPS 降级至 HTTP 时已增加登录前确认；同主机的路径、端口变化仍由服务端决定 |
| H4 | **Forge 安装器执行第三方 jar**：`executeProcessor` 用 `java -cp` 跑 install_profile 里声明的任意 processor，只按 maven 坐标下载，**不校验签名** | `Core/Services/ForgeInstallService.swift:212-222` | Forge 官方安装器可信，但同一代码路径不区分来源 |
| H5 | **日志仍可能含游戏进程自行输出的敏感信息**，且可一键导出 | `Core/Minecraft/Launch/MinecraftLauncher.swift`、`SettingsViewModel.swift` | 启动器 argv 的令牌子串、authlib 注入参数已脱敏；导出前仍须检查游戏原始日志 |
| ~~H6~~ | ~~刷新后的令牌仅在退出时写盘~~ | `Task/MinecraftLaunchTask.swift` | **已修复**：刷新成功后立即保存；写盘失败会提示 |

## 中危

| # | 发现 | 位置 |
|---|---|---|
| M1 | 移除账号**不调用任何 revoke**，微软侧授权仍长期有效 | `AccountViewModel.swift:72-82`，全仓无 `/revoke` |
| M2 | 正版"是否过期"只靠本地时钟 `>= 86400`，无服务端探测、无 401 重登；刷新失败仍可**用失效 token 继续启动** | `MicrosoftAccount.swift:38-40`、`Task/MinecraftLaunchTask.swift:144-176` |
| M3 | 单个账号解码失败仍会令整体配置无法加载；原文件现先备份，备份失败则禁止自动覆盖 | `LauncherConfig.swift` |
| M4 | `checksums == nil` 仍表示无校验；**全为未知算法时现会拒绝通过** | `Core/Utils/FileUtils.swift` |
| M5 | CurseForge key 缺失时**把空字符串当 key 发出**而非跳过，本地构建必然 403 且错误信息来自服务端 | `AppDelegate.swift:69-71`、`ModpackViewModel.swift:20-25`、`FileDropHandler.swift:20`、`InstalledResourcesViewModel.swift:39` |
| ~~M6~~ | ~~Yggdrasil 登录失败后保留明文密码~~，且曾错误裁剪首尾空格 | `AccountViewModel.swift`；**已修复** |
| M7 | 玩家档案**从不验签**：`unsigned=true`，`signature` 字段解析了但不用 | `YggdrasilService.swift:160-162`、`PlayerProfile.swift:47` |
| M8 | 微软认证错误文案仍需限制长度与换行；Yggdrasil 响应错误已截断为 300 字符并去除换行 | `MicrosoftAuthService.swift`、`YggdrasilService.swift` |
| ~~M9~~ | ~~`multiplayer` flag 软门控~~ | **已随联机功能移除失效（ADR-011）** |
| ~~M10~~ | ~~联机接受作者私钥签名的强制关房指令~~ | **已随联机功能移除失效（ADR-011）** |
| M11 | `hasMicrosoftAccount` 单向 sticky，永不复位 → 正版劝导逻辑与实际账号状态脱钩 | `App/LauncherConfig.swift:55`、`AccountViewModel.swift:71-82,150` |
| M12 | `--clientId ${clientid}` / `--xuid ${auth_xuid}` 无值供给，字面量进 argv（1.20.2+） | `Core/Minecraft/Launch/MinecraftLauncher.swift:25-43` 对照 `ClientManifest` gameArguments |
| ~~M13~~ | ~~微软 client ID 无法替换~~；现支持构造参数、环境变量及 `Secrets.properties` 覆盖 | `MicrosoftAuthService.swift` |
| ~~M14~~ | ~~`.urlEncoded` 未进行百分号转义~~ | `HTTPClient.swift`；**已修复** |

## 工程质量（会影响改造成本）

| # | 发现 | 位置 |
|---|---|---|
| Q1 | **编译告警**：weak 捕获与外层强捕获不一致（`Managers/MinecraftLaunchManager.swift`）、isolated conformance 传入 `@concurrent`（`Managers/TaskManager.swift`）。当前 Swift 5 模式只是 warning，**切 Swift 6 语言模式大概率编不过**（联机相关告警已随功能移除消失，ADR-011） | 构建日志 |
| Q2 | 测试覆盖仍有限，部分下载用例使用真实网络；账号、鉴权、启动装配缺少端到端覆盖 | `PCLMacCE.Tests` |
| Q3 | 四处 `catch let e as DecodingError` **永远进不去**（HTTPClient 已包装成 `ResponseError`）→ 解码失败原因丢失 | `YggdrasilService.swift:60-63,122-125,146-148,165-167` |
| Q4 | 新增账号类型若漏改 `is` 链 → `fatalError()` 闪退而非报错 | `Core/Models/Account/Account.swift:56-69` |
| Q5 | 无 base URL 注册表；`Core/Utils/URLConstants.swift` 名字误导（全是本地路径） | 见[接口总表](../api/inventory.md) |
| Q6 | `NativesMapper.swift` 作者自留注释："直接从老项目里抄的 / 这段代码现在只有上帝能看懂了.jpg" | `Core/Utils/NativesMapper.swift:8-9` |
| ~~Q7~~ | ~~上报 vendor 串版本不同步~~ | **已随联机功能移除失效（ADR-011）** |
| ~~Q8~~ | ~~头像各自新建账号 ViewModel 并重复下载纹理~~ | `Components/PlayerAvatar.swift`、`AccountViewModel.swift`；**已共享缓存与 CIContext** |
| Q9 | `LaunchPrecheck.checkAccount` 收下 `profile` 却完全不用，预检与账号状态脱钩 | `Core/Minecraft/Launch/LaunchPrecheck.swift:33-39` |
| Q10 | 自更新只留 `.backup` 文件、**无自动回滚**；且要求当前 `.app` 所在目录可写 | `Managers/UpdateManager.swift:42-47` |

## 一句话总结

剩余重点是**凭据处理**（令牌明文、不撤销、失效探测不足、游戏原始日志可能含敏感信息）和**外部来源验证**（Forge 处理器、第三方认证服务）。相关问题需分别设计迁移与验证流程。
