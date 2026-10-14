//
//  APIEndpoints.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/10/14.
//

import Foundation

/// 全部远程 API 端点的唯一注册表。
///
/// 项目曾把 HTTP 根地址以字面量形式散落在 20+ 个文件中，同域名字面量重复出现，
/// 换源必须逐文件检索。现在所有远程地址集中于此，各服务只引用本注册表。
///
/// 状态标注（实测于 2026-10）：
/// - `cylorine.studio` 主域已下线（GitHub Pages 404），其下的更新源 / 版本反查 /
///   帮助页均为死链；`api.cylorine.studio` 子域仍存活，两者命运不绑定。
/// - `gitee.com/yizhimcqiu/easytier-mirror` 仓库已删除（404），EasyTier 下载需走
///   官方 GitHub Release 兜底。
public enum APIEndpoints {
    // MARK: Mojang 官方

    /// Mojang 版本清单元数据根。
    public enum MojangMeta {
        /// 全量版本清单。
        public static let versionManifest: URL = .init(string: "https://launchermeta.mojang.com/mc/game/version_manifest.json")!

        /// Java 运行时列表。
        ///
        /// 路径中的 `2ec0cc96…` 是 Mojang 官方启动器写死的清单标识，社区启动器均直接引用。
        public static let javaRuntimeAll: URL = .init(string: "https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json")!
    }

    /// Mojang 会话与账号服务。
    public enum MojangServices {
        /// Minecraft 服务 API 根。
        public static let apiRoot: URL = .init(string: "https://api.minecraftservices.com")!

        /// 以 UUID 查询玩家档案（皮肤、披风、改名记录）。
        public static func sessionServerProfile(id: String) -> URL {
            .init(string: "https://sessionserver.mojang.com/session/minecraft/profile/\(id)")!
        }
    }

    /// Mojang 静态资源分发。
    public enum MojangPiston {
        /// 资源对象（版本 jar、资源文件）根。
        public static let dataRoot: URL = .init(string: "https://piston-data.mojang.com")!
    }

    // MARK: 微软登录链

    /// 微软设备授权流与令牌端点。
    public enum MicrosoftAuth {
        /// 设备授权码申请。
        public static let deviceCode: URL = .init(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!
        /// OAuth 2.0 令牌（含设备授权流轮询）。
        public static let token: URL = .init(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
        /// 设备授权验证页兜底链接。
        public static let verificationFallback: URL = .init(string: "https://microsoft.com/link")!
    }

    /// Xbox Live 鉴权链。
    public enum XboxAuth {
        /// 用户认证（user token）。
        public static let userAuthenticate: URL = .init(string: "https://user.auth.xboxlive.com/user/authenticate")!
        /// XSTS 授权（Xbox Live 安全令牌）。
        public static let xstsAuthorize: URL = .init(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
    }

    // MARK: Mod 平台

    /// Modrinth 开放 API。
    public enum Modrinth {
        public static let apiRoot: URL = .init(string: "https://api.modrinth.com")!
    }

    /// CurseForge 开放 API。
    public enum CurseForge {
        public static let apiRoot: URL = .init(string: "https://api.curseforge.com")!

        /// CurseForge 文件 CDN。
        public static let forgeCDN: URL = .init(string: "https://edge.forgecdn.net")!
    }

    // MARK: 模组加载器

    /// Fabric 元数据 API。
    public enum FabricMeta {
        public static let root: URL = .init(string: "https://meta.fabricmc.net/v2")!

        /// 指定 Minecraft 版本的加载器版本列表。
        public static func loaderVersions(for minecraftVersion: String) -> URL {
            root.appending(path: "versions/loader/\(minecraftVersion)")
        }

        /// Fabric 安装 profile。
        public static func loaderProfile(minecraftVersion: String, loaderVersion: String) -> URL {
            .init(string: "\(root.absoluteString)/versions/loader/\(minecraftVersion)/\(loaderVersion)/profile/json")!
        }
    }

    /// Forge 官方 Maven。
    public enum ForgeMaven {
        public static let root: URL = .init(string: "https://files.minecraftforge.net/maven")!
    }

    /// NeoForge 官方 Maven。
    public enum NeoForgeMaven {
        public static let root: URL = .init(string: "https://maven.neoforged.net/releases")!
    }

    /// Maven Central（HMCL 移植的 ARM natives 位于此处）。
    public enum MavenCentral {
        public static let root: URL = .init(string: "https://repo1.maven.org/maven2/")!
    }

    // MARK: authlib-injector

    /// authlib-injector 构建产物元数据。
    public enum AuthlibInjector {
        /// 全部构建列表。
        public static let artifacts: URL = .init(string: "https://authlib-injector.yushi.moe/artifacts.json")!

        /// 指定构建号的产物详情。
        public static func artifact(buildNumber: Int) -> URL {
            .init(string: "https://authlib-injector.yushi.moe/artifact/\(buildNumber).json")!
        }
    }

    // MARK: 自有后端

    /// 作者自建后端 API（存活）。
    public enum CylorineAPI {
        public static let root: URL = .init(string: "https://api.cylorine.studio")!
    }

    /// 作者自建静态站点。
    ///
    /// ⚠️ **主域已下线（404）**：更新源、版本反查、帮助页均不可用，保留仅为集中管理。
    public enum CylorineSite {
        public static let root: URL = .init(string: "https://cylorine.studio")!

        /// 启动器更新元数据（死链）。
        public static let launcherUpdate: URL = root.appending(path: "meta/PCL.Mac/update.json")

        /// 版本 jar SHA-1 反查（死链）。
        public static func versionLookup(sha1: String) -> URL {
            root.appending(path: "meta/mc/version_lookup/sha1/\(sha1)")
        }
    }

    // MARK: 镜像源

    /// 社区镜像源。
    public enum Mirrors {
        /// BMCLAPI（bangbang93 维护）。
        public static let bmclapi: URL = .init(string: "https://bmclapi2.bangbang93.com")!
        /// MCIM（Modrinth / CurseForge CDN 镜像）。
        public static let mcim: URL = .init(string: "https://mod.mcimirror.top")!
        /// Cloudflare 出口 IP 探测，用于判断中国大陆地区。
        public static let cloudflareTrace: URL = .init(string: "https://www.cloudflare-cn.com/cdn-cgi/trace")!
    }

    // MARK: EasyTier

    /// EasyTier 联机内核。
    public enum EasyTier {
        public static let version: String = "v2.5.0"

        /// ⚠️ gitee 搬运仓库已删除（404），仅作历史候选保留。
        public static func giteeMirror(component: String, architecture: String) -> URL {
            .init(string: "https://gitee.com/yizhimcqiu/easytier-mirror/releases/download/\(version)/easytier-\(component)-macos-\(architecture)")!
        }

        /// 官方 GitHub Release 压缩包（内含 `easytier-macos-<arch>/` 目录）。
        public static func officialRelease(architecture: String) -> URL {
            .init(string: "https://github.com/EasyTier/EasyTier/releases/download/\(version)/easytier-macos-\(architecture)-\(version).zip")!
        }
    }
}
