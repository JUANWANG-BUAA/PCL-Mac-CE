//
//  MoreSidebar.swift
//  PCLMacCE
//

import SwiftUI

struct MoreSidebar: Sidebar {
    var body: some View {
        VStack {
            MyNavigationList(
                .init(.about, .iconAbout, "关于与鸣谢"),
                .init(.toolbox, .iconBox, "百宝箱")
            )
            Spacer()
        }
    }
}
