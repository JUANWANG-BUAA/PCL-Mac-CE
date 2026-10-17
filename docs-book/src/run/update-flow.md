# 启动器更新

更新检查指向本项目的 GitHub Releases：`JUANWANG-BUAA/PCL-Mac-CE`。当前还没有正式发布的稳定版；GitHub API 返回 404 时，应用视作暂无更新。草稿和预发布版本不会进入自动更新。

## 触发与版本判断

应用启动后自动检查，设置页可手动检查；用户选择“不再提示”后仅跳过自动检查。Debug 构建或 `CFBundleVersion == 0` 的本地构建不检查更新。

更新器读取 `releases/latest`，只接受严格的 `v主版本.次版本.修订号` 标签。它比较该标签与当前应用的 `CFBundleShortVersionString`，只有较新的稳定版才会提示。发布工作流从 `Configs/Base.xcconfig` 取得版本并创建草稿 Release；正式发布前必须完成签名、公证和实机验收。

## 下载与安装

同一 Release 必须包含名为 `PCLMacCE-v版本.zip` 的应用包，且 GitHub API 为该资源提供 `sha256:` 摘要；缺失摘要时不提供自动安装。下载只使用该 Release 的 HTTPS GitHub 资源地址，不将第三方镜像用于应用更新。下载器用 SHA-256 验证文件。发布工作流还附带 `SHA256SUMS.txt`，供手动核对 ZIP 和 DMG。

ZIP 在独立临时目录解压。安装前检查内部 `PCLMacCE.app` 的 Bundle ID、版本号、代码签名有效性，以及签名 Team ID 是否与当前应用一致。之后在原位置替换应用并重启。当前安装器没有提权；应用所在目录不可写时，自动安装会失败，用户应在 Release 页面手动下载安装。已有替换逻辑会留下 `.backup`，但没有自动回滚。

## 发布前条件

GitHub Actions Release 构建要求签名证书、证书密码、签名身份和 Team ID；公证还要求 Apple ID 与 app 专用密码。缺少这些仓库 Secrets 时，工作流会失败，不应发布未签名或未经公证的安装包。CI 的离线测试不能替代 Apple 芯片 Mac 上的真实安装、登录和游戏启动验收。
