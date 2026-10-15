## 变更说明

<!-- 简述这个 PR 做了什么、为什么。涉及界面改动请附截图。 -->

## 关联

<!-- 相关 Issue / ADR（docs-book/src/decisions/）。 -->

## 检查单

- [ ] 构建通过且 **0 警告**（`xcodebuild -project PCLMacCE.xcodeproj -scheme PCLMacCE build`）
- [ ] 全量测试通过（`xcodebuild test -project PCLMacCE.xcodeproj -scheme PCLMacCE`）
- [ ] SwiftLint **0 违规**（`swiftlint lint --config .swiftlint.yml --strict`）
- [ ] 涉及产品/架构决策时，已在 `docs-book/` 补 ADR 并登记 `SUMMARY.md`
- [ ] 面向用户的改动已同步 README / `CLAUDE.md` 中受影响的操作说明

> 提交信息与 PR 描述请使用简体中文。
