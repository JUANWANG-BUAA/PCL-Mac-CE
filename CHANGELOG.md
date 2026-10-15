# 更新日志

本项目自 **1.2.0** 起为独立维护序列（更名前为 PCL.Mac 社区维护版）。
1.1.1 及更早版本为原 PCL.Mac 上游的历史版本，其变更记录不在本文件内。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [未发布] 1.2.0 — PCL Mac CE

> 更名后的首个独立版本。相对 1.1.1 基线，本版本聚焦「与已停更上游切割 + 工程质量归零」。

### 变更

- 产品更名为 **PCL Mac CE**（社区版）：PCL 前缀保留（符合《PCL 存储库合理使用指南》
  重度使用条款），工程/目标/数据目录/Bundle ID 全面自有化（`PCLMacCE`），
  老用户数据目录自动迁移（`PCL.Mac.Refactor` / `PCL.Mac` → `PCLMacCE`）（ADR-012）
- 版本序列从 1.2.0 重新起算，与上游版本号脱钩
- 微软登录缺省 client ID 切换为 Prism Launcher 公开的公共客户端 ID，
  支持构建期注入自有 Entra client ID（`MS_CLIENT_ID` / `PCLMAC_MS_CLIENT_ID`）（ADR-010）

### 移除

- **回声洞**与**联机（EasyTier）**功能整体移除：其依赖的上游作者私有后端
  （`api.cylorine.studio`）不属于本项目可维护资产（ADR-011）
- 移除 `SwiftScaffolding` 依赖（vendor 副本、许可声明、日志接入一并清理），
  对外部闭源方的代码/资产/许可依赖归零（ADR-013）
- 移除指向已关闭上游的全部死链入口（官网、赞助、Discussions、更新源、头像图源）（ADR-008）

### 修复

- 上游遗留的 JVM 标记 `-Dtop.cylorinestudio.cl.OldVersionFlag=1` 换为自有命名空间，
  读取兼容旧值，历史清单识别不受影响
- 移除对已下线域名的版本反查调用；实例加载不再打无效请求（ADR-009）
- 「改为安全解包」安全项落实：实例配置页/实例列表页的强制解包改为可空 + 占位态
- 自更新链路加闸门：更新源未配置时不发起请求（新的更新源部署后一处开启）

### 文档与工程

- 新增 `CONTRIBUTING.md`、`SECURITY.md`、`CHANGELOG.md`、`CODEOWNERS`、PR 模板
- CI 增加 SwiftLint `--strict` 门禁；全仓 **0 违规、0 编译警告**
- `docs-book` 新增 ADR-008 ～ ADR-013，记录切割、改名与质量治理全过程

### 许可与署名（保持不变的边界）

- 保留《PCL 分发有限许可》全文、`PCLMacCE.Core` 的 MIT 许可与三方许可声明
- 关于页首位保留龙腾猫跃署名与赞助链接；第三方衍生声明保留
