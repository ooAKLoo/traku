//
//  CreateContentView.swift
//  raku
//
//  手动创建新内容视图 - 用于在空间中直接录入新的文本内容
//  Created by Assistant on 2025/9/21.
//

import SwiftUI

// MARK: - 创建内容数据结构
struct CreateContentData {
    let title: String
    let content: String
    let tags: [String]
    let selectedCategoryId: UUID?
}

// MARK: - 编辑内容数据结构
struct EditContentData {
    let title: String
    let content: String
    let tags: [String]
    let selectedCategoryId: UUID?
}

// MARK: - 创建内容视图
struct CreateContentView: View {
    let space: Space
    let categories: [Category]
    let isDarkMode: Bool
    let onSave: (CreateContentData) -> Void
    
    @State private var content = ""
    @State private var title = ""
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var selectedCategory: Category?
    @State private var isProcessingAI = false
    @State private var showingCategorySelector = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // 空间和类别选择（合并）
                        spaceAndCategorySection
                        
                        // 内容输入（核心功能）
                        contentInputSection
                        
                        // 元数据编辑（标题和标签，支持AI生成）
                        metadataSection
                    }
                    .padding(20)
                    .padding(.bottom, 34)
                }
            }
            .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
            .navigationTitle("创建内容")
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
                        saveContent()
                    }
                    .foregroundColor(canSave ? (isDarkMode ? Color.blue.opacity(0.9) : Color.blue) : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                    .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectorView(
                categories: categories,
                selectedCategory: selectedCategory,
                isDarkMode: isDarkMode,
                onSelection: { category in
                    selectedCategory = category
                    showingCategorySelector = false
                }
            )
        }
    }
    
    // MARK: - 空间和类别选择区域（轻盈简约版）
    private var spaceAndCategorySection: some View {
        VStack(spacing: 12) {
            // 空间信息 - 精简显示
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                
                Text(space.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                
                Spacer()
                
                // 类别选择 - 内联显示
                if let category = selectedCategory {
                    HStack(spacing: 6) {
                        Text(category.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        
                        Button(action: {
                            selectedCategory = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                        }
                    }
                } else {
                    Button(action: {
                        showingCategorySelector = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                            Text("类别")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.06))
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - 内容输入区域（核心功能）
    private var contentInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("输入内容", systemImage: "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
            
            ZStack(alignment: .topLeading) {
                // 背景
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.08), lineWidth: 0.5)
                    )
                
                // 文本编辑器
                TextEditor(text: $content)
                    .font(.system(size: 16))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                
                // 占位符文本
                if content.isEmpty {
                    Text("请输入您的想法、灵感或思考...\n\n这是最重要的部分，专注于您的内容创作")
                        .font(.system(size: 16))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 150)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                .shadow(color: isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.05), 
                       radius: 8, x: 0, y: 2)
        )
    }
    
    // MARK: - 元数据编辑区域（标题和标签）
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("标题和标签", systemImage: "textformat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
                
                Spacer()
                
                // AI生成按钮
                Button(action: generateWithAI) {
                    HStack(spacing: 6) {
                        if isProcessingAI {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14))
                        }
                        Text(isProcessingAI ? "生成中..." : "AI生成")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canGenerateAI ? Color.blue : Color.gray.opacity(0.6))
                    )
                }
                .disabled(!canGenerateAI || isProcessingAI)
            }
            
            VStack(spacing: 16) {
                // 标题编辑
                VStack(alignment: .leading, spacing: 8) {
                    Text("标题")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    
                    TextField("请输入标题或使用AI生成", text: $title)
                        .font(.system(size: 16))
                        .textFieldStyle(ContentEditTextFieldStyle(isDarkMode: isDarkMode))
                }
                
                // 标签编辑
                VStack(alignment: .leading, spacing: 8) {
                    Text("标签")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    
                    // 标签输入
                    HStack(spacing: 8) {
                        TextField("添加标签", text: $tagInput)
                            .font(.system(size: 16))
                            .textFieldStyle(ContentEditTextFieldStyle(isDarkMode: isDarkMode))
                            .onSubmit {
                                addTag()
                            }
                        
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(tagInput.isEmpty ? .gray : .blue)
                        }
                        .disabled(tagInput.isEmpty)
                    }
                    
                    // 已添加的标签
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    TagChip(
                                        text: tag,
                                        isDarkMode: isDarkMode,
                                        onDelete: {
                                            tags.removeAll { $0 == tag }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
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
    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var canGenerateAI: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - 方法
    private func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            tagInput = ""
        }
    }
    
    private func saveContent() {
        guard canSave else { return }
        
        let saveData = CreateContentData(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            selectedCategoryId: selectedCategory?.id
        )
        
        onSave(saveData)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func generateWithAI() {
        guard canGenerateAI, !isProcessingAI else { return }
        
        isProcessingAI = true
        
        // 创建LLMService实例
        let llmService = TwoStepLLMService()
        
        // 创建代理实例并设置回调
        let delegate = AIGenerationDelegate { [generatedTitle = self.$title, generatedTags = self.$tags, isProcessing = self.$isProcessingAI] title, tags in
            DispatchQueue.main.async {
                generatedTitle.wrappedValue = title
                generatedTags.wrappedValue = tags
                isProcessing.wrappedValue = false
            }
        } onError: { [isProcessing = self.$isProcessingAI] error in
            DispatchQueue.main.async {
                isProcessing.wrappedValue = false
                print("AI生成失败: \(error.localizedDescription)")
                // TODO: 显示错误提示给用户
            }
        }
        
        llmService.delegate = delegate
        
        // 使用第一步分析来生成标题和标签
        llmService.analyzeText(content)
    }
}

// MARK: - 类别选择器视图
struct CategorySelectorView: View {
    let categories: [Category]
    let selectedCategory: Category?
    let isDarkMode: Bool
    let onSelection: (Category?) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        // 无类别选项
                        Button(action: {
                            onSelection(nil)
                        }) {
                            HStack {
                                Text("未分类")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                
                                Spacer()
                                
                                if selectedCategory == nil {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 类别列表
                        ForEach(categories) { category in
                            Button(action: {
                                onSelection(category)
                            }) {
                                HStack {
                                    Text(category.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                    
                                    Spacer()
                                    
                                    if selectedCategory?.id == category.id {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(20)
                }
            }
            .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
            .navigationTitle("选择类别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                }
            }
        }
    }
}

// MARK: - 标签芯片组件
struct TagChip: View {
    let text: String
    let isDarkMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
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

// MARK: - 内容编辑文本框样式
struct ContentEditTextFieldStyle: TextFieldStyle {
    let isDarkMode: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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

// MARK: - AI生成代理类
class AIGenerationDelegate: TwoStepLLMServiceDelegate {
    private let onSuccess: (String, [String]) -> Void
    private let onError: (Error) -> Void
    
    init(onSuccess: @escaping (String, [String]) -> Void, onError: @escaping (Error) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }
    
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFirstStep result: FirstStepAnalysis) {
        // 使用第一步分析结果更新标题和标签
        onSuccess(result.title, result.tags)
        service.stopAnalysis() // 只需要第一步结果，停止后续分析
    }
    
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFinalAnalysis result: TwoStepAnalysisResult) {
        // 不需要第二步分析，但需要实现协议
    }
    
    func twoStepLLMService(_ service: TwoStepLLMService, didFailWithError error: Error) {
        onError(error)
    }
}

// MARK: - Preview
struct CreateContentView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSpace = Space(name: "示例空间", description: "这是一个示例空间")
        let sampleCategories = [
            Category(spaceId: sampleSpace.id, name: "想法"),
            Category(spaceId: sampleSpace.id, name: "灵感")
        ]
        
        Group {
            CreateContentView(
                space: sampleSpace,
                categories: sampleCategories,
                isDarkMode: false,
                onSave: { _ in }
            )
            .previewDisplayName("Light Mode")
            
            CreateContentView(
                space: sampleSpace,
                categories: sampleCategories,
                isDarkMode: true,
                onSave: { _ in }
            )
            .previewDisplayName("Dark Mode")
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 编辑内容视图
struct EditContentView: View {
    let article: SpaceArticle
    let recording: AudioRecording
    let space: Space
    let categories: [Category]
    let isDarkMode: Bool
    let onSave: (EditContentData) -> Void
    
    @State private var content: String
    @State private var title: String
    @State private var tags: [String]
    @State private var tagInput = ""
    @State private var selectedCategory: Category?
    @State private var showingCategorySelector = false
    @Environment(\.presentationMode) var presentationMode
    
    init(article: SpaceArticle, recording: AudioRecording, space: Space, categories: [Category], isDarkMode: Bool, onSave: @escaping (EditContentData) -> Void) {
        print("🎨 edit-space-articalcard--- [EditContentView] 初始化开始")
        print("   edit-space-articalcard--- article.id: \(article.id)")
        print("   edit-space-articalcard--- recording.id: \(recording.id)")
        print("   edit-space-articalcard--- recording.title: \(recording.title)")
        print("   edit-space-articalcard--- recording.polishedText 长度: \(recording.polishedText.count)")
        print("   edit-space-articalcard--- recording.transcription 长度: \(recording.transcription.count)")
        print("   edit-space-articalcard--- recording.tags 数量: \(recording.tags.count)")
        print("   edit-space-articalcard--- space.name: \(space.name)")
        print("   edit-space-articalcard--- categories.count: \(categories.count)")
        print("   edit-space-articalcard--- article.categoryId: \(article.categoryId?.uuidString ?? "nil")")
        
        self.article = article
        self.recording = recording
        self.space = space
        self.categories = categories
        self.isDarkMode = isDarkMode
        self.onSave = onSave
        
        // 初始化编辑内容
        let initialContent = recording.polishedText.isEmpty ? recording.transcription : recording.polishedText
        print("   edit-space-articalcard--- 选择的初始内容: \(initialContent.isEmpty ? "空" : "长度\(initialContent.count)")")
        
        self._content = State(initialValue: initialContent)
        self._title = State(initialValue: recording.title)
        self._tags = State(initialValue: recording.tags)
        
        // 设置当前类别
        if let categoryId = article.categoryId {
            let matchedCategory = categories.first { $0.id == categoryId }
            print("   edit-space-articalcard--- 匹配到的类别: \(matchedCategory?.name ?? "未找到")")
            self._selectedCategory = State(initialValue: matchedCategory)
        } else {
            print("   edit-space-articalcard--- 无类别")
            self._selectedCategory = State(initialValue: nil)
        }
        
        print("🎨 edit-space-articalcard--- [EditContentView] 初始化完成")
    }
    
    // MARK: - 编辑模式的元数据区域（无AI按钮）
    private var editMetadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("标题和标签", systemImage: "textformat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
                
                Spacer()
            }
            
            VStack(spacing: 16) {
                // 标题编辑
                VStack(alignment: .leading, spacing: 8) {
                    Text("标题")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    
                    TextField("请输入标题", text: $title)
                        .font(.system(size: 16))
                        .textFieldStyle(ContentEditTextFieldStyle(isDarkMode: isDarkMode))
                }
                
                // 标签编辑
                VStack(alignment: .leading, spacing: 8) {
                    Text("标签")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    
                    // 标签输入
                    HStack(spacing: 8) {
                        TextField("添加标签", text: $tagInput)
                            .font(.system(size: 16))
                            .textFieldStyle(ContentEditTextFieldStyle(isDarkMode: isDarkMode))
                            .onSubmit {
                                addTag()
                            }
                        
                        Button(action: addTag) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(tagInput.isEmpty ? .gray : .blue)
                        }
                        .disabled(tagInput.isEmpty)
                    }
                    
                    // 已添加的标签
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    TagChip(
                                        text: tag,
                                        isDarkMode: isDarkMode,
                                        onDelete: {
                                            tags.removeAll { $0 == tag }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // 空间和类别选择（合并）
                        spaceAndCategorySection
                        
                        // 内容输入（核心功能）
                        contentInputSection
                        
                        // 元数据编辑（标题和标签，手动编辑）
                        editMetadataSection
                    }
                    .padding(20)
                    .padding(.bottom, 34)
                }
            }
            .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
            .navigationTitle("编辑内容")
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
                        saveContent()
                    }
                    .foregroundColor(canSave ? (isDarkMode ? Color.blue.opacity(0.9) : Color.blue) : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                    .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $showingCategorySelector) {
            CategorySelectorView(
                categories: categories,
                selectedCategory: selectedCategory,
                isDarkMode: isDarkMode,
                onSelection: { category in
                    selectedCategory = category
                    showingCategorySelector = false
                }
            )
        }
    }
    
    // MARK: - 空间和类别选择区域（轻盈简约版）
    private var spaceAndCategorySection: some View {
        VStack(spacing: 12) {
            // 空间信息 - 精简显示
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                
                Text(space.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                
                Spacer()
                
                // 类别选择 - 优化交互版本（点击直接打开选择器）
                Button(action: {
                    showingCategorySelector = true
                }) {
                    HStack(spacing: 4) {
                        if let category = selectedCategory {
                            Text(category.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.blue)
                        } else {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                            Text("类别")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - 内容输入区域（核心功能）
    private var contentInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("编辑内容", systemImage: "pencil")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
            
            ZStack(alignment: .topLeading) {
                // 背景
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.08), lineWidth: 0.5)
                    )
                
                // 文本编辑器
                TextEditor(text: $content)
                    .font(.system(size: 16))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                
                // 占位符文本
                if content.isEmpty {
                    Text("请输入您的想法、灵感或思考...\\n\\n这是最重要的部分，专注于您的内容创作")
                        .font(.system(size: 16))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 150)
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
    private var canSave: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - 方法
    private func addTag() {
        let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            tagInput = ""
        }
    }
    
    private func saveContent() {
        guard canSave else { return }
        
        let saveData = EditContentData(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            selectedCategoryId: selectedCategory?.id
        )
        
        onSave(saveData)
        presentationMode.wrappedValue.dismiss()
    }
}
