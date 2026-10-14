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

## 九、补充四：顶栏/侧栏统一、渲染时序与 hover 收尾

延续 e7f463b 的"下一步再处理头部统一与渲染时序"，本轮处理三项遗留：

### 顶栏（仅 Liquid Glass，经典主题零改动）

| 项 | 处理 |
|---|---|
| 设计语言割裂（左侧材质 + 右侧透明） | 整条顶栏统一为侧栏同款玻璃材质，分界线延续到顶栏；材质宽度不再随路由变化，减少重绘闪烁 |
| 黑字在深色壁纸上看不清 | 导航按钮组外包深色玻璃胶囊（`Glass.tint(black 0.38)`），标签改**白色字体**（毛玻璃 + 白字，macOS 悬浮控件思路） |
| 选中态 | 官方 Liquid Glass 高亮（`glassHighlight`）+ 白字；`matchedGeometryEffect` 使选中胶囊在按钮间"液体滑动"（spring 0.34 / damping 0.78） |
| 组件尺寸 | 按钮 78×27 → 88×30、图标 16→17、字号 +1；选中胶囊与整组胶囊同为 `Capsule` 全圆角 |

### 侧栏导航（`MyNavigationList`）

- 选中态由静态圆角高亮改为与顶栏同一语言的 Liquid Glass 胶囊 + `matchedGeometryEffect` 滑动；
- 新增可注入的 `selection` 命名空间：下载页"Minecraft / 社区资源"两个分组共用同一命名空间，
  选中胶囊可**跨分组**滑动；
- 行尺寸保持侧栏标准（32pt 高、图标 20、左右留白 16），不照搬顶栏按钮尺寸。

### 渲染时序（"先黑底再出效果"）

- 窗口背景由纯透明改为 `windowBackgroundColor @ 0.5`：首帧 / 玻璃材质尚未渲染时不再闪黑，
  同时提升玻璃上文字对比度（经典主题页面背景不透明，不受影响）；
- 卡片下移出现动画**保留**（PCL 特色）；曾用于规避黑底的"原生风格禁用卡片动画"已回退；
- 页面切换时的轻微亮度过渡来自卡片入场动画本身，底层不再出现黑底。

### hover 残留清理（原生风格不再出现 PCL 蓝）

| 组件 | 修正 |
|---|---|
| `MyCard` | 标题 / 折叠箭头悬停不再变蓝 |
| `MyComboBox` | 原生使用系统复选框语言（灰描边，选中为强调色填充 + 白勾），悬停只加深描边 |
| `MySelect` | 箭头改正文色降透明度；弹层选中 = 强调色底 + 白字，悬停 = 浅灰底 |
| `LaunchSidebar` 账号悬浮工具栏 | 原生使用中性阴影 / 描边（去掉蓝色发光） |
| `MyExtraTextButton` | 填充按钮悬停改为略微加深（macOS 语言），经典主题仍为变浅 |
| `ListItemButton` | 图标在原生风格使用强调色 |

### 性能

- `AppSidebarView` 移除 `AnyView`（改 `@ViewBuilder` switch），不再为读取宽度重复实例化侧栏；
- 侧栏宽度唯一来源收敛为 `AppSidebarView.sidebarWidth(for:)`（删除 `Sidebar.width` 及各侧栏重复定义）。

验证：构建 ✅ · 全量测试 ✅ · SwiftLint 修改文件 0 违规。

## 十、补充五：Cmd+Tab 黑块修复（失活期撤下玻璃特效 + 交互触发恢复）

现象：Cmd+Tab 切出再切回、或窗口失焦期间，侧栏与顶栏渲染为纯色块/黑块，
直到重新聚焦才恢复（延续 e7f463b "先黑底再出效果"的遗留调查）。

根因（多轮实测 + AppKit 头文件确认）：

- `NSGlassEffectView` 没有窗口激活状态的任何处理 API（其定位是"把控件嵌进玻璃"：
  `contentView` / `NSGlassEffectContainerView`），不是给大面积常驻背景用的；
- 系统对失活的窗口**暂停背板采样**，玻璃的两种特效在该状态下都会回退成块：
  **`tintColor`** → 整块回退渲染成纯色调块；**额外模糊**（SwiftUI `.blur`
  会把玻璃放进离屏合成路径）→ 同样回退成块；
- **无色调、无额外特效的玻璃**回退后是"透明"（内容区背景即证据），
  这是修复方案的立足点。

修复（`GlassCoverState` + `GlassCoverOverlay`）：

- **失焦 / 切换期间**：全窗（侧栏 / 顶栏 / 内容区）盖上**不透明玻璃遮罩**——
  纯 App 绘制面（平滑玻璃光泽面：冷调底色 + 上亮下暗的光泽渐变 + 顶部泛光；
  参照系统玻璃按钮质感，**无任何噪声颗粒**），**完全不依赖任何采样**：
  任何窗口状态下的渲染完全一致，不存在"回退成平板、背板恢复后 settle"的突变；
  侧栏用深色调、顶栏与内容区用浅色调；盖上时机用 `willResignActive`
  （比 `didResignActive` 更早）且不加动画；
- **内容区同样遮挡**：主区域的卡片材质在失焦 / 过渡期同样 settle
  （实机表现为"亮度很高再降下来"），盖上后 settle 发生在遮罩之下；
  实机取舍 = 以"失焦期内容不可见"换"无亮度突变"（无法"快照亮度"补偿——
  合成后的亮度只存在于窗口服务器，读取需要屏幕录制权限，且亮度差随壁纸变化）；
- 玻璃与内容本体**在遮罩之下保持原样**：不对它们做任何状态切换
  （玻璃的色调与模糊恒定 = 原版），被遮住期间渲染成什么都不可见；
- **揭幕 = 激活后 0.7s 自动**（实机调试后的定稿值，不需要用户交互），
  遮罩 0.35s 淡出；全程只有"失焦瞬时盖上 + 一次柔和揭幕"；
- 激活状态下的渲染路径（带色调玻璃 + `blur(radius: 5, opaque: true)`）与原版
  逐像素相同。

排查中确认的排除项（勿重走）：

| 尝试 | 结论 |
|---|---|
| `opaque: true` → `false`（常开） | 只解决"黑块停留到页面重绘"；回退出的块本身仍在 |
| 常删玻璃上的 SwiftUI `.blur` | 部分缓解，但损失磨砂观感；且失活期模糊本身也是黑块来源 |
| 背景层整体换 `NSVisualEffectView` 材质 | 作为**前台**外观不可接受（丢失既定 Liquid Glass 观感），已否决 |
| 失焦期用系统材质做替身（`.followsWindowActiveState` / `.active` 均实机验证） | 材质**同样依赖背板采样**：失焦 / 过渡期呈现平板（深色侧栏近黑、顶栏近白）、背板恢复后"变活"，实机表现为"纯色块 + 闪两次"，已否决——替身必须是不依赖任何采样的纯 App 绘制面 |
| 卡片材质强制 `controlActiveState = .active`（恒激活外观） | 实机验证**无效**：主区域亮度突变仍在。突变来自"背板采样有无"本身，而非材质的失活/激活外观选择，材质路线到此为准 |
| 窗口底色 0.25 → 全透明 | 实机验证**无效**：主区域突变仍可见（底色已恢复 0.25）。结论：主区域突变源自页面玻璃与材质的采样回退本身，与窗口底色无关 |
| "冻结帧"（切换瞬间截图并保持） | App 无法截取窗口的合成结果：截图 API 需屏幕录制权限，且捕获时刻可能已是坏帧；不透明遮罩以"恒定外观"实现同一目的 |

残余风险：连续快速切换时，`willResignActive` 生效前的极短窗口（亚帧级）理论上可能
露一帧玻璃的异常渲染（实测未出现）；参数集中在 `GlassCoverState`。

平台事实（调研结论）：macOS 公共 API 中不存在"大面积 + 模糊 + 失活保持"的组件——
模糊必须采样，而采样对失活窗口会被系统挂起。主流 app 要么窗口不透明（无此场景）、
要么用 alpha 透明（透出的是清晰桌面、无模糊）、要么接受失活变平（Apple 自家 Finder
亦然）。本方案（失焦期全窗自绘遮罩 + 激活后自动揭幕）是该观感取向下的唯一完整解。

验证：构建 ✅ · SwiftLint 修改文件 0 违规 · 全量测试 ✅。
