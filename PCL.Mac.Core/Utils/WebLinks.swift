//
//  WebLinks.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/10/14.
//

import Foundation

/// 用户可见的网页链接注册表。
///
/// 与 `APIEndpoints`（程序间通信端点）相区分，这里集中"在浏览器中打开"的链接，
/// 便于失效后一处替换。
public enum WebLinks {
    /// Minecraft 正版购买页（国区商店）。
    public static let minecraftStore: URL = .init(string: "https://www.xbox.com/zh-cn/games/store/minecraft-java-bedrock-edition-for-pc/9nxp44l49shj")!
    /// 微软账号改名帮助页。
    public static let microsoftRename: URL = .init(string: "https://support.microsoft.com/account-billing/837badbc-999e-54d2-2617-d19206b9540a")!
    /// Minecraft 正版玩家档案编辑页（改名、皮肤）。
    public static let minecraftProfileEdit: URL = .init(string: "https://www.minecraft.net/msaprofile/mygames/editprofile")!
    /// GitHub 问题讨论区。
    ///
    /// ⚠️ 指向的原上游仓库（CylorineStudio/PCL.Mac.Refactor）已转为私有，链接失效；
    /// 本项目自身的仓库确定后在此处替换。
    public static func githubDiscussion(category: String) -> URL {
        .init(string: "https://github.com/CylorineStudio/PCL.Mac.Refactor/discussions/new?category=\(category)")!
    }

    /// Modrinth 项目主页。
    public static func modrinthProject(id: String) -> URL {
        .init(string: "https://modrinth.com/project/\(id)")!
    }

    /// 爱发电赞助页。
    public enum Afdian {
        public static let ltCat: URL = .init(string: "https://afdian.com/a/LTCat")!
        public static let bangbang93: URL = .init(string: "https://afdian.com/a/bangbang93")!
    }

    /// 原上游作者的站点页面。
    ///
    /// ⚠️ 上游项目已关闭：主域整站下线（404）且不会恢复。本枚举仅作历史记录保留，
    /// **不再被任何 UI 引用**（关于页 / 帮助 / 隐私政策等入口均已移除）；
    /// 本项目自己的站点确定后，另建命名空间在此登记。
    public enum CylorineSite {
        public static let project: URL = APIEndpoints.CylorineSite.root.appending(path: "projects/PCL.Mac.Refactor")
        public static let privacy: URL = APIEndpoints.CylorineSite.root.appending(path: "privacy")
        /// 光影包使用教程。
        public static let shaderHelp: URL = APIEndpoints.CylorineSite.root.appending(path: "helps/shader")
        /// 联机帮助。
        public static let multiplayerHelp: URL = APIEndpoints.CylorineSite.root.appending(path: "helps/PCL.Mac#multiplayer")

        /// 用户头像。
        public static func avatar(_ name: String) -> URL {
            APIEndpoints.CylorineSite.root.appending(path: "img/avatar/\(name).png")
        }
    }
}
