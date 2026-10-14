# ADR-005 下载模式分离与选择互斥审计

| 项 | 值 |
|---|---|
| 日期 | 2026-10-14 |
| 状态 | 已实施 |
| 验证 | 干净构建 ✅ · 全量测试 ✅ |

## 背景

用户反馈两类体验问题：
1. **下载场景没有区分**：普通下载（浏览挑选、不绑定实例）与实例定向下载（版本/加载器已锁定）
   混在一起，且实例管理界面没有下载入口；PCL 原版也存在此问题。
2. **互斥项做的不全**：例如安装选项页可以同时选中 Fabric 与 Forge。

另有两项前轮遗留：报错弹窗无复制按钮、删除功能缺失（已在 ADR-004 修复）。

## 决策

### D1. `InstallContext` —— 两种下载模式的显式上下文

```swift
enum InstallContext: Hashable, Equatable, CustomStringConvertible {
    case general              // 普通下载：不预设实例
    case instance(id: String) // 实例定向下载：锁定实例
}
```

- 并入路由：`case resourceDownload(type: ResourceType, context: InstallContext)` 与
  `case projectInstall(project: ProjectListItemModel, context: InstallContext)`。
- **同时合并了原先 4 个重复 case**（`modDownload` / `resourcepackDownload` /
  `shaderpackDownload` / `modpackDownload`）——它们只差 `ResourceType` 一个维度，
  属冗余枚举设计。合并后侧栏、路由映射、标题生成全部去重。

### D2. 普通下载支持"下载到缓存"

- 新目录 `URLConstants.downloadCacheURL`（`…/PCL.Mac.Refactor/DownloadCache/{mods,resourcepacks,shaderpacks}/`）。
- `ResourceInstallViewModel.createCacheDownloadTask(forVersion:)`：下载到缓存（不绑定实例）。
- **普通模式**点版本 → 三按钮选择：`下载到缓存`（高亮）/ `安装到实例…`（弹实例选择）/ `取消`。
- **实例模式**点版本 → 校验后直接安装到锁定实例（目标明确，不再弹实例选择）。

### D3. 模式提示条（UI 显式化）

- `MyTip` 支持尾部动作按钮（`actionLabel:action:`，复用组件而非新建）。
- 实例模式：蓝色提示条显示目标实例（名称/版本/加载器）+「退出实例模式」（就地切回普通模式）。
- 普通模式（项目详情页）：提示双通道行为 +「打开下载缓存」。
- 实例管理页每个资源类型页新增「下载{类型}」入口，直接携带 `.instance(id:)` 上下文。
- `DownloadSidebar` 在实例定向模式下**切换资源类型时保留实例上下文**（继续为目标实例挑选）。

### D4. 选择互斥修复

- **安装选项页三卡互斥**（根因：`MyList` 选中态为组件内部 `@State`，三张卡各有实例，
  选完 Fabric 再选 Forge 时 Fabric 高亮不清除）：`MyList` 新增受控模式
  （`selection: Binding<Int?>`），`ModLoaderCard` 高亮由共享 `currentLoader` 派生。
- **「开始下载」防重复**：快速连点会创建两个同名实例安装任务（第二个因名称冲突失败），
  新增 `isDownloading` 门闩。
- **实例列表选中态**：选择页此前**不显示哪个实例是当前选择**——`InstanceView` 增加
  `selected` 高亮 +「当前选择」描述 + 切换后 hint 反馈。

## 互斥审计记录（全量）

| 场景 | 结论 |
|---|---|
| `MyList` 全部使用点（3 处） | 安装选项页已修；弹窗列表、演示页为单实例内单选，正确 |
| `MySelect` 全部使用点（2 处，下载源/主页） | 单值 Binding，单选正确 |
| Java 选择（实例配置"切换 Java"、设置页"安装 Java"） | 弹窗列表单选，弹窗期间被模态拦截，正确 |
| 披风选择（CapeSelection） | 弹窗单选，正确 |
| 联机创建/加入房间 | state 机驱动页面切换，天然互斥 |
| 侧栏导航（MyNavigationList） | 单选高亮；**加入 context 后需动态匹配**（D3 已处理） |
| 启动游戏 | `isLaunching` 门闩，正确 |
| 设置页（其他/联机） | 无多选控件 |

## 影响

| 文件 | 变更 |
|---|---|
| `App/AppRouter.swift` | `InstallContext` 新增；4+1 路由 case 合并/扩展；视图与侧栏映射 |
| `Components/MyList.swift` | 受控选择模式 |
| `Components/MyTip.swift` | 尾部动作按钮 |
| `Views/Download/ResourcesSearchPage.swift` | context 参数、模式条、上下文透传 |
| `Views/Download/ResourceInstallPage.swift` | 双模式点击流、模式条、缓存下载、实例选择复用 |
| `Views/Download/DownloadSidebar.swift` | 动态 context 导航 |
| `Views/Download/MinecraftInstallOptionsPage.swift` | 防重复 |
| `Views/Launch/InstanceSettings/InstalledResourcesPage.swift` | 下载入口携带实例上下文 |
| `Views/Launch/InstanceList/InstanceListPage.swift` | 当前实例高亮 |
| `ViewModels/ResourceInstallViewModel.swift` | `createCacheDownloadTask` |
| `Core/Utils/URLConstants.swift` | `downloadCacheURL` |

## 后续（不在本轮）

- 从实例管理进入下载后的"返回"语义：目前返回键回到游戏下载页（普通区），
  可用「退出实例模式」显式切换；更理想的返回栈留待导航重构。
- 下载缓存的文件管理 UI（浏览/删除缓存文件）。
