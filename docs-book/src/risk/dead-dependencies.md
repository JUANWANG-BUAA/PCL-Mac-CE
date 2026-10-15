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
| 微软 client ID（缺省为 Prism 公共 ID） | Prism Launcher 团队注册的公共客户端，本项目非注册方 | 若微软封禁该 ID，依赖它的第三方启动器共同受影响；可轻量切换（ADR-010） | `Core/Services/MicrosoftAuthService.swift`，`MS_CLIENT_ID` / `PCLMAC_MS_CLIENT_ID` 可覆盖 |

> 原 `api.cylorine.studio`（回声洞 / EasyTier 节点）与 SwiftScaffolding 信令服务端的依赖
> 已随联机与回声洞功能整体移除（ADR-011），不再存在于代码中。

## 第三方基础设施（非单点，但不可控）

| 依赖 | 性质 | 风险 |
|---|---|---|
| `bmclapi2.bangbang93.com` | 社区志愿镜像（bangbang93） | 停服则中国区下载退化到官方源 |
| `mod.mcimirror.top` | 社区志愿镜像 | 同上 |
| `authlib-injector.yushi.moe` | 个人维护（yushijinhun） | 第三方登录无法注入 |
| `launchermeta/piston-*` 的 Java 列表 URL | 内含**硬编码 commit hash** `2ec0cc96…71` | Mojang 变更该路径即失效（`ViewModels/JavaSettingsViewModel.swift:34`） |
| `repo1.maven.org` | Maven Central | 本身稳定，但**不在镜像改写表**，中国区慢 |

## 上游仓库本身

`CylorineStudio/PCL.Mac.Refactor` 已转私有，本机凭据不可读；`PCL.Mac.Core` 的 MIT 与整体 PCL 许可约束仍然生效。详见 [ADR-001](../decisions/adr-001-baseline.md)。

## 最小替换集（历史记录）

原"五个端点"的最小替换集已随功能移除作废（回声洞 / 联机已删，版本反查已删，
自更新源待本项目部署后另行登记，ADR-011）。上游后端契约的历史记录见 ADR-001 / ADR-008。
