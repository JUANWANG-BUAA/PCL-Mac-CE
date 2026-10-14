# 关于本手册

## 这是什么

PCL.Mac 的**现状（as-is）**架构手册。只记录"代码现在是怎么做的"以及"为什么现在是这个样子"，**不包含任何改造设计**。改造方案（自建后端、替换正版登录链路等）另开文档。

## 版本基线

| 项 | 值 |
|---|---|
| 分支 | `dev` |
| 提交 | `9c69717` — `release: 1.1.1 (#247)`，2026-08-24 |
| 内容树 | `dd27019e2e43eec2edbd172cc74294a91d23b2da` |
| 等价于 | 上游 `CylorineStudio/PCL.Mac.Refactor` 的 `416cde35`（tree 完全一致，已逐字节校验） |
| 上游现状 | 已转私有，本机凭据不可读；详见 [ADR-001](decisions/adr-001-baseline.md) |
| 维护者 | JUANWANG（[github.com/JUANWANG-BUAA](https://github.com/JUANWANG-BUAA)）——原项目停更后接手，持续开发中；与上游的切割边界见 [ADR-008](decisions/adr-008-upstream-detachment.md) |
| 规模 | 186 个 Swift 文件 / 约 17.9k 行主代码 / 83 个 Core 文件 |

> 注意：`dev` 与 `main`（停在 v1.1.0）**没有共同祖先**——上游历史在镜像仓库里被从根重写过。文件内容可信，SHA 谱系不可信。
>
> 2026-10-14 起，仓库在 ADR-001 基线之上做了工程化改造（URL 注册表、UI Token、EasyTier 多源兜底），
> 与上述基线提交的对应关系已不严格成立，改造内容见 [ADR-002](decisions/adr-002-refactor.md)。

## 事实来源与可信度

全部内容由四路代码考古得出，每条论断都带 `文件:行号`，你可以逐条核对：

- 网络层与外部接口 → [接口总表](api/inventory.md)
- 正版登录链路 → [正版登录链路](auth/microsoft-chain.md)
- 账号模型与非正版登录 → [账号模型](auth/account-model.md)
- 元数据 / 自更新 / 联机 / 持久化 → 对应各章

三类标注约定：

- **未确认** —— 代码里读不出结论，需要实测。汇总在[未确认清单](risk/unverified.md)。
- **已失效** —— 依赖的外部服务已下线。汇总在[死依赖与单点](risk/dead-dependencies.md)。
- **风险** —— 现状可用但有问题。汇总在[安全与健壮性发现](risk/security-findings.md)。

## 一处需要特别纠正的常识

**本项目没有使用 macOS 钥匙串（Keychain）。** 全仓库对 `SecItem` / `kSecClass` / `Keychain` 的引用为 **0**，entitlements 里也没有 keychain-groups。所有登录凭据（含正版的 `accessToken` 与 `refreshToken`）以**明文 JSON** 存在：

```
~/Library/Application Support/PCL.Mac.Refactor/config.json
```

细节见 [Token 存储与生命周期](auth/token-storage.md)。

这个纠正的重要性在于：网上能搜到的"PCL macOS 移植版把令牌存进钥匙串 / 有访客模式与信任模式"这类描述，说的是**另一个同名项目**（白枫的独立移植版，后改名 Bug Craft Launcher），不是本仓库。写文档、排查问题、做安全评估时不要混。

## 怎么读

- 想快速建立整体感：[系统概览与分层](arch/overview.md) → [接口总表](api/inventory.md) → [正版登录链路](auth/microsoft-chain.md)
- 打算动手改代码：先读[风险三章](risk/dead-dependencies.md)
- 想知道某次改动为什么长这样：查对应章节里的"现状原因"小节和 [ADR-001](decisions/adr-001-baseline.md)

## 怎么构建与查看

```bash
cd docs-book
mdbook-mermaid install .   # 一次性：生成 mermaid.min.js / mermaid-init.js（已 gitignore）
mdbook serve --open        # 本地阅读
mdbook build               # 产出到 docs-book/book/（已 gitignore）
```

前置工具：`mdbook`（`brew install mdbook`）与 `mdbook-mermaid`（`cargo install mdbook-mermaid`，Homebrew 没有这个 formula）。

若跳过 `mdbook-mermaid install`，构建会因 `additional-js` 指向的文件不存在而失败；图中的 `mermaid` 代码块在未装预处理器时也会退化成纯文本。
