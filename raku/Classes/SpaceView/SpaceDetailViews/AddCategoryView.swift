//
//  AddCategoryView.swift
//  raku
//
//  Created by Assistant on 2025/9/21.
//

import SwiftUI

// MARK: - 添加类别视图
struct AddCategoryView: View {
    let spaceId: UUID
    let isDarkMode: Bool
    let onSave: (String) -> Void
    
    @State private var categoryName = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("类别名称", text: $categoryName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Spacer()
            }
            .navigationTitle("添加类别")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    if !categoryName.isEmpty {
                        onSave(categoryName)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(categoryName.isEmpty)
            )
        }
    }
}