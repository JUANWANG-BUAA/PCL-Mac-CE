# ADR-010 微软登录 client_id 处置：Prism 公共 ID + 构建期注入通道

| 项 | 值 |
|---|---|
| 日期 | 2026-10-15 |
| 状态 | 已实施（自有应用注册后经注入通道切换，见"后续"） |
| 相关 | [ADR-008](adr-008-upstream-detachment.md)（OAuth 待办的本决策终结）、[死依赖与单点](../risk/dead-dependencies.md) |

## Context

ADR-008 将"替换上游注册的 OAuth client_id（`dd28b3f2-…`）"列为头号待办，原设想注册
自有 Entra 应用。实操发现微软已封死这条路的前置条件：

- 个人 Microsoft 账户**免目录注册应用**的能力已弃用（门户提示"在目录外部创建应用
  程序的功能已被弃用"），个人账户登录 Azure 门户亦被"Microsoft Services"租户拦下；
- 无目录的合规获取路径只剩两条：Azure 免费账户（需国际信用卡）或组织账户
  （学校/公司租户，应用归属受制于租户管理员）。M365 开发人员计划自 2024-04 起
  仅向 Visual Studio 订阅者提供沙盒。

同期对生态的源码级调查（2026-10-15）：

| 启动器 | 做法 | client ID 可见性 |
|---|---|---|
| HMCL | 自有应用，构建期从 CI secret 注入 JAR manifest；源码为空时禁用微软登录 | 不公开 |
| PCL2-CE | 自有应用，构建期注入 `MS_CLIENT_ID`；端点/作用域与本项目逐字一致 | 不公开 |
| Prism Launcher（含全部 fork） | 自有应用，**ID 公开在仓库** `CMakeLists.txt`，注释明示"使用即接受微软身份平台服务条款" | **公开** |
| PCL.Mac-XE（姊妹项目） | 仍用上游 `dd28b3f2-…` | 源码硬编码 |

实测：Prism 公共 ID `c36a9fb6-4f2a-41ff-90bd-ae7cc92031eb` 向本项目使用的
`/consumers` 设备码端点 + `scope=XboxLive.signin offline_access` 发起请求，
成功返回 `user_code`（与上游 ID 行为一致，上游 ID 截至 2026-10-15 亦仍存活）。

## Decision

1. **缺省 client ID 换为 Prism 公共 ID**（`MicrosoftAuthService.defaultClientID`）。
   理由：同样是"使用他人注册的公共客户端"，但从**已停更跑路的注册者**（上游）换成
   **活跃维护且明示允许 fork 共用**的开源项目——风险严格更优，且是注册不了自有
   应用的社区项目的事实标准（Prism fork 生态通行做法）。
2. **增加构建期/运行时注入通道**（学 PCL2-CE）：`MicrosoftAuthService.init` 依次
   读显式参数 > 环境变量 `PCLMAC_MS_CLIENT_ID` > Bundle 内 `Secrets.properties`
   的 `MS_CLIENT_ID`，均缺省回落公共 ID。登录（App 层）与 refresh（Core 层）
   两个构造点自动统一走同一配置。
3. **切换代价**：refresh token 绑定 client，切换后既有账号需重新登录一次（含
   开发自用账号）；ADR-008 已预告。

## 后续（自有应用条件具备时）

经 Azure 免费账户或学校租户注册"任何组织目录 + 个人 Microsoft 帐户"型应用并
开启公共客户端流后，在 `Secrets.properties` / CI secret 配置 `MS_CLIENT_ID`
即可，无需改代码。届时可把缺省值收回自有 ID 并撤销对外部 ID 的依赖。

## 风险披露

- 借用第三方注册的 client ID 属灰色地带（微软身份平台条款视角）；Prism 在其
  仓库中明示"使用即接受条款"，视为对 fork/第三方的官方许可姿态。
- 若微软侧封禁该 ID，受影响的是全部共用它的启动器（含 Prism 本体），届时需
  各自切换；本项目的注入通道保证切换是一行配置的事。

验证：构建 ✅ · 全量测试 ✅ · 实测设备码端点返回 `user_code` ✅
