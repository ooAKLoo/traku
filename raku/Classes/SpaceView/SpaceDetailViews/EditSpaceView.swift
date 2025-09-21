//
//  EditSpaceView.swift
//  raku
//
//  Created by Assistant on 2025/9/21.
//

import SwiftUI

// MARK: - 编辑空间视图
struct EditSpaceView: View {
    let space: Space
    let categories: [Category]
    let isDarkMode: Bool
    let onSpaceUpdated: (Space) -> Void
    
    @State private var spaceName: String
    @State private var spaceDescription: String
    @State private var editableCategories: [Category]
    @State private var newCategoryName = ""
    @State private var showingDeleteConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    init(space: Space, categories: [Category], isDarkMode: Bool, onSpaceUpdated: @escaping (Space) -> Void) {
        self.space = space
        self.categories = categories
        self.isDarkMode = isDarkMode
        self.onSpaceUpdated = onSpaceUpdated
        self._spaceName = State(initialValue: space.name)
        self._spaceDescription = State(initialValue: space.description)
        self._editableCategories = State(initialValue: categories)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // 空间信息编辑
                        spaceInfoSection
                        
                        // 类别管理
                        categoryManagementSection
                    }
                    .padding(20)
                    .padding(.bottom, 34)
                }
            }
            .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
            .navigationTitle("编辑空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .foregroundColor(canSave ? (isDarkMode ? Color.blue.opacity(0.9) : Color.blue) : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                    .disabled(!canSave)
                }
            }
        }
    }
    
    // MARK: - 空间信息区域
    private var spaceInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("基本信息", systemImage: "info.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
                Spacer()
            }
            
            VStack(spacing: 12) {
                TextField("空间名称", text: $spaceName)
                    .font(.system(size: 17, weight: .medium))
                    .textFieldStyle(EditTextFieldStyle(isDarkMode: isDarkMode))
                
                TextField("空间描述", text: $spaceDescription)
                    .font(.system(size: 15))
                    .textFieldStyle(EditTextFieldStyle(isDarkMode: isDarkMode, isSecondary: true))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                .shadow(color: isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.05), 
                       radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 类别管理区域
    private var categoryManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Label("类别管理", systemImage: "folder.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
            
            // 添加新类别输入框
            HStack(spacing: 12) {
                TextField("添加新类别", text: $newCategoryName)
                    .font(.system(size: 16))
                    .textFieldStyle(EditTextFieldStyle(isDarkMode: isDarkMode))
                
                Button(action: addCategory) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(canAddCategory ? Color.blue : (isDarkMode ? Color.gray.opacity(0.3) : Color.gray.opacity(0.5)))
                        )
                }
                .disabled(!canAddCategory)
            }
            
            // 已添加的类别列表
            if !editableCategories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("已添加的类别")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                        
                        Spacer()
                        
                        Text("\(editableCategories.count) 个")
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                    }
                    
                    // 类别标签列表
                    FlowLayout(spacing: 6) {
                        ForEach(editableCategories) { category in
                            EditableCategoryTag(
                                category: category,
                                isDarkMode: isDarkMode,
                                onDelete: {
                                    deleteCategory(category)
                                }
                            )
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                .shadow(color: isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.05), 
                       radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 计算属性
    private var canAddCategory: Bool {
        !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var canSave: Bool {
        !spaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - 方法
    private func addCategory() {
        guard canAddCategory else { return }
        
        let categoryName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = Category(spaceId: space.id, name: categoryName)
        
        if DatabaseManager.shared.createCategory(category) {
            editableCategories.append(category)
            newCategoryName = ""
        }
    }
    
    private func deleteCategory(_ category: Category) {
        if DatabaseManager.shared.deleteCategory(id: category.id) {
            editableCategories.removeAll { $0.id == category.id }
        }
    }
    
    private func saveChanges() {
        let updatedSpace = Space(
            id: space.id,
            name: spaceName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: spaceDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: space.createdAt,
            updatedAt: Date()
        )
        
        onSpaceUpdated(updatedSpace)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - 可编辑类别标签
struct EditableCategoryTag: View {
    let category: Category
    let isDarkMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(category.name)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                .fixedSize(horizontal: true, vertical: false)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15))
        )
    }
}


// MARK: - 编辑文本框样式
struct EditTextFieldStyle: TextFieldStyle {
    let isDarkMode: Bool
    var isSecondary: Bool = false
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, isSecondary ? 10 : 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .foregroundColor(isDarkMode ? .white : .black)
    }
}