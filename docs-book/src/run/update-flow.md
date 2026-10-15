# 启动器自更新

**现状前提：这条链路的元数据源已经 404**（`cylorine.studio` 整站删除），所以 v1.1.1 的自更新在真实环境里**永远不会成功**。下面描述的是代码逻辑本身。

## 触发

| 入口 | 位置 |
|---|---|
| 启动后自动 | `App/AppDelegate.swift:169` → `UpdateService.shared.runInteractiveUpdateFlow()`（`manually: false`） |
| 设置页手动 | `Views/Settings/OtherSettingsPage.swift:47-48` → `runInteractiveUpdateFlow(manually: true)` |
| "不再提示" | 弹窗第 3 个按钮（id=2）→ 置 `LauncherConfig.ignoreLauncherUpdates = true`（`Services/UpdateService.swift:56`） |

流程编排在 `Services/UpdateService.swift:16-76`：非手动且 `ignoreLauncherUpdates` 时直接跳过（`:17-20`）；`AsyncSemaphore` 保证单飞（`:14,22-23`）；发现新版本弹窗列出 `updateLogLinks` 各按钮 + 显示包体积（`:44-66`）。

## 短路条件（本地构建永不更新）

`Managers/UpdateManager.swift:23`：

```swift
if debugMode || Metadata.bundleVersion == 0 { return nil }
```

- `debugMode` 来自 Info.plist 的 `DebugMode` 键（`Configs/Debug.xcconfig:2` → `Debug` 配置为 `YES`）。
- `Metadata.bundleVersion` 读 `CFBundleVersion`；`Configs/Base.xcconfig:2` 里 `CURRENT_PROJECT_VERSION = 0`，**只有 CI 在命令行覆盖成 GitHub run 号**（`.github/workflows/build.yml:66-71`）。

**结论：用 `xcodebuild` 在本机构建的 app，`bundleVersion` 恒为 0，自更新逻辑被设计性地关闭。** 想在本地验证更新流程必须显式传 `CURRENT_PROJECT_VERSION=1`。

## 比较规则

`UpdateManager.swift:25`：

```swift
Metadata.bundleVersion >= model.latestVersion.bundleVersion ? nil : model.latestVersion
```

- **只比 `bundleVersion` 整数**，`name`（如 "1.1.1"）纯展示、不参与判断。
- 所以语义版本回退（1.2.0 → 1.1.5）在这套机制下不会被识别为"需要降级"，也不会被阻止——只要整数变小就不提示。
- JSON 契约类型为 `Models/UpdateModel.swift`：**全部字段必填**，缺任何一个键则整体解码失败。

## 下载与校验

`UpdateManager.swift:28-36`：

1. `useMirror` 决定取 `downloads.mirror` 还是 `downloads.github`（`:28,31`）；调用方用 `LocaleUtils.isInChinaMainland(strict: false)` 决定（`UpdateService.swift:69-70`）——**注意这里 strict=false**，判定失败时倾向走镜像。
2. 临时目录 `Temp/launcher-update-{bundleVersion}`（`:29`），`defer` 删除（`:35`）。
3. 走 `FileDownloader`，校验算法是 **SHA-1**（`DownloadItem(..., sha1: version.downloads.sha1)`，`:31-34`）。
4. `size` 字段用于弹窗展示。

> 现状不一致点：`UpdateModel` 同时要求提供 `size` 与 `sha1`，但 `FileDownloader` 的校验只认 checksum；`size` 不参与完整性判定。

## 安装替换

`UpdateManager.swift:37-47`：

```
解压 zip 到 Temp                                    :37
要求解出 Temp/PCL.Mac.app，否则抛"更新包格式错误，请手动安装"  :38-41
FileManager.replaceItemAt(
    Bundle.main.bundleURL,                          ← 原地替换，不搬家
    withItemAt: newBundle,
    backupItemName: "PCL.Mac.app.backup",
    options: [.usingNewMetadataOnly])               :42-47
/usr/bin/open -n <当前 Bundle> 起新进程              :49-55
NSApplication.terminate                             :49-55
```

现状特征与缺口：

| 项 | 现状 |
|---|---|
| 提权 | **无**。不提权、不装到 `~/Applications`、不移动位置 |
| 前置条件 | 当前 `.app` 所在目录必须**可写**。装在 `/Applications` 且属 root 时替换会失败 |
| 失败回滚 | 只留下 `PCL.Mac.app.backup`，**没有自动回滚代码**；失败靠提示用户手动安装 |
| 签名/公证 | 更新包由服务端 URL 决定，客户端不校验代码签名，只校验 SHA-1 |
| 重启 | `open -n` 起新实例后再 terminate 自己，所以短暂存在两个进程 |

## 与"钥匙串交接"无关

再次强调：网上流传的"更新安装前的钥匙串权限交接 / 一次授权安装到 ~/Applications"是**另一个同名项目**（白枫的 Bug Craft Launcher）的发布说明，本仓库既无钥匙串也无提权安装。见[关于本手册](../intro.md#一处需要特别纠正的常识)。
