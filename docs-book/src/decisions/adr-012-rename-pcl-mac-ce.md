# ADR-012 产品更名：PCL.Mac → PCL Mac CE（保留 PCL 前缀）

| 项 | 值 |
|---|---|
| 日期 | 2026-10-15 |
| 状态 | 已实施 |
| 相关 | [ADR-008](adr-008-upstream-detachment.md)、[ADR-009](adr-009-own-identity.md)、[ADR-011](adr-011-remove-upstream-features.md) |

## Context

原直系上游 `CylorineStudio/PCL.Mac.Refactor` 已停更并转私有，其产品名 **PCL.Mac**
（"PCL" + ".Mac" 点号品牌）仍留在本仓库的工程名、包名、数据目录与界面文案中。
维护者决定与这一已死身份切割，同时**保留 PCL 前缀**——依据《PCL 存储库合理使用
指南》重度使用条款第 2 条（名称须以 Plain Craft Launcher (PCL) 开头 + 足以表现
第三方修改的后缀），保留前缀是继续获得"不追究"承诺的前提。

## Decision

**新名称：PCL Mac CE（PCL Mac Community Edition，社区版）**，技术标识 `PCLMacCE`。

- 命名结构完全对齐指南要求：`PCL`（前缀）+ `Mac CE`（平台与第三方社区版标识），
  与生态既有先例 **PCL2-CE**（PCL2 社区版）同构；
- 与已停更上游 "PCL.Mac" 明确区分（点号品牌不再使用），且不暗示官方出品
  （CE = 第三方社区版，指南禁止的"PCL 手机版 / PCL++ / PCL Pro"式误导不存在）；
- 曾考虑：PCL Mac 社区版（全中文显示名，与 CE 二选一）、PCL Mac Reforged（弃：
  与仓库名 Refactor/Reforged 纠缠易混淆）。

### 技术映射表（旧 → 新）

| 项 | 旧 | 新 |
|---|---|---|
| 产品/显示名 | PCL.Mac | PCL Mac CE |
| Xcode 工程/目标 | PCL.Mac{,.Core,.Tests} | PCLMacCE{,.Core,.Tests}（`import Core` 不变；Core 的 PRODUCT_NAME 仍为 `Core`） |
| 工程文件 | PCL.Mac.xcodeproj / PCL.Mac.xctestplan / PCL_Mac.entitlements | PCLMacCE.xcodeproj / PCLMacCE.xctestplan / PCLMacCE.entitlements |
| Bundle ID | io.github.juanwang-buaa.pcl-mac{,.core,.tests} | io.github.juanwang-buaa.pclmacce{,.core,.tests} |
| 数据目录 | `~/Library/Application Support/PCL.Mac` | `…/PCLMacCE`；迁移链覆盖两级历史目录（`PCL.Mac` → `PCL.Mac.Refactor`，取最新存在者） |
| 自更新包名 | PCL.Mac.app / .backup | PCLMacCE.app / .backup |
| CI 工件 | PCL.Mac-* / PCL.Mac.app / PCL.Mac.zip | PCLMacCE-* / PCLMacCE.app / PCLMacCE.zip |
| 文件头注释 | `//  PCL.Mac` | `//  PCLMacCE` |
| 界面文案 | "PCL.Mac"（窗口标题/欢迎/日志/报错/崩溃报告/关于页自身行） | "PCL Mac CE" |

**不改动（PCL 前缀保留的范围内）**：

- `Resources/PCL.ttf`（PCLEnglish 品牌字体）**继续随包分发**：产品保留 PCL 前缀，
  字体属"软件"资源的正常使用（ADR-008 边界备忘的处置原则延续）；
- `Font.pcl` / `PCLEnglish` 字体注册与全部调用点、标题栏 PCL 字母字标（iconTitleLogo）、
  主题显示名"PCL 经典"、`PCLMAC_` Secrets 前缀、`PCL_MAC_TESTING`、通知名
  `PCLMac.*`——均与 PCL 品牌体系一致，保持原样（零扰动）；
- 关于页龙腾猫跃行（首位 + 赞助链接）、原 PCL.Mac 基线致谢行、"PCL Community /
  PCL.Proto"鸣谢、`LICENSE` 全文、Core 与三方许可——全部保留。

### 合规自检（指南重度使用五条）

1. 第三方二创声明：README / 欢迎弹窗 / 关于页 ✅（本次更名同步更新措辞）
2. 名称以 PCL 开头 + 第三方后缀 ✅（本 ADR 的核心动作）
3. 关于页首位龙腾猫跃署名 + 赞助、开源、附指南文件 ✅
4. 正版购买劝导与赞助劝导 ✅（启动次数弹窗、离线登录需正版验证）
5. Windows 蓝色主色相条款：仅 macOS，N/A ✅

### 历史文档约定

docs-book 历史章节（ADR-001…011）中的 `PCL.Mac` 等字样按**引用当时快照**理解，
不回写；`intro.md` 顶部已加命名说明；`CLAUDE.md`（操作性文档）已全量更新。

## Consequences

- 产品身份与已停更上游切割干净：工程、产物、数据目录、界面全部为自有名称，
  同时保留 PCL 前缀与全部署名，落入指南的重度使用保护范围；
- 老用户首次运行新版时数据目录自动迁移（`PCL.Mac` / `PCL.Mac.Refactor` → `PCLMacCE`），
  字体、图标、主题观感均无变化；
- 遗留（非阻塞）：App 图标 / README 配图 / DMG 背景等位图资产仍为旧版视觉，
  可按需重绘（不影响功能与合规）。

验证：构建 ✅ · 全量测试 ✅ · SwiftLint 修改文件 0 违规 ·
全仓 `PCL.Mac` 仅剩历史路径（`PCL.Mac.Refactor`）、历史文档与上游仓库名引用。
