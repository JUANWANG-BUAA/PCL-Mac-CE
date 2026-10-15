# 安全与健壮性发现

按严重度排序，每条给位置与"现状原因"。**这是 as-is 记录，不是修复方案**。

## 高危

| # | 发现 | 位置 | 现状原因 / 说明 |
|---|---|---|---|
| H1 | **所有登录令牌明文落盘**，且应用**关闭沙盒** → 同用户任意进程可直接读走 `refreshToken` / `accessToken` / `clientToken` | `App/LauncherConfig.swift:113-116`、`PCL_Mac.entitlements:5-6` | 全仓零 Keychain 调用；作者选择"文件即配置"，令牌与设置同处 |
| H2 | **ATS 全局放行** `NSAllowsArbitraryLoads = true` + 代码显式允许 `http` | `PCL.Mac/Info.plist:6-10`、`ViewModels/AccountViewModel.swift:241` | 为兼容用户自建明文 Yggdrasil 服务器；代价是**全 app**（含微软登录）失去 TLS 强制 |
| H3 | **ALI 头可静默把凭据端点迁走**：服务端返回的 `x-authlib-injector-api-location` 可以是任意绝对 URL（含跨主机、含降级 http），且**添加账号时一次性永久固化** | `Core/Services/YggdrasilService.swift:26-28`、`AccountViewModel.swift:260-264,289` | 之后所有密码与令牌都发往该地址，用户无二次确认 |
| H4 | **Forge 安装器执行第三方 jar**：`executeProcessor` 用 `java -cp` 跑 install_profile 里声明的任意 processor，只按 maven 坐标下载，**不校验签名** | `Core/Services/ForgeInstallService.swift:212-222` | Forge 官方安装器可信，但同一代码路径不区分来源 |
| H5 | **日志会带出敏感信息，且 UI 主动鼓励外发**：argv 整行入日志，脱敏只做逐项等值替换（token 作为子串时不遮蔽）；`-javaagent:…=<authServerURL>` 与 `prefetched=<base64>` 全文入日志；日志可一键 zip 到桌面 | `Core/Minecraft/Launch/MinecraftLauncher.swift:74,61-62`、`LogManager.swift:45-59`、`SettingsViewModel.swift:21-25`、`AccountViewModel.swift:186,199` | 结果：第三方服务器身份、可能的令牌会随"把日志发给开发者"扩散 |
| H6 | **轮转后的新 refresh_token 不写盘**，落盘只在 `applicationWillTerminate` → 崩溃/强杀后回退到旧令牌 | `Core/Models/Account/MicrosoftAccount.swift:34`、`App/AppDelegate.swift:183-186` | 与 H1 叠加：令牌生命周期完全依赖正常退出 |

## 中危

| # | 发现 | 位置 |
|---|---|---|
| M1 | 移除账号**不调用任何 revoke**，微软侧授权仍长期有效 | `AccountViewModel.swift:72-82`，全仓无 `/revoke` |
| M2 | 正版"是否过期"只靠本地时钟 `>= 86400`，无服务端探测、无 401 重登；刷新失败仍可**用失效 token 继续启动** | `MicrosoftAccount.swift:38-40`、`Task/MinecraftLaunchTask.swift:144-176` |
| M3 | `config.json` **单个账号解码失败 → 整体判为损坏 → 用空配置覆盖实盘**；且 `try?` 吞掉写盘错误 | `LauncherConfig.swift:28-43` |
| M4 | 文件校验可静默降级：未知算法键被跳过（全未知即"通过"）；`checksums == nil` 直接返回 true | `Core/Utils/FileUtils.swift:58,60,67` |
| M5 | CurseForge key 缺失时**把空字符串当 key 发出**而非跳过，本地构建必然 403 且错误信息来自服务端 | `AppDelegate.swift:69-71`、`ModpackViewModel.swift:20-25`、`FileDropHandler.swift:20`、`InstalledResourcesViewModel.swift:39` |
| M6 | Yggdrasil 登录**失败路径不清理明文密码**（只有成功路径清） | `AccountViewModel.swift:297-309` |
| M7 | 玩家档案**从不验签**：`unsigned=true`，`signature` 字段解析了但不用 | `YggdrasilService.swift:160-162`、`PlayerProfile.swift:47` |
| M8 | 原始响应体整段进错误文案 → 弹窗 + 落日志，可做**日志换行注入**与文案仿冒 | `YggdrasilService.swift:225-228`、`MicrosoftAuthService.swift:144-154`、`AccountViewModel.swift:178-182,301-308` |
| ~~M9~~ | ~~`multiplayer` flag 软门控~~ | **已随联机功能移除失效（ADR-011）** |
| ~~M10~~ | ~~联机接受作者私钥签名的强制关房指令~~ | **已随联机功能移除失效（ADR-011）** |
| M11 | `hasMicrosoftAccount` 单向 sticky，永不复位 → 正版劝导逻辑与实际账号状态脱钩 | `App/LauncherConfig.swift:55`、`AccountViewModel.swift:71-82,150` |
| M12 | `--clientId ${clientid}` / `--xuid ${auth_xuid}` 无值供给，字面量进 argv（1.20.2+） | `Core/Minecraft/Launch/MinecraftLauncher.swift:25-43` 对照 `ClientManifest` gameArguments |
| M13 | 微软 client ID 硬编码且 `init()` 无参 → 无法替换为自己的应用注册 | `MicrosoftAuthService.swift:14,19` |
| M14 | `.urlEncoded` 不做百分号转义，`scope` 里的裸空格原样发出，依赖服务端容错 | `HTTPClient.swift:188`、`MicrosoftAuthService.swift:28,92` |

## 工程质量（会影响改造成本）

| # | 发现 | 位置 |
|---|---|---|
| Q1 | **编译告警**：weak 捕获与外层强捕获不一致（`Managers/MinecraftLaunchManager.swift`）、isolated conformance 传入 `@concurrent`（`Managers/TaskManager.swift`）。当前 Swift 5 模式只是 warning，**切 Swift 6 语言模式大概率编不过**（联机相关告警已随功能移除消失，ADR-011） | 构建日志 |
| Q2 | 测试 8 文件 / 285 行 / **11 用例**，且部分用例打真实网络（`PCL.Mac.Tests/DownloadTests.swift:16-85`）；账号、鉴权、启动装配**零覆盖** | — |
| Q3 | 四处 `catch let e as DecodingError` **永远进不去**（HTTPClient 已包装成 `ResponseError`）→ 解码失败原因丢失 | `YggdrasilService.swift:60-63,122-125,146-148,165-167` |
| Q4 | 新增账号类型若漏改 `is` 链 → `fatalError()` 闪退而非报错 | `Core/Models/Account/Account.swift:56-69` |
| Q5 | 无 base URL 注册表；`Core/Utils/URLConstants.swift` 名字误导（全是本地路径） | 见[接口总表](../api/inventory.md) |
| Q6 | `NativesMapper.swift` 作者自留注释："直接从老项目里抄的 / 这段代码现在只有上帝能看懂了.jpg" | `Core/Utils/NativesMapper.swift:8-9` |
| ~~Q7~~ | ~~上报 vendor 串版本不同步~~ | **已随联机功能移除失效（ADR-011）** |
| Q8 | 每个头像实例各自 new `AccountViewModel`，列表逐个重复请求纹理；启动也各自 new | `Components/PlayerAvatar.swift:12,33-42`、`MinecraftLaunchTask.swift:195` |
| Q9 | `LaunchPrecheck.checkAccount` 收下 `profile` 却完全不用，预检与账号状态脱钩 | `Core/Minecraft/Launch/LaunchPrecheck.swift:33-39` |
| Q10 | 自更新只留 `.backup` 文件、**无自动回滚**；且要求当前 `.app` 所在目录可写 | `Managers/UpdateManager.swift:42-47` |

## 一句话总结

这个项目的风险集中在**凭据处理**（明文、不撤销、不探测、日志外泄）和**外部信任**（镜像源、注入器、管理员指令、服务端响应体直接回显）两条线上，而不是业务逻辑本身。它"能用"依赖大量善意假设：正常退出、服务端诚实、用户不关沙盒、key 已配好。
