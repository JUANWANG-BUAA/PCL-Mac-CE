# ADR-006 可用性与健壮性扫尾轮

| 项 | 值 |
|---|---|
| 日期 | 2026-10-14 |
| 状态 | 已实施 |
| 验证 | 构建 ✅ · 全量测试 ✅ |

## 背景

对全仓库做"操作反人类 / 功能性缺失 / 数据丢失风险"三类审计后的修复集合。

## 修复清单

### U1. 弹窗键盘支持（反人类）

`MessageBox` 弹窗此前**完全不支持键盘**：回车不能确认、ESC 不能取消，
只能鼠标点击按钮。已在 `AppDelegate` 的全局键盘监控中扩展：

- 弹窗打开时：`Return`/小键盘 `Enter` → 触发主按钮（优先 highlight，其次 id=1，再次最后一个）；
  `ESC` → 触发取消按钮（id=0 或 `cancelButtonID`；无取消按钮时不响应）。
- 通过 `Notification.Name.messageBoxConfirm / messageBoxCancel` 通知 `MessageBoxView`，
  响应后走与鼠标点击**完全相同的**按钮逻辑（含 list 选择与 input 提交分支）。
- 弹窗关闭后 ESC 仍为"返回上一页"（原行为保留）。

### U2. 危险操作补确认（反人类）

| 操作 | 原行为 | 现行为 |
|---|---|---|
| 移除账号（侧栏 trash 图标） | 悬停点击即删 | 确认框（红色"移除"）+ 结果 hint 带账号名 |
| 删除 EasyTier（联机设置） | 一键直接删除 | 确认框（红色"删除"） |

### U3. 错误实例可操作（功能缺失）

实例列表的"错误的实例"此前只显示名称与错误信息，**没有任何操作入口**。
新增（悬停显示）：

- **打开文件夹**：定位到损坏的版本目录；
- **删除**：确认后移入废纸篓（可恢复），完成后自动重载列表。

### U4. MyLoading 失败可重试（功能缺失）

加载失败界面此前只有错误文案，用户必须退出重进页面。
`MyLoadingViewModel.fail(with:retry:)` 新增重试闭包，`MyLoading` 在失败时显示
「重试」按钮。已注册：资源搜索（搜索/翻页）、资源详情（版本列表加载）、
已安装资源（列表加载）。

### U5. 关键数据立即落盘（数据丢失风险）

`config.json` 此前**只在正常退出时保存**（`applicationWillTerminate`），
崩溃/强杀会丢失近期变更：

- **账号**：添加/移除/切换后立即保存（`AccountViewModel`）；
- **仓库**：增删/切换/重命名通过 `AppDelegate` 的 Combine sink 立即保存
  （注意 sink 经 `receive(on:)` 异步投递，故保存动作必须在 sink 内，
  而非调用方同步 `save()`——后者会先于数据同步执行）；
- **令牌**：刷新失败冷却标记（ADR-004）已即时保存。

## 记录（本轮不改，留待后续）

- **任务失败无重试**：任务列表不提供"重试"——需要持久化任务工厂，属架构级改动。
- **下载缓存无管理 UI**：普通下载的缓存文件（ADR-005）目前只能通过"打开下载缓存"浏览。
- **崩溃分析**：目前仅支持导出崩溃报告（原实现），无日志解析。

## 影响文件

`App/AppDelegate.swift`（键盘监控 + sink 落盘）、`Managers/MessageBoxManager.swift`（通知定义）、
`Views/MessageBoxView.swift`（键盘响应）、`Views/Launch/LaunchSidebar.swift`（账号删除确认）、
`Views/Multiplayer/MultiplayerSettingsPage.swift`（EasyTier 确认）、
`Views/Launch/InstanceList/InstanceListPage.swift`（错误实例操作）、
`Components/MyLoading.swift` + `ViewModels/MyLoadingViewModel.swift`（重试）、
`Views/Download/ResourcesSearchPage.swift`、`Views/Download/ResourceInstallPage.swift`、
`Views/Launch/InstanceSettings/InstalledResourcesPage.swift`（重试注册）、
`ViewModels/AccountViewModel.swift`（即时落盘）。
