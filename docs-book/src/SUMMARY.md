# 目录

- [关于本手册](intro.md)

## 架构

- [系统概览与分层](arch/overview.md)
- [模块清单](arch/modules.md)
- [技术栈与依赖](arch/tech-stack.md)

## 外部接口

- [接口总表](api/inventory.md)
- [网络层与镜像源体系](api/network-layer.md)
- [Mojang 元数据与安装源](api/mojang-metadata.md)
- [Mod 平台与加载器](api/mod-platforms.md)

## 鉴权与 Token

- [账号模型与判别式编解码](auth/account-model.md)
- [正版登录链路](auth/microsoft-chain.md)
- [第三方与离线登录](auth/yggdrasil-offline.md)
- [Token 存储与生命周期](auth/token-storage.md)

## 运行时

- [游戏启动流程](run/launch-flow.md)
- [启动器自更新](run/update-flow.md)
- [配置持久化与 flags](run/persistence.md)

## 风险

- [死依赖与单点](risk/dead-dependencies.md)
- [安全与健壮性发现](risk/security-findings.md)
- [未确认清单](risk/unverified.md)

## 决策记录

- [ADR-001 以 v1.1.1 为基线](decisions/adr-001-baseline.md)
- [ADR-002 工程化改造第一轮：URL 注册表、UI Token 与死链兜底](decisions/adr-002-refactor.md)
- [ADR-003 工程化改造第二轮：Xcode 27 并发范式与工程瘦身](decisions/adr-003-refactor.md)
- [ADR-004 语义 Bug 修复轮：基于用户日志的实证修复](decisions/adr-004-bugfixes.md)
- [ADR-005 下载模式分离与选择互斥审计](decisions/adr-005-download-modes.md)
- [ADR-006 可用性与健壮性扫尾轮](decisions/adr-006-usability.md)
- [ADR-007 主题系统、静态分析基线与复杂度治理](decisions/adr-007-theming-quality.md)
- [ADR-008 与已关闭的直系上游（CylorineStudio/PCL.Mac）切割](decisions/adr-008-upstream-detachment.md)
- [ADR-009 上游身份资产本地化：Bundle ID、数据目录、版本序列与 SwiftScaffolding vendor](decisions/adr-009-own-identity.md)
- [ADR-010 微软登录 client_id 处置：Prism 公共 ID + 构建期注入通道](decisions/adr-010-ms-client-id.md)
- [ADR-011 移除回声洞与联机功能，全面替换上游痕迹](decisions/adr-011-remove-upstream-features.md)
- [ADR-012 产品更名：PCL.Mac → PCL Mac CE（保留 PCL 前缀）](decisions/adr-012-rename-pcl-mac-ce.md)
