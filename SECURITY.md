# 安全政策

## 支持的版本

| 版本 | 支持状态 |
|---|---|
| 1.2.x（PCL Mac CE） | ✅ 接受安全报告 |
| ≤ 1.1.1（原 PCL.Mac 上游历史版本） | ❌ 上游已停止维护，不再处理 |

## 上报漏洞

请优先使用 GitHub 仓库的 **Security → Report a vulnerability**（私密漏洞上报）通道；
若该入口不可用，请创建 Issue 并 @JUANWANG-BUAA，请在修复前**不要公开利用细节**。

报告中请尽量包含：复现步骤、影响范围（账号 / 令牌 / 文件系统 / 网络）、
系统与启动器版本、相关日志（注意先自行抹除其中的令牌与个人信息）。

## 敏感数据处置说明（现状）

- 账号令牌（Microsoft / Yggdrasil）保存在本地配置文件
  `~/Library/Application Support/PCLMacCE/config.json`，为明文存储——请勿将配置文件
  上传到 Issue、网盘或任何公共位置；
- 日志（`…/Logs/`）不含令牌；导出的崩溃报告仅含启动器版本、Java 与实例信息；
- 可选的密钥项（CurseForge key、微软登录 client ID 覆盖）通过
  `Resources/Secrets.properties` 或环境变量 `PCLMAC_*` 注入，不随仓库分发；
- 本项目的网络请求目标清单见 `PCLMacCE.Core/Utils/APIEndpoints.swift` 与 `WebLinks.swift`。

## 响应预期

本项目为个人独立维护的开源项目，无 SLA 承诺；收到报告后会尽力在下一个版本修复，
并在 `CHANGELOG.md` 与相关 ADR 中公开处置结论（在漏洞修复后）。
