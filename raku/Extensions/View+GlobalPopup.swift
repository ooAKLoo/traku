//
//  View+GlobalPopup.swift
//  raku
//
//  Created by Assistant on 2025/1/16.
//  ViewModifier扩展 - 简化全局浮窗的使用
//

import SwiftUI

// MARK: - 全局浮窗修饰器
struct GlobalPopupModifier: ViewModifier {
    @StateObject private var popupManager = GlobalPopupManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GlobalPopupView()
                    .environmentObject(popupManager)
                    .allowsHitTesting(popupManager.isShowing || popupManager.isBatchSelectionShowing)
            )
            .environmentObject(popupManager)
    }
}

// MARK: - View 扩展
extension View {
    /// 添加全局浮窗支持
    /// 在应用的根视图上调用此方法，即可在任何地方使用全局浮窗
    func globalPopup() -> some View {
        modifier(GlobalPopupModifier())
    }
}

// MARK: - 便捷的批量选择工具栏方法
extension View {
    /// 显示批量选择工具栏（使用全局浮窗）
    /// 这个方法会将原有的本地工具栏替换为全局浮窗
    func globalBatchSelectionToolbar(
        isPresented: Binding<Bool>,
        selectedCount: Int,
        totalCount: Int,
        actionTitle: String = "添加到空间",
        actionIcon: String = "plus.circle.fill",
        onSelectAll: @escaping () -> Void,
        onDeselectAll: @escaping () -> Void,
        onAction: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: isPresented.wrappedValue) { newValue in
                let popupManager = GlobalPopupManager.shared
                
                if newValue {
                    let data = BatchSelectionData(
                        selectedCount: selectedCount,
                        totalCount: totalCount,
                        actionTitle: actionTitle,
                        actionIcon: actionIcon,
                        onSelectAll: onSelectAll,
                        onDeselectAll: onDeselectAll,
                        onAction: onAction
                    )
                    popupManager.showBatchSelection(data)
                } else {
                    popupManager.hideBatchSelection()
                }
            }
            .onChange(of: selectedCount) { newCount in
                if isPresented.wrappedValue {
                    let data = BatchSelectionData(
                        selectedCount: newCount,
                        totalCount: totalCount,
                        actionTitle: actionTitle,
                        actionIcon: actionIcon,
                        onSelectAll: onSelectAll,
                        onDeselectAll: onDeselectAll,
                        onAction: onAction
                    )
                    GlobalPopupManager.shared.batchSelectionData = data
                }
            }
    }
}

// MARK: - 使用示例
/*
 1. 在应用根视图添加全局浮窗支持：
 ```swift
 @main
 struct YourApp: App {
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .globalPopup() // 添加这一行
         }
     }
 }
 ```
 
 2. 在任何视图中使用通用浮窗：
 ```swift
 // 获取管理器实例
 let popupManager = GlobalPopupManager.shared
 
 // 显示成功消息
 popupManager.showSuccess("操作成功")
 
 // 显示错误消息
 popupManager.showError("发生错误")
 
 // 显示带操作的消息
 popupManager.show(
     message: "新消息到达",
     type: .info,
     duration: 3.0,
     action: {
         // 点击查看的操作
     }
 )
 ```
 
 3. 使用批量选择工具栏：
 ```swift
 struct YourView: View {
     @State private var isSelectionMode = false
     @State private var selectedItems: Set<UUID> = []
     
     var body: some View {
         YourContent()
             .globalBatchSelectionToolbar(
                 isPresented: $isSelectionMode,
                 selectedCount: selectedItems.count,
                 totalCount: items.count,
                 actionTitle: "添加到空间",
                 actionIcon: "plus.circle.fill",
                 onSelectAll: {
                     selectedItems = Set(items.map { $0.id })
                 },
                 onDeselectAll: {
                     selectedItems.removeAll()
                 },
                 onAction: {
                     // 执行批量操作
                 }
             )
     }
 }
 ```
 */