//
//  WebLinks.swift
//  PCL.Mac
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

    /// Modrinth 项目主页。
    public static func modrinthProject(id: String) -> URL {
        .init(string: "https://modrinth.com/project/\(id)")!
    }

    /// 爱发电赞助页。
    public enum Afdian {
        public static let ltCat: URL = .init(string: "https://afdian.com/a/LTCat")!
        public static let bangbang93: URL = .init(string: "https://afdian.com/a/bangbang93")!
    }
}
