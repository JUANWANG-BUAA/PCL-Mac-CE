# ADR-002 工程化改造第一轮：URL 注册表、UI Token 与死链兜底

| 项 | 值 |
|---|---|
| 日期 | 2026-10-14 |
| 状态 | 已实施 |
| 基线 | `dev` @ v1.1.1 (`9c69717`) 之后 |
| 验证 | `xcodebuild build` ✅ · `xcodebuild test` ✅（全部通过） |

## 背景

2026-10-14 对全部远程依赖做了实测复查，结合 [ADR-001](adr-001-baseline.md) 时期的代码考古，发现三类问题：

1. **死链**：`cylorine.studio` 主域整体下线（GitHub Pages 404）；
   `gitee.com/yizhimcqiu/easytier-mirror` 仓库被删除（404），
   导致**新用户无法安装 EasyTier 联机内核**——这是唯一影响可用功能的死链。
2. **URL 散落**：HTTP 根地址以字面量形式散落在 20+ 个 Swift 文件中，
   同域名字面量重复（`launchermeta` 3 次、`cylorine.studio` 3 次等），
   换源必须逐文件检索。`URLConstants.swift` 名不副实，全是本地文件路径。
3. **UI 无 token 体系**：间距、圆角、字体、语义色在组件中硬编码，
   `MyButton` 的危险红 `0xCE2111` 与悬停红 `0xFF4C4C` 为裸 hex。

## 决策

### D1. `APIEndpoints` —— 程序间通信端点的唯一注册表

- 新文件：`Core/Utils/APIEndpoints.swift`，按服务分命名空间
  （`MojangMeta` / `MicrosoftAuth` / `XboxAuth` / `Modrinth` / `ForgeMaven` / `CylorineAPI` / `Mirrors` / `EasyTier` …）。
- 已死端点**不删除**，以 `⚠️` 文档注释标注实测状态，集中在 `CylorineSite` 命名空间，
  站点恢复或迁移时一处替换。
- 全部调用点（14 个 Core 文件 + 3 个 App 文件）已改为引用注册表。

### D2. `WebLinks` —— 用户可见网页链接注册表

- 新文件：`Core/Utils/WebLinks.swift`。
- 与 `APIEndpoints` 的分工：**浏览器打开的链接**（帮助页、赞助页、商店、GitHub 讨论区）
  归 `WebLinks`；**程序请求的端点**归 `APIEndpoints`。
- `AboutPage` 的开源许可署名数据（sourceURL/licenseURL 列表）视为内容数据，保留原地。

### D3. EasyTier 下载双源兜底

- `gitee` 镜像（裸二进制 + SHA-1 校验）保留为首选；
  下载失败自动回退**官方 GitHub Release zip**
  （`easytier-macos-<arch>-v2.5.0.zip`，内含 `easytier-macos-<arch>/` 目录），
  解压提取两个二进制到目标位置。
- 官方产物与镜像哈希不保证一致：提取后写入 `<binary>.official-source` 标记文件，
  后续安装检查对该来源只做可执行校验，跳过镜像 SHA-1。
- 并发下载进度复用 Core 已有的 `ConcurrentProgressHandler`（0.5 倍率 × 2）。

### D4. `DesignTokens` —— UI 设计 token

- 新文件：`App/Extensions/DesignTokens.swift`：
  - `Spacing`（4pt 栅格：xs=4 / sm=8 / md=12 / lg=16 / xl=20 / xxl=32）
  - `Radius`（xs=2 / md=4 / lg=5，对应现网观测值）
  - `ShadowToken`（card / cardHover）
  - `Font.pcl(_:)` / `Font.cardTitle`
  - 语义色 `Color.danger` / `Color.dangerHover`
- **组件层是 token 消费边界**：`MyText` / `MyButton` / `MyCard` / `MyTip` / `MyTag` /
  `MyNavigationList` / `MySearchBox` 已全部改用 token；视图层新代码应优先使用 token。
- 品牌调色板 `Color.color1-8` / `colorGray1-8`（源自 PCL2-CE，见 issue #13）
  **保持原名不动**——它们本身就是 primitive token，改名 100+ 调用点属于高风险零收益扰动。

### D5. `MinecraftLaunchTask` 弹窗模式 DRY

- 提取 `fail(task:title:content:)`（错误提示后取消）与
  `confirmContinue(task:title:error:)`（"是否继续启动"确认框，取消则中止任务），
  消除 3 处约 30 行的重复弹窗模板。

## 实测端点状态（2026-10-14）

| 端点 | 状态 |
|---|---|
| `cylorine.studio`（主域） | ❌ 404（update.json / version_lookup / helps / 官网 / 隐私 / 头像） |
| `api.cylorine.studio` | ✅ 200（cave / easytier） |
| `gitee.com/yizhimcqiu/easytier-mirror` | ❌ 404（仓库已删除） |
| `github.com/EasyTier/EasyTier` releases | ✅（zip 兜底可用） |
| `authlib-injector.yushi.moe/artifacts.json` | ✅ 200 |
| `launchermeta.mojang.com` / `piston-*` | ✅ |
| `api.modrinth.com` / `meta.fabricmc.net` | ✅ |
| `mod.mcimirror.top` | ✅ |
| `bmclapi2.bangbang93.com` | ⚠️ 本次实测网络不可达（连接失败，疑似地区/网络差异），未判定为死链 |

## 未做（刻意）

- **不删除死链功能**：自更新、版本反查、帮助页按钮保留——换域名即恢复，
  符合"不丢失功能"的约束。
- **不做 config.json 迁移**：`DownloadSourcePolicy` 等持久化结构不动。
- **不动 `color1-8` 命名**：见 D4。
- **不引入 SwiftLint/strict concurrency**：属于下一轮工程化（见下）。

## 后续方向

1. SwiftLint + `SWIFT_STRICT_CONCURRENCY` 渐进开启；
2. `MinecraftLaunchTask` / `LaunchSidebar` 等大文件的进一步拆分；
3. 自更新源的迁移决策（依赖上游复活或自建）。
