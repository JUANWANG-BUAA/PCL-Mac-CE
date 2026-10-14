# ADR-004 语义 Bug 修复轮：基于用户日志的实证修复

| 项 | 值 |
|---|---|
| 日期 | 2026-10-14 |
| 状态 | 已实施 |
| 方法 | 用户运行日志考古（`Logs/Log5.log`）+ 代码路径推演 |
| 验证 | 干净构建 ✅ · 全量测试 ✅ · 测试隔离实测 ✅ |

## 背景

用户报告两个语义 bug："已安装资源无法删除"、"每次启动游戏必触发一次报错"。
通过真实运行日志（非测试日志）定位到四个语义缺陷，全部修复。

## 修复清单

### B1. 已安装资源无删除入口（用户报告 #1）

`InstalledResourcesPage` 的资源条目只有 打开 / 查看 / 禁用 三个操作，**没有删除功能**
（Assets 中也无 trash 图标）。PCL 原版具备此功能。

修复：
- 新增删除按钮（SF Symbol `trash`，无需新增位图资源）+ 删除确认弹窗；
- 删除采用 `NSWorkspace.recycle`（**移入废纸篓**，可恢复，符合 macOS 惯例）；
- `InstalledResourcesViewModel.deleteResource` 同步移除 `loadResult` 缓存并刷新分页。

### B2. 微软账号令牌过期后每次启动必弹错误框（用户报告 #2）

**日志证据**（Log5，三次启动三次复现）：

```
MicrosoftAuthService: 400 invalid_grant, AADSTS70000: grant is expired.
MinecraftLaunchTask: 刷新 accessToken 失败 → 弹"刷新访问令牌失败"框 → 用户点继续 → 游戏正常启动
```

根因链：`shouldRefresh()` 以 `lastRefresh` 距今 ≥ 24h 判定 → refresh_token 永久失效
（AADSTS70000，90 天未用或被撤销）→ `refresh()` 抛错 → 弹框 → **`lastRefresh` 不更新**
→ 下次启动重复同样流程。死循环弹窗。

修复：
- `MicrosoftAuthService.Error` 新增 `grantExpired`，`post` 识别 `invalid_grant`；
- 新增 `MicrosoftAccount.markRefreshFailed()`：失败也重置 `lastRefresh`（24h 冷却），
  调用后立即 `LauncherConfig.save()` 落盘；
- 启动任务对 `grantExpired` 显示专用文案（"登录已过期，重新登录即可彻底解决"），
  其余错误维持原"是否继续启动"框；
- 补齐 `MicrosoftAuthService.Error: LocalizedError`——此前用户弹窗里显示的是
  `未能完成操作。（Core.MicrosoftAuthService.Error错误1。）` 这类无信息文案。

### B3. 测试进程污染生产环境

`PCL.Mac.Tests` 以 app 为 TEST_HOST 运行，`applicationWillFinishLaunching` 无条件
`enableLogging()`：**每次跑测试都会轮转用户的生产日志**（Log1→Log2，实测确认）、
把测试下载写入生产 `Temp/`、加载生产 `config.json`。

修复：`URLConstants.applicationSupportURL` 检测 `PCL_MAC_TESTING=1`（xctestplan 注入），
指向隔离目录 `…/PCL.Mac.Refactor/TestHome/`。实测：测试后生产日志未被触碰，
测试数据全部落在 TestHome。

### B4. fabric.mod.json 严格解析导致部分 mod 元数据丢失

**日志证据**：`ModParser: Unescaped control character '0xa' around line 7`——
社区 mod 的 `fabric.mod.json` 常在字符串内含裸换行（严格 JSON 非法，但 Newtonsoft
等宽松解析器接受；PCL 原版基于 Newtonsoft 所以能读）。

修复：`loadFabric` 严格解析失败（`DecodingError`）时，用状态机清洗器把字符串
字面量内的控制字符转义为 `\uXXXX` 后重试一次。

### 附带修复

- `toggleDisabled` 禁用/启用后未同步 `loadResult` 中的 URL——翻页后引用旧路径，
  也会使新删除功能对"已禁用资源"匹配失败。已同步。
- `ModpackViewModel` 空 `catch {}`（前轮已改为 `handleUnknownError`）。

## 死代码与实验性代码结论

| 项 | 结论 |
|---|---|
| `ReplaceMethod` | 前轮已删除（零引用） |
| `Encodable+Dictionary.toDictionary` | **非死代码**（YggdrasilService 使用），保留——本轮曾误判后恢复，教训：引用计数需全仓库验证 |
| `Compatibility.swift` | **非死代码**：macOS 12 兼容垫片（`URL.appending(path:)`、`Task.sleep(seconds:)` 均为 macOS 13+ API），部署目标 12.0 时必需 |
| `DemoHomepageView` / `HomepageType.demo` | 实验性"控件预览"页，由持久化设置项引用（设置页可选），属 feature，保留 |
| `EasterEggManager` / `FlagsManager` | 彩蛋与 feature flag 基础设施，保留 |

## 未修复（记录在案）

- `Account.type` 的 `fatalError() // unreachable`：`is` 链与三个子类的人肉同步，
  新增账号类型时是运行时崩溃点（架构问题，待账号体系重构时处理）。
