<div align="center">
  <img alt="Logo" src=".github/assets/icon.png" width="140">
  <h1>PCL Mac CE</h1>
  <img src="https://img.shields.io/badge/macOS-12.0+-blue?logo=macos" alt="Minimum OS Version">
</div>
<br>

PCL Mac CE 是基于 [Plain Craft Launcher（PCL）](https://github.com/Meloong-Git/PCL) 的第三方 macOS 启动器，由 [JUANWANG-BUAA](https://github.com/JUANWANG-BUAA) 独立维护。项目使用 SwiftUI 构建，拥有独立的界面设计、图标、发布流程和用户支持渠道。

> **项目关系**：本项目与此前的 PCL.Mac 项目及其维护团队没有隶属或继承关系。当前代码以旧项目 v1.1.1 作为历史起点，此后的产品决策、界面、维护和发行均由本项目独立负责。PCL Mac CE 与 PCL 官方也没有隶属关系；PCL 来源及许可说明见下方许可证章节。

感谢此前 PCL.Mac 项目贡献者公开 v1.1.1 代码，为本项目提供历史代码起点。

问题反馈请使用本项目的 [Issue 页面](https://github.com/JUANWANG-BUAA/PCL-Mac-CE/issues)，不要提交到 PCL 官方或其他衍生项目。

## 下载

项目发布页：[PCL Mac CE Releases](https://github.com/JUANWANG-BUAA/PCL-Mac-CE/releases)。首个版本尚未正式发布；正式下载仅以该页面的签名、公证安装包为准。

维护者下一步应配置 Apple 签名与公证凭据、运行发布工作流生成草稿、在 Intel 和 Apple 芯片上验收安装包，再公开发布。操作步骤和检查项见[发布操作手册](docs-book/src/run/release-playbook.md)。首版暂保持 1.2.0，完成验收前不发布正式版本。

## 环境要求

|          |          最低           |    推荐     |
|:--------:|:-----------------------:|:-----------:|
| 普通使用 |       macOS 12.0        | macOS 14.0+ |
|   开发   | macOS 14.5 (Xcode 16) |      —      |

同时支持 Intel 与 Apple 芯片。

## 许可证
- PCL Mac CE 使用与 [PCL](https://github.com/Meloong-Git/PCL) 相同的许可证（见 `LICENSE`），并遵守其中关于“重度使用”的规定：关于页首位保留龙腾猫跃署名与赞助链接，已实现 Minecraft 正版购买劝导，名称以 PCL 开头并带第三方标识（Mac CE）。
- PCLMacCE.Core（`PCLMacCE.Core/`）采用 MIT License 协议，使用其代码时请**保留许可证**及署名信息。
- 历史代码来源与对 PCL.Mac v1.1.1 贡献者的致谢见[来源说明](Resources/licenses/PCL-Mac-CE-Baseline-Notice.txt)；该说明不替代上述许可证。
