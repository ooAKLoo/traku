//
//  CustomSpaceConfigView.swift
//  raku
//
//  Created by Claude on 2025/9/15.
//

import SwiftUI

// MARK: - 自定义空间配置视图
struct CustomSpaceConfigView: View {
    @Binding var isPresented: Bool
    let isDarkMode: Bool
    let onSpaceCreated: (Space) -> Void
    var isEmbedded: Bool = false
    var templateData: SpaceTemplate? = nil  // 添加模板数据参数
    
    @State private var spaceName = ""
    @State private var spaceDescription = ""
    @State private var selectedEmoji = "📋"
    @State private var categories: [CustomCategoryItem] = []
    @State private var newCategoryName = ""
    @State private var showingEmojiPicker = false
    
    private let availableEmojis = ["📋", "🎨", "🚀", "📚", "✍️", "💡", "🔮", "⭐", "🌟", "🎯", "🎪", "🎭"]
    
    var body: some View {
        Group {
            if isEmbedded {
                embeddedContent
            } else {
                NavigationView {
                    fullScreenContent
                        .navigationTitle("自定义空间")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("取消") {
                                    isPresented = false
                                }
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("创建") {
                                    createSpace()
                                }
                                .foregroundColor(canCreateSpace ? (isDarkMode ? Color.blue.opacity(0.9) : Color.blue) : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                                .disabled(!canCreateSpace)
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingEmojiPicker) {
            EmojiPickerView(
                selectedEmoji: $selectedEmoji,
                emojis: availableEmojis,
                isDarkMode: isDarkMode
            )
        }
        .onAppear {
            initializeFromTemplate()
        }
    }
    
    // MARK: - 嵌入模式内容
    private var embeddedContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 空间基本信息
                spaceInfoSection
                    .padding(.horizontal, 20)
                
                // 类别管理
                categoriesSection
                    .padding(.horizontal, 20)
                
                // 创建按钮
                Button(action: createSpace) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        
                        Text("创建空间")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: canCreateSpace ? 
                                        [Color.blue, Color.blue.opacity(0.8)] : 
                                        [Color.gray, Color.gray.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: canCreateSpace ? Color.blue.opacity(0.3) : Color.clear, 
                                   radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(!canCreateSpace)
                .scaleEffect(canCreateSpace ? 1 : 0.98)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: canCreateSpace)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
            .padding(.top, 10)
        }
        .background(isDarkMode ? Color.black : Color.white)
    }
    
    // MARK: - 全屏模式内容
    private var fullScreenContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 空间基本信息
                spaceInfoSection
                
                // 类别管理
                categoriesSection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .background(isDarkMode ? Color.black : Color.white)
    }
    
    // MARK: - 空间信息区域
    private var spaceInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(L("basic_information"), systemImage: "sparkle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
                Spacer()
            }
            
            // 空间名称和emoji
            HStack(spacing: 16) {
//                Button(action: {
//                    showingEmojiPicker = true
//                }) {
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 14)
//                            .fill(LinearGradient(
//                                colors: [
//                                    isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.08),
//                                    isDarkMode ? Color.white.opacity(0.04) : Color.gray.opacity(0.04)
//                                ],
//                                startPoint: .topLeading,
//                                endPoint: .bottomTrailing
//                            ))
//                        
//                        Text(selectedEmoji)
//                            .font(.system(size: 36))
//                    }
//                    .frame(width: 72, height: 72)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 14)
//                            .stroke(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04), lineWidth: 0.5)
//                    )
//                    .shadow(color: isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.05), radius: 4, y: 2)
//                }
                
                VStack(spacing: 10) {
                    TextField("空间名称", text: $spaceName)
                        .font(.system(size: 17, weight: .semibold))
                        .textFieldStyle(PremiumTextFieldStyle(isDarkMode: isDarkMode))
                    
                    TextField("简短描述（可选）", text: $spaceDescription)
                        .font(.system(size: 14))
                        .textFieldStyle(PremiumTextFieldStyle(isDarkMode: isDarkMode, isSecondary: true))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                .shadow(color: isDarkMode ? Color.black.opacity(0.5) : Color.black.opacity(0.05), 
                       radius: 10, x: 0, y: 4)
        )
    }
    
    // MARK: - 类别管理区域
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Label("类别管理", systemImage: "folder.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
            
            // 添加新类别输入框
            HStack(spacing: 12) {
                TextField("添加新类别", text: $newCategoryName)
                    .font(.system(size: 16))
                    .textFieldStyle(PremiumTextFieldStyle(isDarkMode: isDarkMode))
                
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
            if !categories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("已添加的类别")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                        
                        Spacer()
                        
                        Text("\(categories.count) 个")
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                    }
                    
                    // 类别标签列表
                    FlowLayout(spacing: 6) {
                        ForEach(categories) { category in
                            HStack(spacing: 6) {
                                Text(category.name)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                    .fixedSize(horizontal: true, vertical: false)
                                
                                Button(action: {
                                    categories.removeAll { $0.id == category.id }
                                }) {
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
        !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && categories.count < 10
    }
    
    private var canCreateSpace: Bool {
        !spaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !categories.isEmpty
    }
    
    // MARK: - 方法
    private func initializeFromTemplate() {
        guard let template = templateData else { return }
        
        // 填充基本信息
        spaceName = template.title
        spaceDescription = template.description
        selectedEmoji = template.emoji
        
        // 转换模板类别为自定义类别
        categories = template.categories.map { templateCategory in
            CustomCategoryItem(
                name: templateCategory.name,
                emoji: "📁",  // 使用统一的默认图标
                color: .blue  // 使用统一的默认颜色
            )
        }
    }
    
    private func addCategory() {
        guard canAddCategory else { return }
        
        let category = CustomCategoryItem(
            name: newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: "📁",  // 使用统一的默认图标
            color: .blue  // 使用统一的默认颜色
        )
        
        categories.append(category)
        newCategoryName = ""
    }
    
    private func createSpace() {
        guard canCreateSpace else { return }
        
        // 创建空间
        let space = Space(
            name: spaceName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: spaceDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // 保存到数据库
        if DatabaseManager.shared.createSpace(space) {
            // 创建类别
            for categoryItem in categories {
                let category = Category(
                    spaceId: space.id,
                    name: categoryItem.name
                )
                _ = DatabaseManager.shared.createCategory(category)
            }
            
            onSpaceCreated(space)
            isPresented = false
        }
    }
    
}

// MARK: - 自定义数据模型
struct CustomSpace {
    let name: String
    let description: String
    let emoji: String
    let categories: [CustomCategoryItem]
}

struct CustomCategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let color: Color
}


// MARK: - Emoji选择器
struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    let emojis: [String]
    let isDarkMode: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button(action: {
                            selectedEmoji = emoji
                            dismiss()
                        }) {
                            Text(emoji)
                                .font(.system(size: 32))
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedEmoji == emoji ? (isDarkMode ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)) : Color.clear)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedEmoji == emoji ? (isDarkMode ? Color.blue.opacity(0.8) : Color.blue) : Color.clear, lineWidth: 2)
                                        )
                                )
                        }
                    }
                }
                .padding(20)
            }
            .background(isDarkMode ? Color.black : Color.white)
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? Color.blue.opacity(0.9) : Color.blue)
                }
            }
        }
    }
}

// MARK: - 高级文本框样式
struct PremiumTextFieldStyle: TextFieldStyle {
    let isDarkMode: Bool
    var isSecondary: Bool = false
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
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


// MARK: - 预览
struct CustomSpaceConfigView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomSpaceConfigView(
                isPresented: .constant(true),
                isDarkMode: false,
                onSpaceCreated: { _ in },
                isEmbedded: false
            )
            .previewDisplayName("Full Screen Mode")
            
            CustomSpaceConfigView(
                isPresented: .constant(true),
                isDarkMode: false,
                onSpaceCreated: { _ in },
                isEmbedded: true
            )
            .previewDisplayName("Embedded Mode")
        }
    }
}
