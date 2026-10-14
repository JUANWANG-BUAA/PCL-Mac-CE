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
