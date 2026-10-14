# 正版登录链路

实现：`Core/Services/MicrosoftAuthService.swift`（229 行，全静态方法风格的 `class`）。采用 **OAuth2 设备码流程**（device code flow），没有本地回调端口、没有 ASWebAuthenticationSession。

## 端到端

```mermaid
sequenceDiagram
    autonumber
    participant U as 用户
    participant A as AccountViewModel
    participant S as MicrosoftAuthService
    participant M as login.microsoftonline.com
    participant X as user.auth.xboxlive.com
    participant T as xsts.auth.xboxlive.com
    participant C as api.minecraftservices.com
    participant J as sessionserver.mojang.com

    A->>S: start()
    S->>M: POST /devicecode (client_id, scope)
    M-->>S: device_code, user_code, expires_in, interval
    S-->>A: AuthorizationCode(userCode, verificationUri)
    A->>U: 复制 user_code 到剪贴板 + 打开验证页
    U->>M: 浏览器输入 user_code 授权
    loop pollCount = expires_in / interval 次
        A->>S: poll()
        S->>M: POST /token (grant_type=device_code, client_id, device_code)
        M-->>S: access_token + refresh_token（或 authorization_pending）
    end
    A->>S: authenticate()
    S->>X: POST /user/authenticate (RpsTicket = d=<at>)
    X-->>S: XBL Token + uhs
    S->>T: POST /xsts/authorize (UserTokens=[xblToken])
    T-->>S: XSTS Token + uhs
    S->>C: POST /authentication/login_with_xbox (XBL3.0 x=<uhs>;<token>)
    C-->>S: Minecraft access_token
    S->>C: GET /minecraft/profile (Bearer)
    C-->>S: id（error==NOT_FOUND → 未购买）
    S->>J: GET /session/minecraft/profile/<id>
    J-->>S: PlayerProfile（含 skins/capes textures）
    S-->>A: MinecraftAuthResponse
    A->>A: 组装 MicrosoftAccount → 内存 accounts
```

## 步骤与凭据

| # | 端点 | 请求携带 | 产出 | 落到哪 | 行 |
|---|---|---|---|---|---|
| 1 | `…/oauth2/v2.0/devicecode` | `client_id` + `scope="XboxLive.signin offline_access"` | `device_code`/`user_code`/`verification_uri`/`expires_in`/`interval` | `deviceCode`（`:15`）、`pollCount = expiresIn/interval`（`:35`）、`pollInterval`（`:36`） | `:23-41` |
| 2 | 浏览器（非本进程） | `user_code` | — | 只回传 UI，不存 | `ViewModels/AccountViewModel.swift:205-217` |
| 3 | `…/oauth2/v2.0/token` | `grant_type=urn:ietf:…:device_code` + `client_id` + `device_code`（**不带 scope**） | OAuth `access_token` + `refresh_token` | `oAuthToken`（`:16`）、`refreshToken`（`:17`） | `:45-64` |
| 4 | `user.auth.xboxlive.com` | `RpsTicket = "d=<at>"`、`AuthMethod="RPS"`、`RelyingParty="http://auth.xboxlive.com"` | XBL JWT + `uhs` | **仅局部变量** | `:159-177` |
| 5 | `xsts.auth.xboxlive.com` | `UserTokens=[xblToken]`、`SandboxId="RETAIL"`、`RelyingParty="rp://api.minecraftservices.com/"` | XSTS JWT + `uhs` | 仅局部变量 | `:179-198` |
| 6 | `…/authentication/login_with_xbox` | `identityToken = "XBL3.0 x=<uhs>;<xstsToken>"` | Minecraft `access_token` | 局部 `minecraftToken` | `:200-208` |
| 7a | `…/minecraft/profile` | `Authorization: Bearer` | `id`；`error=="NOT_FOUND"` → `Error.notPurchased` | — | `:210-224` |
| 7b | `sessionserver.mojang.com/…/profile/<id>` | **无鉴权头** | `PlayerProfile`（textures） | `MinecraftAuthResponse.profile` | `:226-228` |
| 8 | — | — | 账号对象 | `MicrosoftAccount{profile,accessToken,refreshToken,lastRefresh,id}` | `:79` → `AccountViewModel.swift:146` → `Models/Account/MicrosoftAccount.swift:21-27` |
| 9 | — | — | 落盘 | `accounts.didSet` → `LauncherConfig.shared.accounts`；**磁盘写入只在退出时** | `AccountViewModel.swift:14-18`、`App/AppDelegate.swift:183-186` |

编排入口是 `authenticate()`（`:68-80`），把 4→5→6→7 串起来。

## 刷新链路

`refresh(token:)`（`:85-108`）：`POST …/token` 带 `client_id` + `refresh_token` + `grant_type=refresh_token` + `scope`，拿到新 OAuth token 后**从第 4 步整条重跑**，返回全新的 `MinecraftAuthResponse`。

调用点只有两处：

1. 启动期 —— `Task/MinecraftLaunchTask.swift:140-177` 的 `refreshAccount`，是启动任务第 2 步（`:31`）。
2. 换披风 —— `Services/CapeSelection.swift:23-24`。

## Token 生命周期

| Token | 微软返回的过期字段 | 代码是否解析 | 是否检查过期 | 是否持久化 |
|---|---|---|---|---|
| `device_code` | `expires_in` | 只用来算轮询次数 | 间接（轮询耗尽报"授权超时"） | 否 |
| OAuth `access_token` | `expires_in` | **完全没解析** | 否 | 否（一次性） |
| **`refresh_token`** | `refresh_token_expires_in` | **完全没解析** | 否 | **是**，明文进 `config.json` |
| XBL / XSTS Token | JWT 内 `XEXP` | 没解析 | 否 | 否 |
| Minecraft `access_token` | `expires_in`（实际 30 天） | **丢弃**（`:207` 只取 `access_token`） | 否 | **是**，明文 |

**唯一的"过期"判据是本地墙上时钟**：

```swift
// Core/Models/Account/MicrosoftAccount.swift:38-40
public func shouldRefresh() -> Bool {
    return Date.now.timeIntervalSince(lastRefresh) >= 86400   // 硬编码 24 小时
}
```

`lastRefresh` 也在 `CodingKeys` 里（`:14`），所以跨重启有效、不会每次启动都刷。协议签名是 `async throws -> Bool`（`Account.swift:15`），但正版实现是同步常量判断——**正版这条链路完全没有服务端有效性探测、没有 401 触发重登、没有 `token/revoke` 调用**（对比第三方：`YggdrasilAccount.swift:49-51` 是真的联网 `POST /authserver/validate`）。

## 失败处理现状

| 场景 | 行为 | 行 |
|---|---|---|
| `shouldRefresh()` 抛错 | 弹"验证令牌有效性失败"，按钮 `否` / `继续`(红)；选继续**仍用旧 token 启动** | `MinecraftLaunchTask.swift:144-157` |
| `refresh()` 抛错 | 弹"刷新访问令牌失败"，同样可"继续"，`:176` 把**已失效的** accessToken 塞进 `LaunchOptions` | `:163-176` |
| 披风流程 refresh 失败 | 统一降级成"更换披风失败：…"，不区分认证错误、不提示重登 | `CapeSelection.swift:58-62` |
| XErr 特定错误码 | 有分类弹窗：`2148916238`（未成年）/ `2148916233`（未关联 Xbox）/ `.notPurchased` / `.apiError`，各带外链 | `AccountViewModel.swift:154-195`，判定源 `MicrosoftAuthService.swift:148-151` |
| 账号被微软侧永久吊销 | 只能等下次启动 refresh 失败暴露；`refreshToken` 不清除、账号不移除 | — |

## 契约边界（改造时的现实约束）

消费方（`AccountViewModel.swift:105-152`、`MicrosoftAccount.swift:29-36`）**只看到 4 个 public 方法**：`start()`、`poll()`、`authenticate()`、`refresh(token:)`，以及返回类型 `AuthorizationCode`（`:110-113`）/ `Bool` / `MinecraftAuthResponse`（`:115-119`）。这是既有的切面事实。

其他相关约束：

- 8 个端点 URL **全是内联字符串字面量**（`:25,50,87,161,181,202,212,227`），没有 baseURL 注入、没有环境开关；唯一被抽成常量的是 `MinecraftProfileService.rootURL`（`Core/Services/MinecraftProfileService.swift:14`）。
- `clientID` 是 `private let` 且 `init()` 无参（`:14`、`:19`）→ **无法换成自己的 AAD 应用注册**。
- `SandboxId` 固定 `"RETAIL"`（`:184`），`RelyingParty` 固定两个字符串（`:168`、`:189`）。
- `HTTPClient` 的 `.urlEncoded` 不做百分号转义（`Core/Utils/HTTPClient.swift:188`），而 `scope` 含裸空格（`:28`、`:92`）→ 现在能跑是依赖服务端容错。

## 已知的两个隐患

1. **轮转后的新 refresh_token 不写盘**。`MicrosoftAccount.refresh()`（`:34`）原地 mutate class，内存一致，但磁盘写入只在 `applicationWillTerminate`（`App/AppDelegate.swift:185`）。**非正常退出 → 下次加载的是旧 refresh_token**。
2. **`poll()` 要求 `access_token` 与 `refresh_token` 同时存在才返回成功**（`MicrosoftAuthService.swift:58`）。若某次响应缺 `refresh_token`，会被当成"用户还没授权"，一路轮询到次数耗尽后报**误导性的"授权超时。"**（`AccountViewModel.swift:139-141`）。
