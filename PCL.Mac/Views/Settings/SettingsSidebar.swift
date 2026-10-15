//
//  SettingsSidebar.swift
//  PCL.Mac
//

import SwiftUI

struct SettingsSidebar: Sidebar {
    var body: some View {
        VStack {
            MyNavigationList(
                .init(.launcherSettings, .iconSettingsPage, "启动器"),
                .init(.javaSettings, .iconJava, "Java 管理"),
                .init(.otherSettings, .iconBox, "其它")
            )
            Spacer()
        }
    }
}
