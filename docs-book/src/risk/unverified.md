# 未确认清单

代码里读不出结论、需要实测或外部信息才能确定的事项。**写文档时一律标注，不猜。**

## 需要实机验证

| # | 事项 | 线索 | 怎么验 |
|---|---|---|---|
| U1 | 1.12- 老清单的 `--accessToken` 是否根本没被替换 | 老式占位符是 `${access_token}` / `${profile_name}`，而 values 字典只有 `auth_access_token` / `auth_player_name`（`Core/Minecraft/Launch/MinecraftLauncher.swift:25-43`、`Core/Models/ClientManifest.swift:73-83`） | 装一个 1.8.9 实例启动，看日志里的 argv |
| U2 | `--clientId ${clientid}` / `--xuid ${auth_xuid}` 字面量进 argv 是否影响 1.20.2+ 实际启动 | 无值供给、无 rules 保护 | 1.20.5 实例启动并观察游戏是否报参数错 |
| U3 | `URL.appending(path:)` 对带尾斜杠的 `authServerURL` 拼接 `/authserver/…` 的归一化行为 | `YggdrasilService.swift:216` | 用尾斜杠地址添加第三方账号 |
| U4 | authlib-injector 官方 `artifact/N.json` 实际给哪几种 checksum 键 | 代码支持 sha1/256/512（`Core/Utils/FileUtils.swift:52-64`） | `curl https://authlib-injector.yushi.moe/artifacts.json` 后取最新 build 的 json |
| U5 | 游戏进程自身是否会把 token 打进 stdout（从而进日志） | 取决于 MC 版本，本仓库不控制 | 启动后查 `Temp/game-log-*.log` |
| U6 | 整合包实际支持哪些压缩格式（7z / rar / tar / tgz） | 只有 ZIPFoundation 在依赖里（`Core/Extensions/Archive+EntryExtract.swift`），但 `ModpackIndex.Format` 有 4 种 | 逐个拖入测试 |
| U7 | `replaceItemAt` 在 `/Applications` 下（root 属主）是否必然失败 | `Managers/UpdateManager.swift:42-47` 不提权 | 需真实 update.json 才能测（本地构建 `bundleVersion==0` 会短路） |

## 需要外部信息

| # | 事项 | 说明 |
|---|---|---|
| ~~U8~~ | ~~SwiftScaffolding 的信令后端主机~~ | **已随联机功能移除失效（ADR-011）**；库已 vendor 仅余日志能力 |
| U9 | 上游是否还有 v1.1.1 之后的提交 | 上游已私有；2026-10-07 镜像仓库合并时 tip 仍是 `416cde3`（v1.1.1，2026-08-24），此后不可见 |
| ~~U10~~ | ~~`api.cylorine.studio` 的运维归属与关停计划~~ | **已随功能移除失效（ADR-011）**，本项目不再请求该域 |
| ~~U11~~ | ~~EasyTier 关房私钥的持有者范围~~ | **已随联机功能移除失效（ADR-011）** |
| U12 | 《PCL 分发有限许可》对"个人自用的本地分支"的边界 | 需读 `LICENSE` 原文并咨询，属法律问题不是代码问题 |

## 已排除的"伪事项"

这些一度被怀疑，但已确认**不成立**，不必再查：

- ~~钥匙串存储令牌~~ → 全仓零 Keychain（见[Token 存储](../auth/token-storage.md)）。
- ~~"更新安装前的钥匙串权限交接"、"设置导入导出"、"访客/信任模式"~~ → 均不属于本仓库，是另一个同名项目（白枫 / Bug Craft Launcher）的发布说明。
- ~~`PCL.Mac.Core` 依赖 UI~~ → 83 个文件里 `import SwiftUI` 命中数为 0。
- ~~存在集中的 base URL 配置~~ → 没有，`URLConstants.swift` 全是本地路径。
