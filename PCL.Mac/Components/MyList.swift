//
//  MyList.swift
//  PCL.Mac
//
//  Created by AnemoFlower on 2026/1/26.
//

import SwiftUI

/// 可选择的列表。
///
/// 提供两种选择模式：
/// - **非受控**：组件内部持有选中状态，适合独立使用的单选列表。
/// - **受控**（`selection:`）：选中状态由外部 `Binding` 派生，
///   适合同一选择分布在多个列表/卡片中的互斥场景（如 Fabric / Forge 版本选择）。
struct MyList: View {
    @State private var internalSelection: Int?
    private let externalSelection: Binding<Int?>?
    private let items: [ListItem]
    private let selectable: Bool
    private let onSelect: ((Int?) -> Void)?
    
    /// 当前的选中状态绑定：受控模式转发外部状态，非受控模式使用内部状态。
    private var selection: Binding<Int?> {
        externalSelection ?? Binding(
            get: { internalSelection },
            set: { internalSelection = $0 }
        )
    }
    
    init(items: [ListItem], selectable: Bool = false, onSelect: ((Int?) -> Void)? = nil) {
        self.items = items
        self.externalSelection = nil
        self.selectable = selectable || onSelect != nil
        self.onSelect = onSelect
    }
    
    /// 受控模式：选中状态完全由外部持有。
    init(items: [ListItem], selection: Binding<Int?>, onSelect: ((Int?) -> Void)? = nil) {
        self.items = items
        self.externalSelection = selection
        self.selectable = true
        self.onSelect = onSelect
    }
    
    init(_ items: ListItem..., selectable: Bool = false, onSelect: ((Int?) -> Void)? = nil) {
        self.init(items: items, selectable: selectable, onSelect: onSelect)
    }
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                MyListItem(items[index], selected: selection.wrappedValue == index)
                    .onTapGesture {
                        guard selectable else { return }
                        selection.wrappedValue = selection.wrappedValue == index ? nil : index
                        onSelect?(selection.wrappedValue)
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: selection.wrappedValue)
    }
}
