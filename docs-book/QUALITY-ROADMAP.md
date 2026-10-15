# PCL Mac CE 质量治理清单

> 2026-10-15 首轮盘点。按可验证性和用户数据风险排序；不是已完成声明。

## 已落地（首轮）

- 配置保存改为原子写入；解码失败时原子备份，备份失败则禁止覆盖原配置，错误提示按实际备份结果展示。
- 拖拽导入区分“无法识别”和解析/文件错误，去除目录强制解包，并创建目标目录。
- Liquid Glass 主内容区增加轻薄非采样底色，不额外叠加系统材质。**视觉效果仍需在 macOS 26、不同壁纸及失焦/深浅环境下人工验证。**
- 同 ordinal 任务并发测试的共享数据加锁；新增配置持久化隔离测试。

## 后续优先级

1. **P0 用户数据**：梳理 `try? LauncherConfig.save()`、下载/安装中忽略的清理错误；为配置损坏、磁盘满、只读目录、重复目标文件编写故障注入测试。确认配置失败后可恢复与用户手动修复路径。
2. **P0 安装事务**：检查 Forge/整合包的临时目录创建、取消时清理和 `.incomplete` 标记；失败时不能留下被当成完整实例的目录。`ForgeInstallService` 初始化阶段目前吞掉临时目录创建错误，应移到可抛错的安装阶段。
3. **P1 UI**：在 macOS 12/14/26 分别核对经典与原生主题的侧栏/主区域/顶栏，测量亮暗壁纸下文本对比度、Reduce Transparency、Reduce Motion、窗口失焦及 Cmd+Tab；由截图和可访问性结果再调整 tint，不凭代码推断“已修好”。
4. **P1 性能**：用 Instruments 的 Time Profiler、Allocations、SwiftUI View Body、Core Animation 对首屏、实例列表滚动、主题切换、文件扫描建立基线；定位后再优化，避免盲目缓存或模糊层叠。
5. **P1 测试分层**：把纯离线单元测试和在线下载/本机 Java 探测分组；CI 默认只跑离线组，在线测试显式启用并设超时/资源上限。Java 探测测试是否调用进程需先审计，不能作为安静环境默认测试。
6. **P2 完整性**：对账户登录、模组/资源包、安装、更新、备份与升级迁移建立功能矩阵和手动验收清单；识别失效服务及缺失流程。

## 本轮验证边界

运行 `xcodebuild test` 的离线筛选：`ArchitectureTests`、`UUIDUtilsTest`、`MinecraftVersionTests`、`ClientManifestTests`、`MyTaskTests`、`LauncherConfigPersistenceTests`。未启动 Minecraft 或 Java 游戏进程；未执行依赖在线资源的测试。没有进行 macOS 26 实机视觉验收或性能剖析。
