# PCL Mac CE 质量治理清单

> 2026-10-15 首轮盘点。按可验证性和用户数据风险排序；不是已完成声明。

## 已落地（首轮）

- 配置保存改为原子写入；解码失败时原子备份，备份失败则禁止覆盖原配置，错误提示按实际备份结果展示。
- 拖拽导入区分“无法识别”和解析/文件错误，去除目录强制解包，并创建目标目录。
- Liquid Glass 主内容区增加轻薄非采样底色，不额外叠加系统材质。**视觉效果仍需在 macOS 26、不同壁纸及失焦/深浅环境下人工验证。**
- 同 ordinal 任务并发测试的共享数据加锁；新增配置持久化隔离测试。
- Minecraft 与整合包安装将目录预创建设为独立阶段；仅清理本任务创建的实例目录，完成标记与默认选项写入失败时阻止实例发布。

## 后续优先级

1. **P0 用户数据**：梳理 `try? LauncherConfig.save()`、下载/安装中忽略的清理错误；为配置损坏、磁盘满、只读目录、重复目标文件编写故障注入测试。确认配置失败后可恢复与用户手动修复路径。
2. **P0 安装事务**：检查 Forge/整合包的临时目录创建、取消时清理和 `.incomplete` 标记；失败时不能留下被当成完整实例的目录。`ForgeInstallService` 临时目录创建错误已移到可抛错的下载阶段；仍需故障注入测试。
3. **P1 UI**：在 macOS 12/14/26 分别核对经典与原生主题的侧栏/主区域/顶栏，测量亮暗壁纸下文本对比度、Reduce Transparency、Reduce Motion、窗口失焦及 Cmd+Tab；由截图和可访问性结果再调整 tint，不凭代码推断“已修好”。
4. **P1 性能**：用 Instruments 的 Time Profiler、Allocations、SwiftUI View Body、Core Animation 对首屏、实例列表滚动、主题切换、文件扫描建立基线；定位后再优化，避免盲目缓存或模糊层叠。
5. **P1 测试分层**：把纯离线单元测试和在线下载/本机 Java 探测分组；CI 默认只跑离线组，在线测试显式启用并设超时/资源上限。Java 探测测试是否调用进程需先审计，不能作为安静环境默认测试。
6. **P2 完整性**：对账户登录、模组/资源包、安装、更新、备份与升级迁移建立功能矩阵和手动验收清单；识别失效服务及缺失流程。

## 本轮验证边界

运行 `xcodebuild test` 的离线筛选：`ArchitectureTests`、`UUIDUtilsTest`、`MinecraftVersionTests`、`ClientManifestTests`、`MyTaskTests`、`LauncherConfigPersistenceTests`。未启动 Minecraft 或 Java 游戏进程；未执行依赖在线资源的测试。没有进行 macOS 26 实机视觉验收或性能剖析。

## 2026-10-17 补充验收

已自动化验证（`InstallerEndToEndTests`、`ThemeAppearanceTests`、`WindowSettingsTests`、`JavaCompatibilityTests`）：

- 安装器全链路：真实上游版本清单 → 客户端清单解析 → 库文件下载 → sha1 校验 →
  二次调用命中校验缓存（实测 ~4s 完成，含网络下载）。
- 深色模式行为：Liquid Glass 主题下全局外观为 `nil`（跟随系统），经典主题锁定
  `aqua`；深色外观下系统语义色可正常解析。
- 窗口参数：`has_custom_resolution` 规则仅在宽高均设置时放行；旧配置缺少窗口
  字段时按"跟随游戏设置"回落。
- Java 上界：1.16.5/1.17/1.20.4 等边界与 1.7.2 架构评分修复均有断言覆盖。

**仍需人工完成的视觉验收**（本轮环境无法进行：ScreenCaptureKit 截图权限被拒，
窗口动效导致无障碍 token 频繁失效）：

1. macOS 12 / 14 / 26 三档系统上，Liquid Glass 主题在亮/暗壁纸、深浅外观、
   Reduce Transparency、窗口失焦下的文本对比度与玻璃层级。
2. 重点检查 AppKit 控件在深色下的表现：`MySelect` 下拉、`MyTextField` 输入框、
   `NSSavePanel`/`NSOpenPanel`、系统菜单。
3. 经典主题在系统深色下应保持浅色且不出现半深色控件（全局 aqua 锁定是否生效）。
4. 实例设置新增的「游戏窗口」与「Mod 加载器」卡片在窄窗口下的布局。

