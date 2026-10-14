# 技术栈与依赖

## 语言与工具链

| 项 | 值 | 出处 |
|---|---|---|
| 语言模式 | **Swift 5**（`SWIFT_VERSION = 5.0`） | `PCL.Mac.xcodeproj/project.pbxproj` 各 buildSettings |
| UI | SwiftUI 为主 + AppKit 混用（`NSWorkspace`、`NSApplication`、`NSOpenPanel`、`NSWindowDelegate`、`SecureField`） | `App/AppWindow.swift`、`App/AppDelegate.swift` |
| 最低系统 | App 与 Core 均 `MACOSX_DEPLOYMENT_TARGET = 12.0`；测试 target 14.0 | 同上 |
| 架构 | Universal（Intel + Apple Silicon）；运行时按 `Architecture.systemArchitecture()` 分派 | `Core/Utils/Architecture.swift` |
| 签名 | `CODE_SIGN_STYLE = Automatic`（本地）；CI Release 改 Manual + `ENABLE_HARDENED_RUNTIME=YES` | `.github/workflows/build.yml:74-84` |
| 公证 | `notarytool` + `MACOS_NOTARY_APPLE_ID/PASSWORD/TEAM_ID` | `.github/workflows/release.yml:44-48` |
| 本机实测 | Xcode 27 / macOS 27 上 `xcodebuild` **编译通过，0 error**，5 类代码告警 | 见[风险章](../risk/security-findings.md) |

> **Swift 5 模式是理解那批告警的前提**：`unstructured throwing task 未使用`、`weak 捕获与外层强捕获不一致`、`isolated conformance 传入 @concurrent` 在 Swift 6 语言模式下大概率是 error。也就是说这份代码在作者时代是"能过"的，切到 Swift 6 模式会直接编不过。

## 版本标识（很重要，决定自更新是否生效）

| 字段 | 来源 | 值 |
|---|---|---|
| `MARKETING_VERSION` | `Configs/Base.xcconfig:1` | `1.1.1` |
| `CURRENT_PROJECT_VERSION` | `Configs/Base.xcconfig:2` | **`0`** |
| `DebugMode` | `Configs/Debug.xcconfig:2` → `Info.plist:4-5` | Debug 配置为 `YES`，Release 为 `NO` |
| CI 实际 build number | `.github/workflows/build.yml:66-71` | 命令行覆盖成 `BUILD_NUMBER`（GitHub run 号） |

推论（已核对代码路径）：**本地 `xcodebuild` 构建出来的 app，`CFBundleVersion` 是 0**，而 `UpdateManager.swift:23` 在 `debugMode || bundleVersion == 0` 时直接返回 nil 不检查更新。所以本地开发构建**永远不会触发自更新**，这是设计而非故障。

## SPM 依赖（只有 4 个）

| 包 | 版本 | 用途 | 备注 |
|---|---|---|---|
| [SwiftScaffolding](https://github.com/CylorineStudio/SwiftScaffolding) | 0.2.0 | 红石联机（Scaffolding-MC）协议的 Swift 实现 | 作者自己的库，**仍是公开仓库**；其信令后端主机在本仓库不可见 |
| [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) | 5.0.2 | 宽松 JSON 解析 | `HTTPClient.Response.json()` 的返回类型 |
| [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | 0.9.20 | zip 解压（整合包、自更新包） | `Extensions/Archive+EntryExtract.swift` |
| [TOMLDecoder](https://github.com/dduan/TOMLDecoder) | 0.4.4 | 解析 mods.toml（Forge 模组元数据） | `Services/Resource/Parsers/ModParser.swift` |

依赖面极小是这个项目"能被改"的一个直接原因：没有 Alamofire、没有 SwiftPM 复杂解析规则、没有代码生成。

## 外部二进制依赖（不在包体内，运行时下载）

| 二进制 | 来源 | 版本固定方式 | 校验 |
|---|---|---|---|
| EasyTier `easytier-core` / `easytier-cli` | `gitee.com/yizhimcqiu/easytier-mirror` v2.5.0 | **URL 里写死 v2.5.0** | **SHA-1 硬编码在源码**（`Managers/EasyTierManager.swift:31,36,44,49`），按 arm64/x86_64 各一份 |
| `authlib-injector.jar` | `authlib-injector.yushi.moe` | 取 `artifacts.json` 里 `build_number` 最大者 | 服务端下发的 `checksums`，本地支持 sha1/sha256/sha512（`Core/Utils/FileUtils.swift:52-64`） |
| JRE | 系统 Java / Homebrew / SDKMAN / Mojang `java-runtime` 列表 / 用户手动添加 | `JavaSearcher` + `Configs` | Mojang 运行时的 manifest 走 piston-meta |

## 持久化与网络

- **无数据库**，**无 Keychain**。全部是文件 JSON：`config.json` + 每实例的 `.clconfig.json` / `.clmetadata.json`。见[配置持久化](../run/persistence.md)。
- 网络：`URLSession`。API 请求用 `URLSession.shared`（`Core/Utils/HTTPClient.swift:129`），下载用自建 session（`Core/Services/Download/FileDownloader.swift:11-15`）。
- 编码：`JSONEncoder.shared` / `JSONDecoder.shared`（`Core/Extensions/JSONCoder+Shared.swift`），ISO8601 + 无排序 key。

## 凭据与配置注入

| 项 | 位置 | 现状 |
|---|---|---|
| CurseForge API Key | `Resources/Secrets.properties`，键 `CURSE_FORGE_API_KEY` | 仓库内是**全注释模板**，无真实值；CI 用 heredoc 写入（`build.yml:50-53`，#204 修的就是变量被提前展开） |
| 环境变量优先 | `App/Secrets.swift:30` | `PCLMAC_CURSE_FORGE_API_KEY` 优先于文件 |
| 打包方式 | `project.pbxproj:100-103` | `Resources` 作为同步根组整体进 bundle → **该文件会被拷进 `.app` 内**，任何人可从成品 app 里读出 key |
| 微软 client ID | `Core/Services/MicrosoftAuthService.swift:14` | 硬编码 `dd28b3f2-1db5-49b7-9228-99fdb46dfaca`，`init()` 无参 → **无法换成自己的 AAD 应用** |
| ATS | `PCL.Mac/Info.plist:6-10` | `NSAllowsArbitraryLoads = true` |
| 沙盒 | `PCL.Mac/PCL_Mac.entitlements` | 只有 `app-sandbox = false` 与 `audio-input = true` |

## CI

四个 workflow，`release.yml` 与 `pr-test.yml` 都 `uses: ./.github/workflows/build.yml` 复用同一个构建 job：

| 文件 | 触发 | 作用 |
|---|---|---|
| `build.yml` | 被复用（workflow_call） | 生成 Secrets.properties → 导入证书（仅 Release）→ `xcodebuild archive` → ditto 打包上传 artifact |
| `release.yml` | `workflow_dispatch` | 调 build.yml → 下载 artifact → notarytool 公证 → 建 GitHub Release（含 DMG，#189） |
| `test.yml` | push/PR | 跑 `PCL.Mac.Tests`（注意有会打真实网络的用例） |
| `pr-test.yml` | PR | 复用 build.yml 做编译验证 |

## 许可证现状

- 整体：v1.1.1 起采用 PCL 官方的 **《PCL 分发有限许可》+《PCL 存储库合理使用指南》**（#223 换的），版权方为"成都瓜皮龙科技有限公司"。
- `PCL.Mac.Core/`：**MIT**，使用其代码需保留许可与署名。
- 依赖各自的 MIT / Apache-2.0 / zlib 等许可（`SwiftScaffolding` 用 MIT，见其 LICENSE）。

> 这一条对"能不能二次分发、能不能改名发布"有直接约束，改造前务必读 `LICENSE` 原文。
