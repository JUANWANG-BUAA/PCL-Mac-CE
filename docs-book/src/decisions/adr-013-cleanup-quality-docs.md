# ADR-013 上游残留二次清除、质量治理归零与开源工程文档补全

| 项 | 值 |
|---|---|
| 日期 | 2026-10-15 |
| 状态 | 已实施 |
| 相关 | [ADR-009](adr-009-own-identity.md)（Superseded-by 本 ADR 的 vendor 决策）、[ADR-011](adr-011-remove-upstream-features.md)、[ADR-007](adr-007-theming-quality.md)（质量基线） |

## Context

ADR-008～012 完成了上游切割的主体（UI 入口、构建依赖、登录凭据、私有后端、命名），
本轮对全仓做最终普查，发现四类遗留：

1. **依赖级遗留**：`Vendor/SwiftScaffolding` 在联机功能移除后仅剩一个 `Logger.enableLogging`
   调用——该库已无实际日志产出，整个依赖（含其许可条目与 `Resources/licenses/` 声明）
   成为纯粹的维护负担；
2. **功能级遗留**：`ClientManifest.oldVersionFlag` 的 JVM 标记仍是上游域名
   （`-Dtop.cylorinestudio.cl.OldVersionFlag=1`）；
3. **资产级遗留**：`AnemoFlower` 头像 imageset 已无引用；App 图标与关于页产品头像
   仍是旧 "PCL Mac" 视觉；标题栏标签仍为 "Mac"；
4. **质量基线遗留**（ADR-007 时期已知接受）：SwiftLint 57 条、编译警告 4 条、
   4 个 TODO（其中 2 个是强制解包安全项）、7 个 60–91 行函数（最长 91）。

## Decision

**1. SwiftScaffolding 依赖完全移除**（取代 ADR-009 的 vendor 决策）
删除 `Vendor/`、pbxproj 全部引用、AppDelegate 的日志启用调用、
`Resources/licenses/SwiftScaffolding.LICENSE.txt` 与关于页许可条目。
本项目对 `CylorineStudio` 名下代码、资产、许可的依赖至此为**零**。

**2. 标记自有化**：`oldVersionFlag` → `-Dpclmacce.OldVersionFlag=1`；
读取时兼容上游旧值（`legacyOldVersionFlag`），历史清单不丢识别。

**3. 资产清理与重绘**：删除孤儿 `AnemoFlower` 头像；App 图标重绘为
"PCL + CE" 同风格（渐变圆角方 + 六边形晶格，PIL 生成 512/1024 两档并补齐
512@2x 资产位）；关于页产品行头像同步换新；标题栏标签 "Mac" → "CE"；
关于页文本修正（"PCL Mac CE 社区维护版"）。

**4. 质量治理归零**（全部按本项目 `.swiftlint.yml` 规范执行）：

| 项 | 前 | 后 |
|---|---|---|
| SwiftLint 违规 | 57（长行 43 / 长函数 6 / 类型体 1 / TODO 4 / 其它） | **0** |
| 编译警告 | 4（Sendable ×3、死 default ×1） | **0** |
| 安全 TODO（强制解包） | 2 | 安全可空 + 占位态 |
| 依赖 | 4 个 SPM 包 | 3 个（SwiftyJSON / ZIPFoundation / TOMLDecoder） |

主要手法：长行换行或拆分字面量（含 base64 分块）；`MinecraftInstanceLoader`、
`MinecraftLaunchTask`、`MinecraftInstallTask`、`ResourceLoadService`、
`ResourceInstallViewModel`、`AccountViewModel` 六个函数按语义拆分子函数；
`MinecraftLaunchTask` 类型体以扩展切分；`InstanceConfigViewModel.instance`
改为可空（跨仓库查找 + 页面占位态）；`InstanceListViewModel` 仓库查找带回退；
测试夹具单行 JSON 用定点豁免并注明理由；CurseForge 远程查源的 TODO 转为
明示局限说明（官方指纹接口需 Authorized key，暂不纳入）。

**5. CI 门禁**：`pr-test.yml` 增加 `<redacted>` job
（`swiftlint lint --config .swiftlint.yml --strict`），质量基线不允许回退。

**6. 开源工程文档补全**：新增 `CONTRIBUTING.md`（开发环境、构建/测试/规范、
提交与 ADR 流程）、`SECURITY.md`（漏洞上报、令牌与密钥处置）、
`CHANGELOG.md`（1.2.0 起自有变更史，此前版本指向上游）、
`.github/CODEOWNERS`（维护者 @JUANWANG-BUAA）、
`.github/PULL_REQUEST_TEMPLATE.md`。README 的截图与完整重写待独立一轮完成。

## Consequences

- 仓库对外部闭源/停更方的依赖全部清零：代码零引用、资产零引用、许可清单零引用；
- 质量基线从"已知接受的 57 条"压缩到 0 并受 CI 强制；后续重构有了可回归的护栏；
- SwiftScaffolding 若未来恢复联机功能需重新引入（协议实现已随 vendor 删除，
  但 Scaffolding-MC 为公开协议，重实现无阻碍）。

验证：构建 ✅（0 警告） · 全量测试 ✅ · SwiftLint 0 违规 ·
全仓 grep `SwiftScaffolding / cylorinestudio / AnemoFlower` 仅剩历史文档。
