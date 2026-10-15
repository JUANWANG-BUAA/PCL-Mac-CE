# 账号模型与判别式编解码

## 统一抽象

`Core/Models/Account/Account.swift:10-16` —— 是**协议**，不是基类。公共面只有 4 个成员：

| 成员 | 类型 | 说明 |
|---|---|---|
| `profile` | `PlayerProfile` | 名字 + UUID + properties |
| `id` | `UUID` | **本地生成**，与微软/服务端无关 |
| `accessToken` | `String` | 启动时注入 JVM 的那个令牌 |
| `refresh()` | `async throws -> Void` | 各自实现 |
| `shouldRefresh()` | `async throws -> Bool` | 各自实现 |

三个实现**全部是 `class`（引用类型）**：

| 类型 | 文件 | 独有字段 | `shouldRefresh()` 怎么判断 |
|---|---|---|---|
| 正版 | `MicrosoftAccount.swift:13-14` | `refreshToken`、`lastRefresh` | 本地时钟 ≥ 86400 秒（`:38-40`），**不联网** |
| 第三方 | `YggdrasilAccount.swift:13-19` | `authServer`、`authServerURL`、`cachedMetadata`、`clientToken`、可变 `accessToken`；`service` 是 `lazy` 且不参与编解码（`:17`） | **真的联网** `POST /authserver/validate`（`:49-51`） |
| 离线 | `OfflineAccount.swift:11-12` | 无 | 恒 `false`（`:25`） |

## 判别式编解码

因为三个实现是 class，Swift 无法自动多态编解码，所以有外层信封 `AccountWrapper`（`Account.swift:22-54`）：

```
{ "type": "microsoft" | "yggdrasil" | "offline", "account": { ...具体字段... } }
```

- `type` 是**兄弟字段**，不是 `account` 内部的 tag。
- 解码：先取 `type`（`:36-47`），按枚举分支解码具体类。
- 编码：`container.encode(account, forKey: .account)`（`:52`），依赖存在型动态派发 `encode(to:)`。
- 判定类型靠运行时 `is` 链（`:56-69`），**兜底是 `default: fatalError()`（`:66`）**。
- 挂接点：`App/LauncherConfig.swift:73`（解包 `[AccountWrapper] → [Account]`）、`:99`（回封）。

> 现状结论：新增第 4 种账号类型时，如果忘了改 `Account.swift:56-69` 的 `is` 链，**启动读配置会直接闪退**，而不是报错。

## 玩家档案模型

`Core/Models/PlayerProfile.swift:10-49`

- `id` 以**无连字符 32 位字符串**编解码（`:32`、`:39`）。
- `properties` 缺省为 `[]`（`:33`）。
- `Property.value` 保持原始 String，非 base64 也不炸（`:45-49`；这个容错来自 v1.0.4 的修复 `fix: PlayerProfile.Property 会在值不为 base64 时 decode 失败`）。
- `Property.signature` 被解析但**从未使用**（`:47`）——第三方档案用 `unsigned=true` 取，本来也没有签名。

## 当前账号与切换

| 元素 | 位置 | 行为 |
|---|---|---|
| `currentAccountId: UUID?` | `ViewModels/AccountViewModel.swift:19-23` | `didSet` 写回 `LauncherConfig.shared.currentAccountId` |
| `currentAccount` | `:24-29` | 按 UUID **线性查表**，查不到即 nil |
| 切换 | `:66-69`，UI 在 `Views/Launch/LaunchSidebar.swift:234-236` | — |
| 删除 | `AccountViewModel.swift:72-82` | 删当前账号时自动落到 `accounts.first`，否则 `currentAccountId = nil` |
| 持久化 | `App/LauncherConfig.swift:52-53`，编码 `:99-100`，解码含回退 `:73-81` | 存的 UUID 不在列表里 → 强制取 `accounts[0].id` |
| 落盘时机 | `App/AppDelegate.swift:183-186` | **只在 `applicationWillTerminate`** |

> 崩溃 / `kill -9` / 强杀 → 本次新登录的 token 全部丢失（只在内存里）。

## 实例级账号绑定：不存在

`Core/Models/Minecraft/MinecraftInstance.swift:45-58` 的实例配置只有三个字段：`jvmHeapSize` / `javaURL` / `jvmArguments`，**没有任何账号字段**。`PCL.Mac.Core` 全目录 grep `account` 只命中协议本体与启动选项（`Core/Minecraft/Launch/LaunchOptions.swift:28`、`LaunchPrecheck.swift:18`）。

启动只读全局当前账号：`LaunchSidebar.swift:70-74` → `MinecraftLaunchTask.swift:375,383-385`。全仓库**没有账号选择器 UI**。（联机功能已移除，见 ADR-011。）

## 皮肤与头像

| 账号 | textures 来源 | 位置 |
|---|---|---|
| 正版 | `sessionserver.mojang.com/session/minecraft/profile/<id>`（拿到 MSA profile 之后再取一次） | `Core/Services/MicrosoftAuthService.swift:225-228` |
| 第三方 | 自建 `<authServerURL>/sessionserver/session/minecraft/profile/<uuid>?unsigned=true` | `Core/Services/YggdrasilService.swift:155-169`；添加时取一次（`AccountViewModel.swift:283`），refresh 时再取（`YggdrasilAccount.swift:43-46`） |
| 离线 | 无（`properties: []`，`OfflineAccount.swift:15`） | — |

统一消费在 `ViewModels/AccountViewModel.swift:85-102`：取 `textures` 属性 → Base64 解码 → 拿 `textures.SKIN.url` → HTTP GET 拉 PNG。

回退行为：属性缺失（`:90`）、URL 解析失败（`:94-96`）、任何抛错（`:98-101`）一律返回同文件 `:86` 内联的 Base64 默认皮肤。渲染在 `Components/PlayerAvatar.swift`：双层裁切（头 `8,16` + 帽 `40,16`，`:25-27`）、自动兼容 64×32 / 64×64 布局（`:50`）、`CIImage` 构造失败只记 `err` 并留空白占位（`:35-38`）。

现状要点：

- **代码里不存在任何外部皮肤站集成**（grep `LittleSkin` / `skinsrest` / `skinview` 零命中），也没有换肤/上传皮肤功能。只有正版与第三方服务端下发的 textures。
- 纹理 URL 由服务端任意指定，客户端只受 `HTTPClient` 的 scheme 守卫约束（允许 http）；**无大小上限、无缓存、无去重**。
- `PlayerAvatar.swift:12` 每个头像实例各自 `new AccountViewModel`，账号列表逐个头像都会**重复请求纹理 URL**（`:33-42`，列表在 `LaunchSidebar.swift:213`）。

## 一个与账号相关的持久状态缺陷

`LauncherConfig.hasMicrosoftAccount`（`App/LauncherConfig.swift:55`）是**单向 sticky 布尔**：

- 置 `true` 于 `AccountViewModel.swift:150` 与 `MinecraftLaunchTask.swift:196`；
- **全仓库没有任何地方把它置回 `false`**（`AccountViewModel.swift:71-82` 的删除路径不复位）。

它只用于 `Core/Minecraft/Launch/LaunchPrecheck.swift:33-39` → `.noMicrosoftAccount` → 中国大陆 + 特定 `launchCount` 时的"考虑一下正版？"劝导弹窗（`MinecraftLaunchTask.swift:200-215`）。**后果：只要曾经登录过一次正版，之后即使删掉账号，该劝导永久不再出现。**
