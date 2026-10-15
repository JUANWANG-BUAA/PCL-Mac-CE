# 仓库结构与发布前检查

## 跟踪的源码与配置

| 路径 | 职责 | 处理原则 |
| --- | --- | --- |
| `PCLMacCE/` | SwiftUI App、路由、组件、主题、ViewModel、交互管理 | UI 层，不把 Minecraft 核心逻辑搬进来 |
| `PCLMacCE.Core/` | 实例/版本/账户模型，下载、安装、启动、API、任务框架 | 不依赖 UI；`LICENSE` 是独立许可文件，不与根许可证合并 |
| `PCLMacCE.Tests/` | Swift Testing；含纯离线测试及联网/本机探测测试 | 发包门禁只运行明确筛选的离线用例 |
| `PCLMacCE.xcodeproj/`、`Configs/` | 工程、部署目标、版本与测试计划 | 改动需同时验证 Debug/Release |
| `Resources/` | 本地化、字体、依赖许可、密钥占位模板 | `Secrets.properties` 仓库版本只有注释模板；实际密钥不能提交 |
| `Packaging/` | DMG 背景与 Finder 布局模板 | `DS_Store` 虽像垃圾文件，但被 release workflow 有意引用，不删除 |
| `.github/` | CI、发布流水线、贡献模板与截图 | 发布只能走签名/公证验证后的草稿流程 |
| `docs-book/src/` | mdBook 文档源、ADR、风险记录 | ADR 是历史记录，不直接改写旧决策 |

`docs-book/book/` 与 `docs-book/mermaid*.js` 是 gitignore 的构建产物，不属于仓库；本轮仅清除了本地未跟踪、空的 `Vendor/` 缓存目录。`Vendor/SwiftScaffolding` 已在 ADR-013 从源码与工程依赖中移除，历史文档提及它不代表当前仍依赖它。目录的视觉冗余不等于可安全删除：先查 pbxproj、工作流、许可再处理。

## 本次功能审计结果

- **已修**：无 CurseForge Key 时 Modrinth/普通压缩包本不应被阻止导入；CurseForge 格式仍给出明确缺 Key 提示。
- **已修**：索引路径可含 `..`、绝对路径或符号链接，下载可能写出实例目录；现先校验路径并拒绝 symlink，覆盖目录也校验。
- **已修**：整合包安装重用 Minecraft 安装子任务但未继承失败清理；现在失败时清理版本目录。普通压缩包导入开始时写 `.incomplete`。
- **待审**：同时导入同名实例的竞态；任务失败清理与用户已有目录之间的边界需要并发/故障注入测试。下载代理、解压与实例扫描也需隔离测试。
- **明确功能缺口**：启动器自动更新源未配置（`UpdateManager.isSourceConfigured == false`），因此发包后用户只能手动更新。
- **发布证据不足**：未测试真实 Microsoft/Yggdrasil 登录、在线下载、Forge/Fabric/NeoForge 安装与启动；未在 macOS 12/14/26 完成手工 UI/签名/公证/DMG 安装验证。图书馆环境不运行游戏或 Java。

## 发布判断

**不建议公开正式版**。可以在具备 Apple 签名/公证凭据的 CI 中构建并检查草稿包；release workflow 现在要求离线回归通过、公证状态为 `Accepted`、stapler 与 codesign 验证，然后才创建 draft。正式发布仍需维护者在非安静环境做安装、登录、启动与升级验收，并确认更新分发渠道/缺 Key 时的功能说明。不要将“构建成功”当作“功能可用”。
