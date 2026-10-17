//
//  AboutPage.swift
//  PCLMacCE
//

import SwiftUI
import AppKit
import Core

struct AboutPage: View {
    var body: some View {
        CardContainer {
            MyCard("关于", foldable: false) {
                VStack(spacing: 0) {
                    ProfileView(.local(.ltCatt), "龙腾猫跃", "Plain Craft Launcher 的作者！",
                                .init("GitHub 主页", "https://github.com/LTCatt"),
                                .init("前往赞助", WebLinks.Afdian.ltCat.absoluteString))

                    ProfileView(.network(url: "https://github.com/JUANWANG-BUAA.png"), "JUANWANG", "PCL Mac CE 的独立维护者 · 负责设计、开发与发布",
                                .init("GitHub 主页", "https://github.com/JUANWANG-BUAA"))

                    ProfileView(.appIcon, "PCL Mac CE",
                                "PCL 的第三方 macOS 衍生作品，由 JUANWANG-BUAA 独立维护。"
                                + "当前版本 \(Metadata.appVersion) (\(Metadata.bundleVersion))")
                }
            }

            MyCard("特别鸣谢", foldable: false) {
                VStack(spacing: 0) {
                    ProfileView(.appIcon, "PCL.Mac 项目贡献者",
                                "感谢原项目贡献者公开 v1.1.1 代码，作为本项目的历史代码起点。当前项目独立维护与发行。")

                    ProfileView(.local(.pclCommunity), "PCL Community", "Plain Craft Launcher 非官方社区",
                                .init("GitHub 主页", "https://github.com/PCL-Community"))

                    ProfileView(.local(.pclProto), "PCL.Proto", "以 PCL2 和 PCL2-CE 为蓝本，旨在为各 PCL 分支版本提供一个标准化的原型样本。",
                                .init("GitHub 仓库", "https://github.com/PCL-Community/PCL.Proto"))

                    ProfileView(.local(.bangbang93), "bangbang93", "提供 BMCLAPI 镜像源，详见 https://bmclapi.bangbang93.com",
                                .init("前往赞助", WebLinks.Afdian.bangbang93.absoluteString))
                }
            }

            MyCard("许可与版权声明", foldable: false) {
                VStack(spacing: 15) {
                    MyText("PCL Mac CE 的分发条件见仓库根目录 LICENSE；历史代码来源与致谢见 PCL-Mac-CE-Baseline-Notice.txt。")
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    LicenseListItem(
                        "SwiftyJSON", "Copyright (c) 2017 Ruoyu Fu\nLicensed under the MIT License.",
                        sourceURL: "https://github.com/SwiftyJSON/SwiftyJSON",
                        licenseURL: "https://github.com/SwiftyJSON/SwiftyJSON/blob/master/LICENSE"
                    )
                    LicenseListItem(
                        "ZIPFoundation", "Copyright (c) 2017-2025 Thomas Zoechling (https://www.peakstep.com)\nLicensed under the MIT License.",
                        sourceURL: "https://github.com/weichsel/ZIPFoundation",
                        licenseURL: "https://github.com/weichsel/ZIPFoundation/blob/development/LICENSE"
                    )
                    LicenseListItem(
                        "TOMLDecoder", "Copyright (c) 2019 TOMLDecoder contributors\nLicensed under the MIT License.",
                        sourceURL: "https://github.com/dduan/TOMLDecoder",
                        licenseURL: "https://github.com/dduan/TOMLDecoder/blob/main/LICENSE"
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
        }
    }

    private struct ProfileView: View {
        @ObservedObject private var easterEggManager: EasterEggManager = .shared
        @Environment(\.disableHoverAnimation) private var cardAppearAnimationPlaying: Bool

        private let avatar: Avatar
        private let avatarURL: URL?
        private let nickname: String
        private let description: String
        private let links: [Link]

        init(_ avatar: Avatar, _ nickname: String, _ description: String, _ links: Link...) {
            self.avatar = avatar
            if case .network(let url) = avatar {
                self.avatarURL = URL(string: url)
            } else {
                self.avatarURL = nil
            }
            self.nickname = nickname
            self.description = description
            self.links = links
        }

        var body: some View {
            MyListItem {
                HStack {
                    Group {
                        switch avatar {
                        case .local(let imageResource): Image(imageResource).resizable()
                        case .appIcon: Image(nsImage: NSApp.applicationIconImage)
                        case .network:
                            if let avatarURL {
                                NetworkImage(url: avatarURL)
                            } else {
                                Image(nsImage: .init())
                            }
                        }
                    }
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(.circle)
                    .contrast(easterEggManager.modifyColor ? -1 : 1) // 防止“千万别点”颜色反转影响到头像
                    VStack(alignment: .leading) {
                        MyText(nickname)
                        MyText(description, color: .textSecondary)
                    }
                    Spacer()
                    HStack {
                        ForEach(links, id: \.url) { link in
                            MyButton(link.buttonName) {
                                if let url: URL = .init(string: link.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .frame(width: 100)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .padding(2)
            }
        }

        struct Link {
            let buttonName: String
            let url: String

            init(_ buttonName: String, _ url: String) {
                self.buttonName = buttonName
                self.url = url
            }
        }

        enum Avatar {
            case local(ImageResource)
            case appIcon
            case network(url: String)
        }
    }

    private struct LicenseListItem: View {
        private let name: String
        private let info: String
        private let sourceURL: URL
        private let licenseURL: URL

        init(_ name: String, _ info: String, sourceURL: String, licenseURL: String) {
            self.name = name
            self.info = info
            self.sourceURL = URL(string: sourceURL)!
            self.licenseURL = URL(string: licenseURL)!
        }

        var body: some View {
            HStack(alignment: .top, spacing: 20) {
                MyText(name)
                    .frame(width: 120, alignment: .leading)
                VStack(alignment: .leading, spacing: 7) {
                    MyText(info)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 20) {
                        MyButton("查看来源网站") {
                            NSWorkspace.shared.open(sourceURL)
                        }
                        .frame(width: 140)
                        MyButton("查看许可文档") {
                            NSWorkspace.shared.open(licenseURL)
                        }
                        .frame(width: 140)
                    }
                    .frame(height: 38)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
