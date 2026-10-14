//
//  MultiplayerSidebar.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/1/15.
//

import SwiftUI

struct MultiplayerSidebar: Sidebar {
    var body: some View {
        VStack {
            MyNavigationList(
                .init(.multiplayerSub, .iconMultiplayerPage, "联机"),
                .init(.multiplayerSettings, .iconSettingsPage, "设置")
            )
            Spacer()
        }
    }
}
