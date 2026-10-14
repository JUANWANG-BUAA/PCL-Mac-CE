# ADR-003 工程化改造第二轮：Xcode 27 并发范式与工程瘦身

| 项 | 值 |
|---|---|
| 日期 | 2026-10-14 |
| 状态 | 已实施 |
| 工具链 | Xcode 27.0 (27A266a) |
| 验证 | 干净构建 0 error / 0 警告（仅良性 AppIntents 提示） |

## 背景

评估发现（详见风险章节）：`SWIFT_VERSION = 5.0` + 默认 minimal 并发检查下潜藏着
**84 条** Swift 6 将拒绝的并发警告（`SWIFT_STRICT_CONCURRENCY = targeted` 实测）。
同时存在：反引号类型名 `` `Type` ``、纯镜像转发层 `LaunchViewModel`、死代码
`ReplaceMethod`、静默吞错的空 `catch {}`、项目级部署目标与 target 不一致（15.5 vs 12.0）。

## 决策

### D1. 开启 `SWIFT_STRICT_CONCURRENCY = targeted`

`Configs/Base.xcconfig`。Apple 官方渐进路线：`targeted` → `complete` → `SWIFT_VERSION = 6`。
本轮完成第一步并把警告清零，为后续铺路。

### D2. 部署目标统一

项目级 `MACOSX_DEPLOYMENT_TARGET` 15.5 → 12.0，与 App/Core target 一致
（Tests 保持 14.0，Swift Testing 需要）。

### D3. ViewModel 层 `@MainActor` 化

全部 `ObservableObject` ViewModel/Manager 标注 `@MainActor`（它们本就是 UI 状态）。
随之**拆除方法内冗余的 `await MainActor.run { … }` 样板**——方法本体已在主线程。
`Task.detached` / 非 `@Sendable` 闭包内的跳转保留。

### D4. Core 值类型补 `Sendable`

`CLAPIClient.EasyTierStatus`、`ModrinthAPIClient.SearchResponse`、`ModrinthProject`、
`EmptyModel`。**`TaskModel` 协议自此要求 `Sendable`**——MyTask 的共享可变载体
（各 Task 的 `Model`）以 `@unchecked Sendable` + 文档注释声明担保
（MyTask 设计上由子任务并发读写单一载体，属已知权衡）。

### D5. `@preconcurrency import`

App→Core 边界（Account 类等引用类型短期无法 Sendable）与第三方 `SwiftScaffolding`
使用 Apple 官方迁移工具 `@preconcurrency import`，待 Core 完成 Sendable 审计后逐个移除。

### D6. 删除 `LaunchViewModel`（-52 行）

它是 `MinecraftLaunchManager` 发布状态的纯镜像转发（属性逐一订阅再发布），
唯一消费者 `LaunchSidebar` 改为直接观察 `MinecraftLaunchManager.shared`。

### D7. 死代码清理

`ReplaceMethod`（全仓库零引用）删除。

### D8. 命名规范化：反引号类型名清零

- `MyButton.`Type`` → `MyButton.Style`（对齐 SwiftUI `ButtonStyle` 惯例）
- `HintModel.`Type`` → `HintModel.Kind`（属性名 `type` 保留，调用面零改动）

### D9. `checkDisclaimer()`：`throws` → `Bool`

原实现以异常做流程控制（地区不符/用户拒绝 → `throw SimpleError`），
调用方 3 处 fire-and-forget `Task` 丢弃错误产生警告。改为返回 `Bool`，
消除 [NoUseUnstructuredThrowingTask] 警告且更符合 Swift 惯例。

### D10. 静默吞错修复

`ModpackViewModel` 的空 `catch {}`（原注释自述"不知道为什么必须加"）——
实为 do 块中文件系统等非类型化错误的逃逸通道，改为 `handleUnknownError(error)`
（与同文件 default 分支一致）。

### D11. `nonisolated(unsafe)` 担保点（三处，均有注释指向本 ADR）

`TaskManager.execute` 的 `unsafeTask`、`EasyTierManager.downloadFromMirror` 的
进度闭包装箱（`ProgressHandlerBox`）。

## 度量

| 指标 | 改造前 | 改造后 |
|---|---|---|
| 并发相关警告（targeted 检查） | 84 | **0** |
| 反引号类型名 | 2 | 0 |
| `MainActor.run` 样板（VM 方法内） | 11 | 0 |
| 纯转发层 | 1（LaunchViewModel） | 0 |
| 死代码 enum | 1（ReplaceMethod） | 0 |

## 后续（不在本轮）

- `SWIFT_STRICT_CONCURRENCY = complete`；
- Core 模块 Sendable 全面审计（移除 App 侧 `@preconcurrency import`）；
- `MyTask` 载体模式的架构级替代（actor 化或消息传递），移除 `@unchecked`。
