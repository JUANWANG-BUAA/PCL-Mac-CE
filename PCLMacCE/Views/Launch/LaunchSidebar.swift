//
//  LaunchSidebar.swift
//  PCLMacCE
//

import SwiftUI
import Core

struct LaunchSidebar: Sidebar {
    @StateObject private var instanceVM: InstanceViewModel
    @StateObject private var accountVM: AccountViewModel = .init()
    @ObservedObject private var launchVM: MinecraftLaunchManager = .shared
    @State private var addingYggdrasilAccount: Bool = false
    @State private var tip: String = LaunchSidebar.tips.randomElement() ?? ""

    @State private var showToolbar: Bool = false
    @State private var toolbarHovered: Bool = false

    /// 启动等待页“你知道吗”的提示池。
    private static let tips: [String] = [
        "在设置中可以把下载源切换为镜像优先，在国内下载会更快。",
        "启动大型整合包前，记得在实例设置中调整内存分配，内存不足是崩溃的常见原因。",
        "模组、资源包和光影包可以直接拖进启动器窗口导入。",
        "可以在实例设置里为每个实例指定不同的 Java 版本。",
        "遇到问题时，导出日志并发给他人，比截图更有帮助。",
        "删除的实例会进入废纸篓，误删后可以从废纸篓找回。",
        "Fabric 通常对新版本跟进更快，适合追新；Forge 的模组生态更庞大。",
        "任务页面可以查看并取消正在进行的下载与安装。",
        "游戏崩溃后可以在崩溃报告中找到详细原因，别只看弹窗里的文字。",
        "实例目录是独立的，把存档放进实例的 saves 文件夹即可。",
        "老版本 Minecraft（1.16 及更早）需要 Java 8~17，配错版本会直接崩溃。",
        "光影包需要先安装 Iris 或 OptiFine 等光影加载器才能生效。"
    ]

    init(instanceManager: InstanceManager) {
        self._instanceVM = StateObject(wrappedValue: InstanceViewModel(instanceManager: instanceManager))
    }

    private let insertTransition: AnyTransition =
        .asymmetric(
            insertion: .modifier(
                active: ScaleOpacityEffect(scale: 0.95, opacity: 0.0),
                identity: ScaleOpacityEffect(scale: 1.0, opacity: 1.0)
            )
            .animation(.spring(response: 0.2)),
            removal: .opacity
        )

    var body: some View {
        if launchVM.isLaunching {
            launchingBody
        } else {
            normalBody
        }
    }

    private var normalBody: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        return VStack {
            // 原生风格：账号区靠上，避免上下均分留白导致的“中部空旷”
            if !isNative {
                Spacer()
            }
            Group {
                switch accountVM.currentPanel {
                case .normal:
                    if let account = accountVM.currentAccount {
                        normalPanel(account)
                    }
                case .accountList:
                    accountListPanel
                case .addYggdrasil:
                    addYggdrasilAccountPanel
                }
            }
            .padding(.top, isNative ? 32 : 0)
            .transition(insertTransition)

            Spacer()
            VStack(spacing: 11) {
                Group {
                    if let instance = instanceVM.currentInstance {
                        MyButton("启动游戏", subLabel: instance.name, type: .highlight) {
                            guard !launchVM.isRunning && !launchVM.isLaunching else {
                                hint("已有一个游戏实例正在运行！", type: .critical)
                                return
                            }
                            if let account = accountVM.currentAccount {
                                launchVM.launch(instance, using: account, in: instanceVM.currentRepository)
                            } else {
                                hint("请先添加一个账号！", type: .critical)
                            }
                        }
                    } else if instanceVM.loading {
                        MyButton("加载中", subLabel: "正在加载实例列表", disabled: true) {}
                    } else {
                        MyButton("下载游戏", subLabel: "未找到可用的游戏实例", type: .normal) {
                            AppRouter.shared.setRoot(.download)
                        }
                    }
                }
                .frame(height: 50)
                HStack(spacing: 11) {
                    MyButton("实例选择") {
                        AppRouter.shared.append(.instanceList(repositoryId: instanceVM.currentRepository.id))
                    }
                    if let instance = instanceVM.currentInstance {
                        MyButton("实例设置") {
                            AppRouter.shared.append(.instanceSettings(id: instance.name))
                        }
                    }
                }
                .frame(height: 32)
            }
            .padding(21)
        }
        .onAppear {
            if instanceVM.currentRepository.instances == nil {
                instanceVM.reload(repository: instanceVM.currentRepository)
            }
        }
    }

    private func normalPanel(_ account: Account) -> some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        return VStack(spacing: 14) {
            VStack(spacing: 15) {
                PlayerAvatar(account)
                VStack(spacing: 4) {
                    MyText(account.profile.name, size: 16)
                    MyText(account.localizedTypeName, size: 12, color: isNative ? .secondary : .colorGray4)
                }
            }
            .padding(4)
            .contentShape(.rect)
            .onTapGesture {
                accountVM.currentPanel = .accountList
            }

            // 工具条：原生风格常驻显示（可见即可用的 macOS 语言，不再藏进悬停热区）；
            // 经典主题保持 PCL 的悬停显露
            toolbarView
                .opacity(isNative || showToolbar ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showToolbar)
        }
        .contentShape(.rect)
        .onHover { showToolbar = $0 }
    }

    private var toolbarView: some View {
        let isNative = ThemeManager.shared.theme.isNativeStyle
        let icons = HStack(spacing: 16) {
            Button {
                    guard let account = accountVM.currentAccount else {
                        hint("请先选择一个账号！", type: .critical)
                        return
                    }
                    CapeSelection.request(for: account)
            } label: {
                Image(systemName: "tshirt.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("选择披风")

            Button { accountVM.currentPanel = .accountList } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("切换账号")
        }
        return Group {
            if isNative {
                // 原生风格：与顶栏导航胶囊同一语言的玻璃胶囊，图标用正文色（深色侧栏下为白色）
                icons
                    .foregroundStyle(Color.primary.opacity(toolbarHovered ? 1 : 0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .glassBackground(in: Capsule())
            } else {
                icons
                    .foregroundStyle(Color.color3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.colorGray8)
                            .shadow(
                                color: toolbarHovered ? .color3.opacity(0.6) : .black.opacity(0.15),
                                radius: toolbarHovered ? 6 : 8
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                toolbarHovered ? Color.color3.opacity(0.45) : Color.colorGray2.opacity(0.35),
                                lineWidth: 1
                            )
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: toolbarHovered)
        .onHover { toolbarHovered = $0 }
    }

    private var accountListPanel: some View {
        VStack {
            accountList
                .padding(.horizontal, 8)
            HStack {
                MyButton("添加账号") {
                    accountVM.requestAddAccount()
                }
                .frame(width: 80)

                if accountVM.currentAccount != nil {
                    MyButton("返回") {
                        accountVM.currentPanel = .normal
                    }
                    .frame(width: 50)
                }
            }
            .frame(height: 30)
        }
    }

    private var accountList: some View {
        VStack(spacing: 0) {
            ForEach(accountVM.accounts, id: \.id) { account in
                MyListItem { hovered in
                    HStack {
                        if account.id == accountVM.currentAccount?.id {
                            RightRoundedRectangle(cornerRadius: 4)
                                .fill(Color.color3)
                                .frame(width: 4, height: 20)
                                .offset(x: -4)
                        } else {
                            Spacer()
                                .frame(width: 12)
                        }
                        PlayerAvatar(account, length: 36)
                        VStack(alignment: .leading) {
                            MyText(account.profile.name)
                            MyText(account.localizedTypeName, color: ThemeManager.shared.theme.isNativeStyle ? .secondary : .colorGray3)
                        }
                        Spacer()
                        if ThemeManager.shared.theme.isNativeStyle || hovered {
                            Button {
                                MessageBoxManager.shared.showText(
                                    title: "移除账号",
                                    content: "确定要移除账号「\(account.profile.name)」吗？\n移除后需要重新登录才能再次使用。",
                                    level: .info,
                                    .no(),
                                    .yes(label: "移除", type: .red)
                                ) { result in
                                    guard result == 1 else { return }
                                    accountVM.remove(account: account)
                                    hint("已移除账号「\(account.profile.name)」", type: .finish)
                                }
                            } label: {
                                Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12)
                                .foregroundStyle(Color.color3)
                                .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("移除账号 \(account.profile.name)")
                            .padding(.trailing, 4)
                        }
                    }
                }
                .onTapGesture {
                    accountVM.switchAccount(to: account)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: accountVM.currentAccount?.id)
    }

    private var addYggdrasilAccountPanel: some View {
        VStack {
            fieldLine("服务器") {
                MyTextField(text: $accountVM.yggdrasilServer)
            }
            fieldLine("用户名") {
                MyTextField(text: $accountVM.yggdrasilUsername)
            }
            fieldLine("密码") {
                MyTextField(text: $accountVM.yggdrasilPassword, secure: true)
            }
            HStack {
                MyButton("返回") {
                    accountVM.currentPanel = .accountList
                }
                .frame(width: 50)
                MyButton("登录", type: .highlight) {
                    guard !addingYggdrasilAccount else { return }
                    addingYggdrasilAccount = true
                    Task {
                        await accountVM.addYggdrasilAccount()
                        await MainActor.run {
                            addingYggdrasilAccount = false
                        }
                    }
                }
                .frame(width: 50)
            }
            .frame(height: 30)
            .padding(.top, 4)
        }
    }

    private var launchingBody: some View {
        VStack(spacing: 0) {
            Spacer()
            MyLoading(viewModel: launchVM.loadingViewModel, showCard: false)
            if let instanceName = launchVM.instanceName {
                MyText(instanceName, size: 13.5, color: .color3)
                    .padding(.top, 5)
            }
            HStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(stops: [
                            .init(color: Color.color4, location: 0),
                            .init(color: Color.color3, location: 0.6)
                        ], startPoint: .topLeading, endPoint: .topTrailing)
                    )
                    .frame(width: 225 * launchVM.progress)
                Rectangle()
                    .fill(Color.color6)
                    .opacity(0.6)
            }
            .frame(width: 225, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 27)

            VStack(alignment: .leading) {
                if let currentStage: String = launchVM.currentStage {
                    launchingInfo(name: "当前步骤", value: currentStage)
                }
                launchingInfo(name: "启动进度") {
                    AnimatablePercentText(progress: launchVM.progress)
                }
            }

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.colorGray1, lineWidth: 1)
                    .padding(1)
                HStack {
                    MyText("你知道吗", size: 12.5)
                        .opacity(0.5)
                        .padding(.horizontal, 10)
                        .background(ThemeManager.shared.theme.isNativeStyle ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.white))
                        .offset(y: -8)
                }
                MyText(tip, size: 12.5)
                    .padding(11)
            }
            .frame(width: 260, height: launchVM.isRunning ? nil : 0)
            .opacity(launchVM.isRunning ? 1 : 0)
            .padding(.top, 26)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()
            MyButton("取消", launchVM.cancel)
                .frame(height: 32)
                .padding(21)
        }
        .animation(.easeOut(duration: 0.2), value: launchVM.progress)
        .animation(.easeOut(duration: 0.1), value: launchVM.isRunning)
    }

    private func launchingInfo(name: String, value: String) -> some View {
        launchingInfo(name: name) { MyText(value, size: 12.5) }
    }

    private func launchingInfo(name: String, value: () -> some View) -> some View {
        HStack(spacing: 15) {
            MyText(name, size: 12.5)
                .opacity(0.5)
            value()
        }
    }

    private func fieldLine(_ name: String, content: () -> some View) -> some View {
        HStack(spacing: 0) {
            MyText(name)
                .frame(width: 50, alignment: .leading)
            content()
        }
        .padding(.horizontal)
    }
}

private struct AnimatablePercentText: View, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let clamped: Double = min(max(progress, 0), 1)
        MyText(String(format: "%.2f %%", clamped * 100), size: 12.5)
    }
}

private struct ScaleOpacityEffect: ViewModifier {
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
    }
}
