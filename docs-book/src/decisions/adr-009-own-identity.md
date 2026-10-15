# ADR-009 上游身份资产本地化：Bundle ID、数据目录、版本序列与 SwiftScaffolding vendor

| 项 | 值 |
|---|---|
| 日期 | 2026-10-15 |
| 状态 | 已实施（外部资源类待办见 ADR-008） |
| 相关 | [ADR-008](adr-008-upstream-detachment.md)（上游切割）、[ADR-001](adr-001-baseline.md)（基线）、[死依赖与单点](../risk/dead-dependencies.md) |

## Context

ADR-008 完成了 UI 入口层面的切割（死链、头像、更新闸门），但仓库内仍有五处
"上游身份"残留在实际运转：构建产物的 Bundle ID 是上游前身的
`org.ceciliastudio.*`；数据目录名 `PCL.Mac.Refactor` 就是上游仓库名；
`MARKETING_VERSION = 1.1.1` 与上游基线同号；崩溃报告与启动日志自称
`PCL.Mac.Refactor`；SPM 依赖 `CylorineStudio/SwiftScaffolding` 仍是远程单点
（其信令服务与仓库均属上游资产，仓库一旦删除则新 clone 构建失败）。
另有一处 ADR-008 的漏网之鱼：`MinecraftInstanceLoader` 仍在调用已 404 的
`cylorine.studio` sha1 版本反查（每次必失败进 catch，白打一次请求）。

## Decision

1. **SwiftScaffolding vendor 化**：按 pin 的 `e5f44ce`（v0.2.1）整包复制到
   `Vendor/SwiftScaffolding/`（剔除 `.git` 与其自身 CI），pbxproj 改为
   `XCLocalSwiftPackageReference`，`Package.resolved` 移除该 pin。MIT 许可
   允许再分发，`LICENSE` 与 `Resources/licenses/` 声明保持原样。
   **注意**：vendor 的只是客户端库；联机信令后端仍是上游主机上的服务
   （Scaffolding-MC 公开协议），服务侧依赖见 [自有后端](../api/own-backend.md)。
2. **Bundle ID 换为自有命名空间**：`io.github.juanwang-buaa.pcl-mac`（及
   `.core` / `.tests`，共 6 处配置）。本项目零 `UserDefaults` 使用、配置走
   文件路径持久化，改 ID 无偏好迁移成本；对已装用户仅表现为 LaunchServices
   重新登记（更新器按路径替换 bundle，不受影响）。
3. **数据目录改名 + 一次性迁移**：`Application Support/PCL.Mac.Refactor` →
   `PCL.Mac`（测试目录随之变为 `PCL.Mac/TestHome`）。
   `URLConstants.migrateLegacyApplicationSupport()` 在
   `applicationWillFinishLaunching` 最前（建目录、加载配置之前）执行：
   仅旧目录存在且新目录不存在时原子改名，两者并存时保守不动，失败则降级为
   全新初始化。
4. **版本序列独立**：`MARKETING_VERSION` 1.1.1 → **1.2.0**。1.1.x 及之前
   归上游历史，本维护版本从 1.2.0 起自己的序列，避免更新比较与版本指称混淆。
5. **运行时身份字符串统一为 `PCL.Mac`**：启动日志、崩溃报告的
   `launcher-info.json` 不再自称仓库名。
6. **移除 sha1 版本反查调用**（`detectVersion` 随之去 async 化）：端点定义按
   死链保留约定仍登记在 `APIEndpoints.CylorineSite.versionLookup`。
7. **杂项**：删除已无 UI 引用的 `WebLinks.Afdian.anemoFlower`；issue 模板
   config.yml 移除指向上游私有仓库 Discussions 的死链（新仓库确定后再补）。

## Consequences

**正面**：新 clone 的构建不再依赖任何 `CylorineStudio` 名下的 git 仓库；
安装包身份、数据目录、版本号、崩溃报告全部是本项目的；老用户首次运行新版本
时配置与实例数据经原子改名无缝继承。

**代价与注意**：
- SwiftScaffolding 从"随上游更新"变为"随本仓库更新"，上游若修 bug 需手动
  同步到 `Vendor/`（目前上游已冻结，实际风险趋零）。
- 数据目录迁移是**单向门**：迁移后再装回旧版本会在旧路径全新初始化。
- Bundle ID 变更后，旧版本的 Gatekeeper"已验证"记录不适用于新包，首个
  自发布版本起需要自己的签名/公证（本就列在 ADR-008 待办）。

**仍待外部资源（ADR-008 待办不变）**：OAuth client_id、自更新源与
`isSourceConfigured` 开闸、公开仓库地址（README 徽章 / 关于页自身行 /
Discussions 链接）、CurseForge key、签名证书。

## 切割边界备忘（承 ADR-008，继续有效）

保留：`LICENSE`（PCL 分发有限许可）、Core 的 MIT 声明、三方许可清单
（vendor 后的 SwiftScaffolding 同样保留原始 LICENSE 与版权行）、关于页
龙腾猫跃行首位 + 赞助链接、文件头 `Created by AnemoFlower` 署名（客观
历史，git 历史本就保留）。

验证：构建 ✅ · 全量测试 ✅ · SwiftLint 修改文件 0 新增违规（存量 5 条与 HEAD 一致）。
