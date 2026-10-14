# ADR-007 主题系统、静态分析基线与复杂度治理

| 项 | 值 |
|---|---|
| 日期 | 2026-10-14 |
| 状态 | 已实施 |
| 工具 | SwiftLint 0.63.x（新增引入） |
| 验证 | 构建 ✅ · 全量测试 ✅ · SwiftLint 1893 → 64 |

## 一、主题系统（新功能）

### 设计

- **`AppTheme`**（`PCL.Mac/Theme/AppTheme.swift`）：`classic`（PCL 经典）/ `liquidGlass`（macOS 26 风格）。
  每个主题提供完整 `Palette`（18 色，与 `Color.colorN` 逐一对应）、页面背景、侧栏背景与
  卡片材质开关。
- **`ThemeManager`**：持有当前主题，切换时写入 `LauncherConfig.theme` 并立即落盘（ADR-006 同款即时保存）。
- **生效机制**：`Color.colorN` 等由 `static let` 改为 `static var` 委托到 `ThemeManager`，
  根视图（`RootView`）以 `.id(theme)` 在主题变化时**重建视图树**，使全部静态色板读取刷新。
  这是对"100+ 处静态色板引用"的最小侵入方案。

### Liquid Glass 视觉

- 色板切换为系统蓝（`0x0071e3`）+ Apple 中性灰阶；
- 卡片使用 `.regularMaterial` 毛玻璃 + 白色高光描边 + 更柔和阴影；
- 侧栏使用 `.ultraThinMaterial`；
- 页面背景为柔和纵向渐变。

### 入口

设置 → 外观 → 主题（`MySelect`，选择即生效并持久化）。

## 二、静态分析基线（SwiftLint 引入）

### 配置（`.swiftlint.yml`）

中文优先项目的适配决策（非机械套用默认值）：

| 规则 | 调整 | 理由 |
|---|---|---|
| `line_length` | 150/250，忽略注释/URL/函数声明 | 中文注释与长字符串多 |
| `identifier_name` | 最短 1 字符；豁免 `xs/sm/md/lg/os` 等 | 设计 token 与循环惯例 |
| `cyclomatic_complexity` | 12 警告 / 20 错误 | 保留"该拆分"质量闸门 |
| `function_body_length` | 60 / 130 | 同上 |
| `nesting` | 类型 2 / 函数 3 | SwiftUI 视图构建器天然较深 |
| `large_tuple` | 允许 3 成员 | 具名三元组（SubTask 摘要等） |

### 治理结果

| 阶段 | 违规数 |
|---|---|
| 基线（默认配置） | 1893 |
| `--fix` 自动修复（行尾空格等格式类 1522 条） | 371 |
| 配置适配 + 复杂度/命名重构 | **64** |

剩余基线（项目级已知项）：52 长行（中文长字符串）、7 个 60–90 行函数（任务定义表性质）、4 个有意保留的 TODO。

## 三、复杂度治理（圈复杂度与长函数重构 7 处）

| 函数 | 改造前 | 拆分为 |
|---|---|---|
| `AccountViewModel.requestAddMicrosoftAccount` | 复杂度 17 · 115 行 | `pollAuthorization`（轮询）+ `handleMicrosoftAuthError`（错误分类）+ 主流程 45 行 |
| `MinecraftInstallTask.create` | 148 行 | `makeBaseSubTasks`（基础任务表）+ `appendModLoaderSubTasks`（加载器任务） |
| `FileDownloader.download` | 复杂度 14 · 61 行 | `attemptDownload`（单次尝试）+ `shouldSkipCandidate`（换源判定） |
| `ModpackViewModel.importModpack` | 复杂度 14 · 75 行 | `confirmModpackInfo` + `handleLoadError` + `handleImportError` + `handleUnknownError` |
| `Architecture.architecture(of:)` | 复杂度 16 | `architectureFromFat` + `architecture(forCPUType:)` + `readUInt32`（**字节序处理逐一核对保留**） |
| `NativesMapper.map` | 复杂度 14 | `mapForX64` + `mapForArm64` + 单库映射两个（**顺带收拢漏网的 `libraries.minecraft.net` 等 2 个硬编码 URL**） |
| `MinecraftLaunchTask.checkJava` | 81 行 | `issuesForBestMatch` + `currentJavaIssue` + `confirmSwitch`（6 参数收敛为 4，提示文案打包 `SwitchPrompt`） |

治理后圈复杂度违规 **0**。

## 四、规范修复

- `force_try`（联机房间公钥解包）→ guard 安全解包；
- `type_name`：`PCL_MacApp` → `PCLMacApp`（@main 类型）；
- `non_optional_string_data_conversion` 3 处 → `Data(_:utf8)`；
- `for_where` → `guard … else { continue }`（保持 throw 语义）；
- `large_tuple` 通过配置豁免（具名元组）。

## 五、注释补充

本轮重构的所有新函数均带文档注释，并标注设计意图（如字节序核对、任务表性质、
换源判定理由、主题重建机制），累计新增/改写注释约 40 处。

## 六、补充：Liquid Glass 升级为完整原生视觉

首版主题仅替换色板，整体仍是 PCL 自绘风格。补充改造将 `liquidGlass`
升级为完整的原生 macOS 视觉（`classic` 主题不受影响）：

| 元素 | 改造前（PCL 风格） | 改造后（原生风格） |
|---|---|---|
| 字体 | PCLEnglish 品牌字体 | **SF Pro 系统字体**（`Font.app()` 随主题分派） |
| 顶栏 | 纯蓝色条 | **`.bar` 工具栏材质** + 深色文字/选中态 |
| 页面背景 | PCL 浅蓝 | **系统窗口背景色**（`windowBackgroundColor`） |
| 侧栏 | 白色矩形 | **`.thinMaterial` 材质** |
| 卡片 | 灰底 + 重阴影 | 材质底 + **细边框** + 极轻阴影（1.5pt） |
| 按钮 | 描边式 | **填充式**（强调=蓝底白字 / 常规=浅灰填充 / 圆角 6） |
| 侧栏导航 | 左侧竖条高亮 | **圆角填充高亮** |
| 列表项 hover | 蓝色淡底 + 缩放 | 淡灰填充、不缩放 |
| 输入框/下拉/搜索 | 描边式 | 填充式 + 聚焦环（accent 2pt） |
| 弹窗 | 23pt 品牌标题 + 重阴影 | **17pt semibold 系统标题** + 半透明分隔线 + 轻阴影 |
| 提示浮层 | 固定色 | 系统语义色（蓝/绿/红） |

实现方式：`AppTheme.isNativeStyle` 在组件内部做双风格分支渲染
（`MyButton`/`MyListItem`/`MyNavigationList`/`MyTip`/`MyTextField`/`MySelect`/
`TitleBarView`/`WindowButton`/`MessageBoxView`/`HintView`），
主题切换经根视图重建即时生效。

## 七、HIG 对齐二轮（差距审计）

对照 macOS HIG 的二轮审计与修正：

| 差距 | 修正 |
|---|---|
| **AccentColor 资产为空**（聚焦环/强调色无定义，且空资产会覆盖系统偏好） | 填充品牌蓝（含深色外观变体 `0.176,0.569,1.0`） |
| **正文 14pt 偏大**（macOS 正文为 13pt） | 原生风格字号整体 -1（`font(size:)` 内 `max(size-1, 9)`） |
| 卡片圆角 5pt（偏小） | 原生风格 10pt（`cardCornerRadius` 主题化） |
| 搜索框 40pt 偏大 | 原生 34pt |
| **自绘顶栏无法拖动窗口**（fullSizeContentView 下仅标准 titlebar 区可拖） | `isMovableByWindowBackground = true` |
| 缩放（绿灯）按钮被隐藏 | 原生主题显示（含全屏能力）；经典主题保持隐藏；**主题切换经 Combine 实时同步** |
| 侧栏材质带 2pt 阴影（系统侧栏无阴影） | 原生风格阴影为 0 |
| 卡片折叠箭头固定色 | 随主题前景色（原生为深色半透明） |
| 提示气泡纯白底 | 原生材质底 |

## 八、同步修复的 Bug（主题轮发现）

- **RootView 每次求值新建 VM**：`environmentObject(MinecraftDownloadPageViewModel())`
  等三处在 body 求值时构造新实例，配合 `.id(theme)` 重建会导致
  下载页/联机状态、卡片交互状态被意外重置——已提升为 `@StateObject`（生命周期稳定）。
