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

- **已修**：普通 CurseForge Mod 的必需依赖现在按所选文件展示；安装时递归解析适配目标 Minecraft / 加载器的前置文件，去重后加入同一下载任务。必需前置缺失、版本不兼容或文件名冲突时会中止，不会只装主 Mod 后假装成功。
- **已修**：实例定向安装页仅保留兼容版本并提供无匹配结果提示；资源筛选器包含快照版本，清单未就绪时仍保留当前实例版本并提供重试。
- **已修**：CurseForge 文件列表翻页读取响应体总数并遍历到服务端上限；依赖工程元数据通过批量接口读取。2026-10-17 使用用户提供的 Key 在线验收 Waystones 必需依赖链：文件声明、批量工程元数据、目标 Minecraft/加载器文件查询均通过；尚未验证客户端下载和真实游戏启动。

- **已修**：无 CurseForge Key 时 Modrinth/普通压缩包本不应被阻止导入；CurseForge 格式仍给出明确缺 Key 提示。
- **已修**：索引路径可含 `..`、绝对路径或符号链接，下载可能写出实例目录；现先校验路径并拒绝 symlink，覆盖目录也校验。
- **已修**：整合包安装重用 Minecraft 安装子任务但未继承失败清理；现在失败时清理版本目录。普通压缩包导入开始时写 `.incomplete`。
- **待审**：同时导入同名实例的竞态；任务失败清理与用户已有目录之间的边界需要并发/故障注入测试。下载代理、解压与实例扫描也需隔离测试。
- **更新渠道现状**：`UpdateManager` 已连接本项目 GitHub `releases/latest`；更新器只接受带 SHA-256 摘要的稳定版 `vX.Y.Z`。草稿和预发布不会被应用内更新发现；当前没有公开 Release，因此检查结果为暂无更新。安装目录不可写时仍需手动安装，替换失败没有自动回滚。
- **发布证据不足**：未测试真实 Microsoft/Yggdrasil 登录、在线下载、Forge/Fabric/NeoForge 安装与启动；未在 macOS 12/14/26 完成手工 UI/签名/公证/DMG 安装验证。图书馆环境不运行游戏或 Java。

## 当前验证证据

- 2026-10-17，Apple Silicon M5 Pro / macOS 27.0.1：完整 XCTest 套件 **53/53 通过**，包含真实 CurseForge 搜索、项目文件和必需依赖链请求；严格 SwiftLint 与 `git diff --check` 通过。
- 发布离线门禁 **23/23 通过**；新增 `ResourceSearchTests` 覆盖文件对目标 Minecraft 版本与加载器的兼容判断，并已纳入 PR 与 Release 工作流。PR 路径筛选现包含 `PCLMacCE.Tests/**`。
- Release 配置成功归档，`1.2.0` App 包含 arm64 与 x86_64 可执行切片。该归档没有 Developer ID Team 签名，不能公证或对外分发。
- 未完成真实 UI 窗口操作、微软/Yggdrasil 登录、客户端下载与游戏启动；macOS 12/14 实机兼容性也未验收。Intel 实机已降为非阻塞项，Universal 构建切片仍保留。

## 发布判断

**仍不建议公开发布安装包，包括 `0.1 α`。** 项目独立版本基线为 `1.2.0`；`release.yml` 固定按此版本创建 `v1.2.0` 草稿，没有 α 预发布流程。仓库还保留历史 `v0.1.x` 标签，因此使用 `0.1` 会与历史版本和现行版本序列混淆。若要邀请用户测试，建议以 `1.2.0-alpha.1` 标记预发布并调整工作流；应用内更新不会发现预发布，测试者需手动下载。

当前 Mac 没有有效 Apple Developer ID 签名身份，GitHub Release Secrets 列表也为空；因此只能生成本地未签名归档，无法公证、创建可验证的 Draft Release 或公开分发。完整测试与在线依赖 API 验收虽已通过，仍需完成 UI/下载/启动验收和 macOS 12/14 兼容性检查。Intel 实机测试不作为本轮发布门槛。
