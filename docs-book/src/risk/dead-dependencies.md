# 死依赖与单点

分两类：**已经死了**（实测不可达）和**还活着但只有一个人在手上**（单点）。

## 已失效（实测 2026-10-14）

`cylorine.studio` 与其 `.github.io` 均返回 GitHub Pages 的 "Site not found" —— 站点仓库被删除，**整个主域不可用**。

> **2026-10-14 改造后状态**：上述死链 URL 已集中到 `Core/Utils/APIEndpoints.swift`（`CylorineSite` 命名空间）
> 与 `Core/Utils/WebLinks.swift`，站点恢复或迁移时只需改这两处。详见 [ADR-002](../decisions/adr-002-refactor.md)。

| 受影响功能 | 依赖 | 现象 | 位置 |
|---|---|---|---|
| 启动器自更新 | `cylorine.studio/meta/PCL.Mac/update.json` | 检查更新必然失败（且本地构建因 `bundleVersion == 0` 根本不触发） | `Managers/UpdateManager.swift:14` |
| 实例版本反查 | `cylorine.studio/meta/mc/version_lookup/sha1/{sha1}` | 静默失败，版本回退显示为目录名 | `Core/Services/MinecraftInstanceLoader.swift:173` |
| 联机帮助 | `/helps/PCL.Mac#multiplayer` | 浏览器 404 | `Views/Multiplayer/MultiplayerPage.swift:139` |
| 光影教程 | `/helps/shader` | 浏览器 404 | `Views/Download/ResourcesSearchPage.swift:22,24`、`Views/Launch/InstanceSettings/InstalledResourcesPage.swift:53,55` |
| 官网 / 隐私政策 | `/`、`/projects/PCL.Mac.Refactor`、`/privacy` | 浏览器 404 | `Views/More/AboutPage.swift:27,31`、`App/AppDelegate.swift:159,162` |
| 作者头像 | `/img/avatar/*.png` | 图片加载失败，静默留空 | `AboutPage.swift:20,25` |
| README 用户群入口 | `/projects/PCL.Mac.Refactor#user_group` | 文档链接失效 | `README.md:20` |

## 仍活但单点

| 依赖 | 谁控制 | 一旦关掉的后果 | 位置 |
|---|---|---|---|
| `api.cylorine.studio/cave` | 作者 | 百宝箱回声洞报错 | `Core/Services/CLAPIClient.swift:17-19` |
| `api.cylorine.studio/easytier/{status,peers}` | 作者 | 联机拿不到节点，只剩用户自备 peer | `CLAPIClient.swift:21-35` |
| **EasyTier 管理员关房** | **作者持 Ed25519 私钥** | 可远程关掉任意房间，客户端无条件接受 | `ViewModels/MultiplayerViewModel.swift:225-242` |
| SwiftScaffolding 信令后端 | 作者（主机名不在本仓库） | 联机房间发现失效 | 客户端库已 vendor（`Vendor/SwiftScaffolding`，ADR-009）；**信令服务端**仍为上游私有设施 |
| 微软 client ID `dd28b3f2-…` | 借用作者注册的公开 client | 若被微软封禁，正版登录全断，且**无法换成自己的** | `Core/Services/MicrosoftAuthService.swift:14` |

> 实测 `https://api.cylorine.studio` 返回 **200**。所以现状是"主域已死、子域还活"，两者命运不绑定 —— 别假设联机功能也坏了。

## 第三方基础设施（非单点，但不可控）

| 依赖 | 性质 | 风险 |
|---|---|---|
| `bmclapi2.bangbang93.com` | 社区志愿镜像（bangbang93） | 停服则中国区下载退化到官方源 |
| `mod.mcimirror.top` | 社区志愿镜像 | 同上 |
| `authlib-injector.yushi.moe` | 个人维护（yushijinhun） | 第三方登录无法注入 |
| `gitee.com/yizhimcqiu/easytier-mirror` | **第三方搬运**，非 EasyTier 官方，**仓库已删除（2026-10-14 复测 404）** | ~~搬运仓库消失 → 联机内核装不上~~ **已修复**：`EasyTierManager` 下载镜像失败自动回退官方 GitHub Release zip（见 [ADR-002](../decisions/adr-002-refactor.md)） |
| `launchermeta/piston-*` 的 Java 列表 URL | 内含**硬编码 commit hash** `2ec0cc96…71` | Mojang 变更该路径即失效（`ViewModels/JavaSettingsViewModel.swift:34`） |
| `repo1.maven.org` | Maven Central | 本身稳定，但**不在镜像改写表**，中国区慢 |

## 上游仓库本身

`CylorineStudio/PCL.Mac.Refactor` 已转私有，本机凭据不可读；`PCL.Mac.Core` 的 MIT 与整体 PCL 许可约束仍然生效。详见 [ADR-001](../decisions/adr-001-baseline.md)。

## 最小替换集（按功能反推的事实清单）

如果只想让"现有功能全部可用"，需要提供的接口就是这五个：

```
GET  {origin}/meta/PCL.Mac/update.json      → UpdateModel（全字段必填）
GET  {origin}/meta/mc/version_lookup/sha1/… → {"version": String}
GET  {origin}/cave                          → {code,msg,data:[String]}
GET  {origin}/easytier/status               → {code,msg,data:{available,time,message}}
GET  {origin}/easytier/peers                → {code,msg,data:[String]}
```

其中只有第一个的 URL 可以通过构造器注入，其余三处的根地址是 `private let` 或内联字面量，**必须改源码**。见[自有后端](../api/own-backend.md#5-耦合点清单改造时的最小替换面)。
