# 发布操作手册

独立仓库：[JUANWANG-BUAA/PCL-Mac-CE](https://github.com/JUANWANG-BUAA/PCL-Mac-CE)，默认分支为 dev。当前首版 1.2.0 尚未正式发布。应用内更新只读取该仓库的正式稳定版 Release；草稿和预发布版本不会触发更新。

## 第一步：配置 GitHub Actions Secrets

在仓库的 Settings → Secrets and variables → Actions 中配置：

| 名称 | 用途 |
|---|---|
| MACOS_CERTIFICATE | Developer ID Application 证书导出的 p12 文件的 Base64 内容 |
| MACOS_CERTIFICATE_PASSWORD | p12 导出密码 |
| MACOS_SIGNING_IDENTITY | 对应的完整 Developer ID Application 签名身份 |
| MACOS_SIGNING_TEAM | Apple Developer Team ID |
| MACOS_NOTARY_APPLE_ID | 公证使用的 Apple ID |
| MACOS_NOTARY_PASSWORD | 该 Apple ID 的 app 专用密码 |
| CURSE_FORGE_API_KEY | 可选，启用 CurseForge 服务时配置 |

在持有证书的可信 Mac 上执行 base64 -i certificate.p12 | pbcopy，再将剪贴板内容保存为 MACOS_CERTIFICATE。先确认该证书属于本项目有权使用的团队。执行 gh secret list --repo JUANWANG-BUAA/PCL-Mac-CE 可检查名称是否齐全；它不会显示密钥内容。不要把证书、密码或 API Key 写入源码、文档或资源模板。

缺少签名凭据时，Release 构建会在开始阶段失败；缺少公证凭据时，发布工作流会失败。不要通过移除检查来发布未签名或未经公证的安装包。

## 第二步：冻结版本并检查代码

首版继续使用 Configs/Base.xcconfig 中的 1.2.0，不为跑通 CI 而增加版本。正式发布后，下一个修订版可使用 1.2.1；相应 Release 标签为 v1.2.1。更新器仅比较三段数字版本，高版本正式 Release 才会提示更新。同版本构建不会提示升级。

在准备发布的提交上运行 SwiftLint、完整 xcodebuild test，并确认 git status --short 无未提交改动。检查 README、应用图标、关于页与许可证署名。CI 离线测试仅覆盖部分代码，不能代替实机启动。

## 第三步：生成草稿 Release

在 GitHub 的 Actions → Build and release → Run workflow 中选择准备发布的 dev 提交。工作流运行离线回归测试、签名构建、公证与票据装订，产出 DMG、ZIP 和 SHA256SUMS.txt，最后创建 Draft Release。工作流不会自动公开它。

在 Actions 日志中确认签名、公证、stapler 和代码签名验证均成功。下载草稿附件，核对 ZIP、DMG 的 SHA-256 与 SHA256SUMS.txt 一致。解压 ZIP 或挂载 DMG 后检查 PCLMacCE.app 的 Bundle ID、版本、Team ID 与预期一致；ZIP 根目录须直接包含 PCLMacCE.app。用 codesign --verify --deep --strict、spctl --assess --type execute 和 xcrun stapler validate 验证实际应用包。任何一步失败，都先修复并重新生成草稿。

## 第四步：实机验收和公开

在 Apple 芯片和 Intel Mac 上分别从 DMG 安装，至少验证首次启动、窗口与图标、微软登录、实例创建或选择、游戏下载、游戏启动、配置保存与再次启动。按本次声明的支持范围补测 Yggdrasil、Fabric/Forge 和整合包导入。记录 macOS、芯片、Java 和 Minecraft 版本以及失败项。

全部通过后，复核草稿说明及附件，手动选择 Publish release。公开后用未登录浏览器确认下载链接、校验清单和 releases/latest 可访问。当前仓库没有正式 Release，因此首版发布前检查更新应显示暂无更新。

## 当前限制与后续

- 仓库尚未配置上述 Apple 签名与公证 Secrets，目前不能产出可公开发布的安装包。
- 自动更新按原安装位置替换。目录不可写时会失败，用户需从 Release 页面手动安装；目前没有自动回滚。
- 更新器要求 GitHub ZIP 附件提供 sha256 摘要，且新包签名 Team ID 与当前应用一致。GitHub API 未给摘要时会保守地跳过自动更新。
