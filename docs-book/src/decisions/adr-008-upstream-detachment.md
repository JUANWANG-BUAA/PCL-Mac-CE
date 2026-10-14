# ADR-008 与已关闭的直系上游（CylorineStudio/PCL.Mac）切割

| 项 | 值 |
|---|---|
| 日期 | 2026-10-14 |
| 状态 | 已实施（维护者身份已归位；本项目公开仓库与更新源待定） |
| 相关 | [ADR-001](adr-001-baseline.md)（基线决策）、[死依赖与单点](../risk/dead-dependencies.md) |

## Context

直系上游 `CylorineStudio/PCL.Mac.Refactor` 于 2026-08-24 起转为私有（时间线见 ADR-001），
其官网与 Pages 站点删除、更新源 `meta/PCL.Mac/update.json` 404、头像图源随主域一并下线。
但产品与文档里仍挂着该项目的身份与入口：

| 残留 | 位置 |
|---|---|
| 欢迎弹窗：官网 / 隐私政策链接与按钮 | `AppDelegate` 首次启动流程 |
| 关于页：风花 / Cylorine Studio 两行（死链按钮 + 图裂头像）、自身行的死链 | `AboutPage` |
| 光影教程、联机帮助、回声洞投稿、更新失败"反馈" | 各页面与 `WebLinks` |
| 自更新源 | `UpdateManager`（必然失败） |
| README 徽章 / 用户群 / Releases 链接（均已死） | `README.md` |

两层上游必须区分处置：**许可与品牌源头 PCL（龙腾猫跃，Hex-Dragon/PCL2，仍活跃）不可切割**——
《PCL 分发有限许可》只授权"原样副本"分发，修改版的安全依据是《存储库合理使用指南》对
"重度使用"的不追究承诺，其条件**要求**保留 PCL 署名（关于页首位 + 赞助链接）、
开源、不得"去 PCL 化"改名。本 ADR 的切割对象仅限 CylorineStudio 的原 PCL.Mac 项目。

## Decision

1. **移除全部指向原上游的入口**（已死的链接、私有服务、图裂头像）：欢迎弹窗两个按钮、
   关于页两个作者行与其全部按钮、光影/联机帮助、回声洞投稿句、更新失败"反馈"按钮、
   README 徽章与死链。不做替代性跳转、不伪造本项目尚不存在的地址。
2. **关于页保留一行事实性基线说明**（"原项目由风花AnemoFlower 与 Cylorine Studio 开发，
   已停止公开开发；本版本基于其 v1.1.1 代码基线独立维护"），不再提供其仓库/官网/赞助按钮；
   龙腾猫跃行保持首位与赞助链接不变（许可要求）；`PCL.Mac.Core` 的 MIT 与
   `Resources/licenses/` 三方许可声明全部保留。
3. **自更新链路加闸门**：`UpdateManager.isSourceConfigured = false`——不发起死请求；
   手动检查提示"更新源迁移中"；本项目新更新源部署后一处开启。
4. **死端点保留为历史记录**：`WebLinks.CylorineSite` / `APIEndpoints.CylorineSite` 加 ⚠️
   注释后原地保留（遵循 ADR-002 的"死链不删除"约定），但不再被任何 UI 引用；
   本项目自己的站点/仓库确定后另建命名空间登记。

## Consequences

**正面**：产品内不再有死链与图裂入口；身份与原团队解耦，消除"仍有官方支持"的误导；
更新链路不再每次启动打无效请求。

**待办（公开仓库确定后一次补齐）**：
- README 徽章与下载链接、关于页自身行的仓库/官网按钮；
- `githubDiscussion()` 的替换（新仓库的 Discussions）；
- 更新源部署 → `isSourceConfigured = true` + 换地址；
- 本站隐私政策（若继续收集账号信息）。

## 维护者归位（同日补记）

原项目停更后，本版本由 **JUANWANG（[github.com/JUANWANG-BUAA](https://github.com/JUANWANG-BUAA)）
接手独立维护并持续开发**。身份已在三处标注：

| 触点 | 标注 |
|---|---|
| 关于页 | 新增维护者行（GitHub 头像 + 主页按钮 + "PCL.Mac 社区维护版的维护者 · 持续开发中"） |
| 欢迎弹窗 | "本版本现由 JUANWANG（github.com/JUANWANG-BUAA）独立维护并持续开发" |
| README | 维护状态块（@JUANWANG-BUAA 接手独立维护并持续开发） |

本项目的公开仓库、徽章、下载渠道与更新源仍待确定（见上方待办）。

## 切割边界备忘（勿越界）

- **保留**：`LICENSE`（《PCL 分发有限许可》）全文、Core 的 MIT 声明、三方许可清单
  （含 SwiftScaffolding）、关于页龙腾猫跃行、色板出处注释、ADR 中的基线事实记录。
- **不可做**："去 PCL 化"式改名（会失去指南对重度使用的保护）。
- **资产注意**：`Resources/PCL.ttf`（PCLEnglish 品牌字体）随"软件"受 PCL 许可约束，
  改名/再分发时其处置须随 LICENSE 一并考虑，不可当自有资产。
- **后续依赖**：`api.cylorine.studio`（回声洞 / EasyTier 节点）是作者私有设施，
  仍存活但不属于本项目的长期依赖，迁移或下线计划见 [自有后端](../api/own-backend.md)。

验证：构建 ✅ · 全量测试 ✅ · SwiftLint 修改文件 0 违规。
