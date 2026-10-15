# 贡献指南

感谢你愿意为 **PCL Mac CE**（PCL Mac Community Edition，技术标识 `PCLMacCE`）贡献力量！
本文覆盖开发环境、代码规范、质量门禁与提交流程；架构与决策背景见 [`docs-book/`](docs-book/src/SUMMARY.md)。

## 开发环境

| 项 | 要求 |
|---|---|
| 系统 | macOS 14.5+（Xcode 16+），支持构建 Universal（Intel + Apple Silicon） |
| 工具链 | Xcode 16 或更高；SwiftLint（`brew install swiftlint`） |
| 依赖 | 仅 3 个 SPM 包（SwiftyJSON / ZIPFoundation / TOMLDecoder），Xcode 自动解析 |

```bash
# 构建
xcodebuild -project PCLMacCE.xcodeproj -scheme PCLMacCE build

# 全量测试
xcodebuild test -project PCLMacCE.xcodeproj -scheme PCLMacCE

# 单个测试
xcodebuild test -project PCLMacCE.xcodeproj -scheme PCLMacCE \
  -only-testing:PCLMacCE.Tests/<ClassName>/<testMethod>

# 代码规范（必须 0 违规）
swiftlint lint --config .swiftlint.yml --strict
```

> 测试通过 `Configs/PCLMacCE.xctestplan` 注入 `PCL_MAC_TESTING=1`，数据写入独立的
> `~/Library/Application Support/PCLMacCE/TestHome`，不会污染生产数据。

## 质量门禁（CI 强制）

1. **构建 0 警告**——合并前请确认构建输出无 warning；
2. **全量测试通过**；
3. **SwiftLint 0 违规**（`--strict`），配置见 `.swiftlint.yml`；
4. 不新增强制解包（`!`）与未处理的可空路径；确需例外时用定点豁免并注明理由。

## 代码规范摘要

完整约定见 [`CLAUDE.md`](CLAUDE.md)（英文工程约定），要点：

- **中文优先**：注释、面向用户的文案、提交信息、文档均使用简体中文；
- **命名**：不使用反引号转义类型名；关联枚举用 `Style` / `Kind` 后缀；
- **URL 注册表**：所有远程地址集中在 `PCLMacCE.Core/Utils/APIEndpoints.swift`（程序请求）
  与 `WebLinks.swift`（浏览器打开），禁止在服务与视图里内联 `https://…`；
- **并发**：ViewModel / Manager 为 `@MainActor`；`Core` 暴露给 App 的值类型须 `Sendable`；
  `MyTask` 载体为 `@unchecked Sendable`（有意设计，见 ADR-003）；
- **UI Token**：间距 / 圆角 / 字体 / 语义色使用 `Extensions/DesignTokens.swift`，不写裸值；
- **日志**：使用全局 `log() / err() / warn() / debug()`，禁止 `print`；
- **JSON**：统一使用 `JSONDecoder.shared` / `JSONEncoder.shared`。

## 提交规范

- 提交信息使用简体中文，一条提交只做一件事；
- 建议格式：`类型: 说明`，类型取 `feat` / `fix` / `docs` / `refactor` / `chore` / `test`；
- 涉及行为变更的提交请在正文说明「为什么」，而不是复述「改了什么」。

## 决策记录（ADR）

产品与架构层面的决策（更名、许可、依赖取舍、目录迁移、质量基线变化等）
必须写入 `docs-book/src/decisions/` 并登记到 `SUMMARY.md`。ADR 一经合并即视为历史，
修订旧决策请新增 ADR 并在旧 ADR 中标注（如 "Superseded-by"）。

## 分支与 PR

- 主开发分支为 `dev`；功能/修复请从 `dev` 切出小分支；
- PR 请按模板逐条勾选检查单；`pr-test` 工作流会运行 SwiftLint 与构建；
- 涉及界面的改动请附截图；涉及数据目录 / 配置格式的改动必须给出迁移方案。

## 许可证与署名红线

本项目是 [Plain Craft Launcher](https://github.com/Meloong-Git/PCL) 的第三方衍生作品，
受《PCL 分发有限许可》与《PCL 存储库合理使用指南》约束。**以下内容不得移除或更改**：

- `LICENSE`（《PCL 分发有限许可》）全文；
- 关于页首位的龙腾猫跃署名与赞助链接；
- `PCLMacCE.Core/LICENSE`（MIT）与 `Resources/licenses/` 三方许可声明；
- 产品名须保持 `PCL` 前缀 + 第三方标识（`Mac CE`），不得"去 PCL 化"。

## 维护者

- [@JUANWANG-BUAA](https://github.com/JUANWANG-BUAA)（独立维护）
