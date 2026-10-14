# 接口总表

本启动器**没有任何自有 API 规范**——它是纯客户端，所有"接口"都是它对别人服务的调用。这一章把 v1.1.1 里的每一次对外请求穷举出来，作为改造的事实基线。

约定：`状态` 列 🟢 公开稳定 / 🟡 依赖第三方意愿 / 🔴 已失效 / ⚫ 依赖用户自建。

## 域名总表

| 域名 | 角色 | 状态 | 是否进镜像改写表 |
|---|---|---|---|
| `launchermeta.mojang.com` | 版本清单、Java 运行时列表 | 🟢 | 是 |
| `piston-meta.mojang.com` | 版本 JSON / assetIndex / Java manifest | 🟢 | 是 |
| `piston-data.mojang.com` | client.jar、mappings、logging 配置 | 🟢 | 是 |
| `resources.download.minecraft.net` | 全量 assets | 🟢 | 是 |
| `libraries.minecraft.net` | library 兜底根 | 🟢 | 是 |
| `sessionserver.mojang.com` | 正版玩家档案（textures） | 🟢 | 否 |
| `login.microsoftonline.com` | OAuth2 设备码 | 🟡 | 否 |
| `user.auth.xboxlive.com` / `xsts.auth.xboxlive.com` | XBL / XSTS | 🟡 | 否 |
| `api.minecraftservices.com` | MC 令牌、档案、披风 | 🟡 | 否 |
| `microsoft.com` | 授权链接兜底 | 🟢 | 否 |
| `api.modrinth.com` | 资源搜索/版本 | 🟢 | 否（`cdn.modrinth.com` 下载进表） |
| `api.curseforge.com` | Mod 详情 | 🟡 需 key | 否（`edge.forgecdn.net` 下载进表） |
| `meta.fabricmc.net` | Fabric 版本列表/profile | 🟢 | 是 |
| `files.minecraftforge.net` | Forge 安装器 | 🟢 | 是（`/maven` 前缀） |
| `maven.neoforged.net` | NeoForge 安装器 | 🟢 | 是（`/releases` 前缀） |
| `repo1.maven.org` | macOS natives 补丁库 | 🟢 | **否（漏网）** |
| `bmclapi2.bangbang93.com` | 中国大陆镜像 | 🟡 社区志愿 | — |
| `mod.mcimirror.top` | Modrinth/ForgeCDN 镜像 | 🟡 社区志愿 | — |
| `authlib-injector.yushi.moe` | 第三方登录注入器 | 🟡 个人维护 | **否（漏网）** |
| `gitee.com/yizhimcqiu/easytier-mirror` | EasyTier 二进制镜像 | 🟡 第三方搬运 | 否（本身即镜像） |
| `www.cloudflare-cn.com` | 出口 IP 地区判定 | 🟢 | 否 |
| `cylorine.studio` | 自更新源、版本反查、帮助页、头像 | 🔴 **已下线** | 否 |
| `api.cylorine.studio` | 回声洞、联机节点与状态 | 🟡 **作者私有，随时可关** | 否 |
| 用户输入的 Yggdrasil 服务器 | 第三方登录 | ⚫ | 否 |

> **镜像改写表**在 `Core/Services/Download/Source/DownloadSource.swift:89-115`。它只覆盖**下载**，不覆盖 API 请求；且新增官方域名必须同步改这张表才会被镜像，否则中国区仍走境外源。

## 1. 自有后端（本次改造的主目标）

| 端点 | 方法 | 用途 | 调用点 | 契约 |
|---|---|---|---|---|
| `cylorine.studio/meta/PCL.Mac/update.json` | GET(revalidate) | 启动器自更新元数据 | `Managers/UpdateManager.swift:14,24` | 见[自更新](../run/update-flow.md)，**全字段必填** |
| `cylorine.studio/meta/mc/version_lookup/sha1/{sha1}` | GET | 按 jar SHA-1 反查版本号 | `Core/Services/MinecraftInstanceLoader.swift:173` | `{"version": "..."}`，深度兜底 |
| `api.cylorine.studio/cave` | GET | 回声洞台词 | `Core/Services/CLAPIClient.swift:17-19` | 信封 `{code,msg,data}`，data 为 `[String]` |
| `api.cylorine.studio/easytier/status` | GET | 联机服务可用性公告 | `CLAPIClient.swift:21-31` | `available:Bool`、`time`(ISO8601)、`message` |
| `api.cylorine.studio/easytier/peers` | GET | EasyTier peer 列表 | `CLAPIClient.swift:33-35` | `[String]` |
| `cylorine.studio/img/avatar/*.png`、`/helps/*`、`/projects/*`、`/privacy` | GET | 头像与外链文档 | `Views/More/AboutPage.swift:20,25,27,31` 等 | 纯展示 |

统一信封与错误语义在 `CLAPIClient.swift:39-67`：`code != 0` → 抛 `apiError(code,msg)`；`data` 缺失 → `missingData`。

## 2. Mojang 元数据与安装

| 端点 | 方法 | 用途 | 调用点 |
|---|---|---|---|
| `launchermeta.mojang.com/mc/game/version_manifest.json` | GET | 版本清单 | `DownloadSource.swift:41` → `VersionManifest.swift:105-107` |
| `launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96…71/all.json` | GET | Java 运行时列表（**commit hash 硬编码**） | `ViewModels/JavaSettingsViewModel.swift:34` |
| `piston-meta…/v1/products/java-runtime/…/{sha1}.json` | GET | Java 包 manifest | `Core/Task/JavaInstallTask.swift:22` |
| manifest 内 `file.url` | 下载 | Java 二进制 | `JavaInstallTask.swift:32` |
| `piston-meta…/v1/packages/{sha1}/{id}.json` | 下载 | 版本 JSON → `ClientManifest` | `Core/Task/MinecraftInstallTask.swift:254` |
| `piston-meta…` assetIndex URL | 下载 | 资源索引 | `MinecraftInstallTask.swift:268` |
| `piston-data…/v1/objects/…/client.jar` | 下载 | 客户端 jar | `MinecraftInstallTask.swift:282` |
| `resources.download.minecraft.net/{xx}/{sha1}` ×N | 下载 | assets（并发 64、强制不走镜像） | `MinecraftInstallTask.swift:295-303` |
| manifest 内 library artifact | 下载 | libraries + natives | `MinecraftInstallTask.swift:311-314` |
| `libraries.minecraft.net` + maven path | 下载 | 无 `downloads` 字段的 library 兜底 | `Core/Models/ClientManifest.swift:260` |
| `piston-data…/…/client-1.12.xml` | 下载 | logging 配置缺失兜底 | `ClientManifest.swift:119` |
| `repo1.maven.org/maven2/…` | 下载 | macOS arm64 natives 补丁（lwjgl-glfw / objc-bridge / lwjgl2） | `Core/Utils/NativesMapper.swift:38,48,61,64` |
| `sessionserver.mojang.com/session/minecraft/profile/{id}` | GET | 正版档案（textures），**无鉴权头** | `Core/Services/MicrosoftAuthService.swift:227` |

## 3. 加载器

| 端点 | 方法 | 用途 | 调用点 |
|---|---|---|---|
| `meta.fabricmc.net/v2/versions/loader/{mc}` | GET | Fabric 列表（官方） | `DownloadSource.swift:49` |
| `bmclapi2…/fabric-meta/v2/versions/loader/{mc}` | GET | Fabric 列表（镜像） | `DownloadSource.swift:81` |
| `meta.fabricmc.net/v2/versions/loader/{v}/{loader}/profile/json` | 下载 | Fabric 客户端清单（**写死官方，不走镜像**） | `MinecraftInstallTask.swift:403-408` |
| `bmclapi2…/forge/minecraft/{mc}` | GET | Forge 版本列表（官方无此 API） | `DownloadSource.swift:73` |
| `bmclapi2…/neoforge/list/{mc}` | GET | NeoForge 版本列表 | `DownloadSource.swift:77` |
| `files.minecraftforge.net/maven/…/forge-{mc}-{v}-installer.jar` | 下载 | Forge 安装器（含 1 个变体候选） | `Core/Services/ForgeInstallService.swift:136-142` |
| `maven.neoforged.net/releases/net/neoforged/…-installer.jar` | 下载 | NeoForge 安装器（1.20.1 特例走 `neoforged/forge`） | `Core/Services/NeoforgeInstallService.swift:12-18` |
| install_profile 内 maven artifact | 下载 | 安装器依赖库 | `ForgeInstallService.swift:204-205` |
| `manifest.downloads.clientMappings.url` | 下载 | mojmaps（`DOWNLOAD_MOJMAPS` processor） | `ForgeInstallService.swift:230` |

## 4. Mod 平台

Modrinth（`Core/Services/ModrinthAPIClient.swift:11` 根 `api.modrinth.com`，**无鉴权**）：

| 端点 | 方法 | 用途 | 行 |
|---|---|---|---|
| `/v2/search?query=&facets=&limit=&offset=` | GET | 资源搜索 | 40-49 |
| `/v2/project/{id\|slug}` | GET | 项目详情（404→nil） | 58 |
| `/v2/projects?ids=<json数组>` | GET | 批量项目 | 70-74 |
| `/v2/project/{slug}/version` | GET | 版本列表 | 83 |
| `/v2/version/{id}` | GET | 单版本 | 99 |
| `/v2/version_file/{sha1}` | GET | 按哈希反查 | 108 |
| `/v2/version_files` body `{hashes,algorithm:"sha1"}` | **POST** | 批量按哈希反查 | 117-124 |
| `cdn.modrinth.com/…`（响应下发） | 下载 | 文件安装 | `ViewModels/ResourceInstallViewModel.swift:130,207` |

CurseForge（根 `api.curseforge.com`，**每个请求带 `x-api-key`**，`AsyncSemaphore` 限 8 并发，`CurseForgeAPIClient.swift:12,39-51`）：

| 端点 | 方法 | 用途 | 行 |
|---|---|---|---|
| `/v1/mods/{modId}` | GET | Mod 详情 | 22 |
| `/v1/mods/{modId}/files/{fileId}` | GET | 文件详情 | 28 |
| `edge.forgecdn.net/files/{a}/{b}/{name}` | 下载 | 响应无 downloadUrl 时兜底（仍带 key） | `Models/CurseForge/CurseForgeMod.swift:82`、`DownloadSource.swift:54-55` |

> **key 缺失时的现状行为**：调用方用 `Secrets.shared.curseforgeApiKey ?? ""`，即**把空字符串当 key 发出去**而不是跳过请求（`AppDelegate.swift:69-71`、`ModpackViewModel.swift:20-25`、`Managers/FileDropHandler.swift:20`、`ViewModels/Instance/InstalledResourcesViewModel.swift:39`）。本地构建必然 403。

## 5. 登录与身份

详见[正版登录链路](../auth/microsoft-chain.md)与[第三方与离线登录](../auth/yggdrasil-offline.md)。

| 端点 | 方法 | 凭据形式 | 行 |
|---|---|---|---|
| `login.microsoftonline.com/consumers/oauth2/v2.0/devicecode` | POST urlEncoded | `client_id` + scope | `MicrosoftAuthService.swift:25` |
| `…/oauth2/v2.0/token`（device_code） | POST urlEncoded | `device_code` | `:50` |
| `…/oauth2/v2.0/token`（refresh） | POST urlEncoded | `refresh_token` | `:87` |
| `user.auth.xboxlive.com/user/authenticate` | POST json | `RpsTicket = d=<at>` | `:161` |
| `xsts.auth.xboxlive.com/xsts/authorize` | POST json | `UserTokens=[xblToken]` | `:181` |
| `api.minecraftservices.com/authentication/login_with_xbox` | POST json | `XBL3.0 x=<uhs>;<token>` | `:202` |
| `api.minecraftservices.com/minecraft/profile` | GET | `Bearer` | `:212` |
| `api.minecraftservices.com/minecraft/profile/capes/active` | **PUT** | `Bearer` | `Core/Services/MinecraftProfileService.swift:34-43` |
| `{authServer}/authserver/{authenticate,validate,refresh}` | POST json | body 内 accessToken + clientToken | `Core/Services/YggdrasilService.swift:45,75,105` |
| `{authServer}/` (HEAD) | HEAD | 读 `x-authlib-injector-api-location` | `YggdrasilService.swift:23` |
| `{authServer}/sessionserver/session/minecraft/profile/{uuid}?unsigned=true` | GET | 无 | `YggdrasilService.swift:158` |
| `authlib-injector.yushi.moe/artifacts.json`、`/artifact/{n}.json` | GET | 无 | `Task/MinecraftLaunchTask.swift:282,286` |

## 6. 其它

| 端点 | 用途 | 行 |
|---|---|---|
| `www.cloudflare-cn.com/cdn-cgi/trace` | 出口 IP 地区判定（解析 `loc=CN`），超时 10s | `Core/Utils/LocaleUtils.swift:29` |
| `gitee.com/yizhimcqiu/easytier-mirror/releases/download/v2.5.0/easytier-{cli,core}-macos-{aarch64,x86_64}` | EasyTier 二进制，SHA-1 写死 | `Managers/EasyTierManager.swift:29,34,42,47` |
| `textures.minecraft.net`（由档案属性下发） | 皮肤 PNG | `ViewModels/AccountViewModel.swift:97` |
| 任意 URL | `NetworkImage` 通用图片加载 | `Components/NetworkImage.swift:27` |

## 现状结论（供改造参考，不含设计）

1. **没有 base URL 注册表**：24 个域名散落在 20+ 文件里以字面量出现，`launchermeta` 重复 3 次、`cylorine.studio` 3 次、`api.minecraftservices` 2 次。唯一可注入根地址的是 `CurseForgeAPIClient`（init 默认参数）。
2. **API 请求没有重试**：`HTTPClient` 用 `URLSession.shared` 单次请求；重试/退避/换源只存在于 `FileDownloader`。任何一次网络抖动都会直接冒到 UI。
3. **两条镜像漏网路径**：`repo1.maven.org`（natives 补丁）与 Fabric `profile/json`，中国区仍走境外源。
4. **`cylorine.studio` 主域已死**，`api.cylorine.studio` 仍活——两者命运不绑定，见[死依赖与单点](../risk/dead-dependencies.md)。
