# ADR-011 移除回声洞与联机功能，全面退场上游私有后端与痕迹清扫

| 项 | 值 |
|---|---|
| 日期 | 2026-10-15 |
| 状态 | 已实施 |
| 相关 | [ADR-008](adr-008-upstream-detachment.md)、[ADR-009](adr-009-own-identity.md)、[死依赖与单点](../risk/dead-dependencies.md) |

## Context

截至 ADR-009/010，仓库对原上游的实质依赖只剩一块：**回声洞与联机功能所依赖的
`api.cylorine.studio` 私有后端**（`/cave`、`/easytier/*`）与 SwiftScaffolding 信令
服务端——全部运行在上游作者的个人设施上，作者已停止公开开发且无任何关停承诺。
联机功能本身也从未完成（藏在一枚默认关闭的 `multiplayer` feature flag 后面，
连完整的禁用语义都没有，见风险登记 M9/M10）。回声洞内容完全由上游后端下发。

## Decision

**1. 移除两个功能**（连根拔，不做禁用开关）：

| 移除物 | 理由 |
|---|---|
| 回声洞（百宝箱卡片 + `ToolboxViewModel` 台词逻辑 + `CLAPIClient.getCaveMessages`） | 内容源是上游私有后端，无自建计划 |
| 联机（`Views/Multiplayer/` 三页 + `MultiplayerViewModel` + `EasyTierManager` + 路由/侧栏/标题栏入口 + `multiplayer` flag + 配置字段） | 未完成、默认关闭、依赖上游信令与 EasyTier 分发链 |

连带退场：`CLAPIClient` 整个文件、`APIEndpoints.CylorineAPI / CylorineSite /
EasyTier` 三个枚举、`WebLinks.CylorineSite / githubDiscussion`、
`URLConstants.easyTierURL`、`LauncherConfig` 的两个字段（旧配置 JSON 里的
多余键解码时自然忽略，无损）、`Resources/licenses/EasyTier.LICENSE.txt`、
关于页 EasyTier 许可条目。`UpdateManager` 改为地址可空：`shared` 不再携带任何
上游 URL，`isSourceConfigured = false` 闸门语义不变，新源部署后一处登记。

**2. 死端点保留约定作废**：ADR-002 确立的"死链原地保留 + ⚠️ 注释"约定至此完成
历史使命（上游域名全部退场），此后**历史记录归 docs-book（ADR 与风险登记册），
代码注册表只登记活端点**。`CLAUDE.md` 的对应条款已同步修改。

**3. 痕迹清扫**：全仓库 `.swift` 文件头删除 `Created by AnemoFlower` 行
（约 190 文件；`Vendor/` 内第三方代码署名不受影响）；`MyCard` 预览文案中的
上游作者口号（"关注风花喵…"）替换为中性示例文本。git 历史完整保留原始署名，
关于页的事实性基线致谢行按 ADR-008 边界继续保留。

## 后果

**正面**：
- 代码对 `*.cylorine.studio` 的网络依赖**归零**——上游作者关停其个人后端不再
  影响本项目的任何功能；
- 风险登记册 M9/M10、Q1/Q7、U8/U10/U11 全部关闭；
- 联机的未完成 UI 不再以实验开关形式残留在产品里。

**代价**：
- 若未来要恢复联机，需自建或选用非上游的信令服务并重写功能（SwiftScaffolding
  客户端协议实现仍在 `Vendor/`，其 MIT 许可允许复用，但服务端从未属于本项目）；
- 回声洞作为 PCL 生态的情怀功能消失，百宝箱仅剩今日人品。

## 边界备忘（承 ADR-008）

不可移除项维持不变：`LICENSE`（PCL 分发有限许可）、Core 的 MIT 声明与
`Resources/licenses/`、关于页龙腾猫跃行（首位 + 赞助链接）、关于页基线事实行、
`PCL.ttf` 随 LICENSE 的处置约束。产品名 `PCL.Mac` 不改名（重度使用条款）。

验证：构建 ✅ · 全量测试 ✅ · SwiftLint 修改文件 0 违规 ·
全仓库 grep `cylorine|AnemoFlower|EasyTier|Multiplayer|cave` 仅剩本 ADR 等
历史文档与 Minecraft 游戏参数（`is_quick_play_multiplayer`）与 Modrinth 分类名。
