//
//  SpaceDetailViewNew.swift
//  raku
//
//  Created by Assistant on 2025/9/15.
//

import SwiftUI

// MARK: - 空间详情页（新版本）
struct SpaceDetailView: View {
    @State private var space: Space
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedCategoryId: UUID?
    @State private var categories: [Category] = []
    @State private var spaceArticles: [SpaceArticle] = []
    @State private var uncategorizedArticles: [SpaceArticle] = []
    @State private var recordings: [UUID: AudioRecording] = [:]
    @State private var showingAddContent = false
    @State private var showingEditSpace = false
    @State private var showUncategorized = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditContent = false
    @State private var editingArticle: SpaceArticle?
    @State private var editingRecording: AudioRecording?
    
    init(space: Space) {
        self._space = State(initialValue: space)
    }
    
    // 过滤后的文章
    private var filteredArticles: [SpaceArticle] {
        if showUncategorized {
            return uncategorizedArticles
        }
        guard let selectedCategoryId = selectedCategoryId else {
            return spaceArticles
        }
        return spaceArticles.filter { $0.categoryId == selectedCategoryId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航
            headerView
            
            // 分类TabBar
            categoryTabBar
            
            // 文章列表
            articleList
        }
        .background(isDarkMode ? Color.black : Color.white)
        .navigationBarHidden(true)
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showingAddContent) {
            CreateContentView(
                space: space,
                categories: categories,
                isDarkMode: isDarkMode,
                onSave: { saveData in
                    handleContentSave(saveData)
                }
            )
        }
        .sheet(isPresented: $showingEditSpace) {
            EditSpaceView(
                space: space,
                categories: categories,
                isDarkMode: isDarkMode,
                onSpaceUpdated: { updatedSpace in
                    updateSpace(updatedSpace)
                }
            )
        }
        .sheet(isPresented: $showingEditContent) {
            Group {
                if let editingArticle = editingArticle, let editingRecording = editingRecording {
                    EditContentView(
                        article: editingArticle,
                        recording: editingRecording,
                        space: space,
                        categories: categories,
                        isDarkMode: isDarkMode,
                        onSave: { saveData in
                            handleContentEdit(saveData)
                        }
                    )
                    .onAppear {
                        print("✅ edit-space-articalcard--- [EditContentView] 成功显示")
                        print("   edit-space-articalcard--- article.id: \(editingArticle.id)")
                        print("   edit-space-articalcard--- recording.id: \(editingRecording.id)")
                        print("   edit-space-articalcard--- recording.title: \(editingRecording.title)")
                        print("   edit-space-articalcard--- space.name: \(space.name)")
                        print("   edit-space-articalcard--- categories.count: \(categories.count)")
                    }
                } else {
                    // 添加空状态日志
                    Text("加载中...")
                        .onAppear {
                            print("❌ edit-space-articalcard--- [Sheet] 数据未准备好")
                            print("   edit-space-articalcard--- editingArticle: \(editingArticle?.id.uuidString ?? "nil")")
                            print("   edit-space-articalcard--- editingRecording: \(editingRecording?.id.uuidString ?? "nil")")
                        }
                }
            }
        }
        .onChange(of: showingEditContent) { newValue in
            print("🔄 edit-space-articalcard--- [Sheet状态] showingEditContent 变化: \(newValue)")
            if newValue {
                print("   edit-space-articalcard--- 当前 editingArticle: \(editingArticle?.id.uuidString ?? "nil")")
                print("   edit-space-articalcard--- 当前 editingRecording: \(editingRecording?.id.uuidString ?? "nil")")
            }
        }
        .alert("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteSpace()
            }
        } message: {
            Text("确定要删除空间“\(space.name)”吗？此操作将删除该空间下的所有内容，且无法恢复。")
        }
    }
    
    // MARK: - 顶部导航
    private var headerView: some View {
        HStack(spacing: 16) {
            // 返回按钮
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                    .frame(width: 32, height: 32)
            }
            
            Spacer()
            
            // 空间名称
            Text(space.name)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isDarkMode ? .white : .black)
                .tracking(0.2)
            
            Spacer()
            
            // 菜单按钮
            Menu {
                Button(action: {
                    showingAddContent = true
                }) {
                    Label("添加内容", systemImage: "plus")
                }
                Button(action: {
                    showingEditSpace = true
                }) {
                    Label("编辑空间", systemImage: "pencil")
                }
                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("删除空间", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
//        .background(isDarkMode ? Color.black : Color.white)
    }
    
    // MARK: - 分类TabBar
    private var categoryTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 32) {
                ForEach(categories) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedCategoryId = category.id
                            showUncategorized = false
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(category.name)
                                .font(.system(size: 14, weight: selectedCategoryId == category.id && !showUncategorized ? .medium : .regular))
                                .foregroundColor(selectedCategoryId == category.id && !showUncategorized ?
                                                (isDarkMode ? .white : .black) :
                                                (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
                                .tracking(0.3)
                            
                            // 极简指示线
                            Rectangle()
                                .fill(isDarkMode ? Color.white : Color.black)
                                .frame(width: 16, height: 2)
                                .cornerRadius(1)
                                .opacity(selectedCategoryId == category.id && !showUncategorized ? 1 : 0)
                                .animation(.easeInOut(duration: 0.25), value: selectedCategoryId)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 未分类标签 - 只有存在未分类文章时才显示
                if !uncategorizedArticles.isEmpty {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showUncategorized = true
                            selectedCategoryId = nil
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text("未分类")
                                .font(.system(size: 14, weight: showUncategorized ? .medium : .regular))
                                .foregroundColor(showUncategorized ?
                                                (isDarkMode ? .white : .black) :
                                                (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
                                .tracking(0.3)
                            
                            // 极简指示线
                            Rectangle()
                                .fill(isDarkMode ? Color.white : Color.black)
                                .frame(width: 16, height: 2)
                                .cornerRadius(1)
                                .opacity(showUncategorized ? 1 : 0)
                                .animation(.easeInOut(duration: 0.25), value: showUncategorized)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
//        .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
    }
    
    // MARK: - 文章列表
    private var articleList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 1) {
                ForEach(filteredArticles) { article in
                    if let recording = recordings[article.audioRecordingId] {
                        ArticleCard(
                            article: article,
                            recording: recording,
                            isDarkMode: isDarkMode,
                            onToggleMark: {
                                toggleArticleMark(article)
                            },
                            onDelete: {
                                deleteArticle(article)
                            },
                            onEdit: {
                                editArticle(article, recording)
                            }
                        )
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Data Loading
    private func loadData() {
        // 加载类别
        categories = DatabaseManager.shared.getCategories(for: space.id)
        
        // 加载所有文章
        spaceArticles = DatabaseManager.shared.getArticlesForSpace(space.id)
        
        // 加载未分类文章
        uncategorizedArticles = DatabaseManager.shared.getUncategorizedArticlesForSpace(space.id)
        
        // 如果没有选中的分类且有分类，默认选中第一个
        if selectedCategoryId == nil && !categories.isEmpty && !showUncategorized {
            selectedCategoryId = categories.first?.id
        }
        
        // 加载录音数据
        for article in spaceArticles {
            if let recording = DatabaseManager.shared.getRecording(by: article.audioRecordingId.uuidString) {
                recordings[article.audioRecordingId] = recording
            }
        }
    }
    
    // MARK: - Actions
    private func handleContentSave(_ saveData: CreateContentData) {
        // saveData包含用户输入的文本内容和元数据
        // 我们需要先创建AudioRecording，然后保存到空间
        
        // 创建新的录音记录
        let newRecording = AudioRecording(
            timestamp: Date(),
            duration: 0, // 手动录入的内容没有时长
            transcription: saveData.content,
            title: saveData.title,
            summary: saveData.content.prefix(100).description, // 使用内容前100字符作为摘要
            tags: saveData.tags,
            audioData: nil, // 手动录入没有音频数据
            enrichedContent: nil,
            polishedText: saveData.content,
            contentType: "thinking" // 默认为思考类型，可根据需要调整
        )
        
        // 先保存录音记录
        let recordingSaved = DatabaseManager.shared.saveRecording(newRecording)
        
        if recordingSaved {
            // 然后添加到空间
            let addToSpaceSuccess = DatabaseManager.shared.addRecordingToSpace(
                recordingId: newRecording.id,
                spaceId: space.id,
                categoryId: saveData.selectedCategoryId
            )
            
            DispatchQueue.main.async {
                if addToSpaceSuccess {
                    print("✅ 新内容成功创建并添加到空间")
                    
                    // 刷新空间内容列表
                    self.loadData()
                    
                    // TODO: 显示成功提示
                    // ToastManager.shared.showSuccess("内容已添加到空间")
                } else {
                    print("❌ 添加到空间失败")
                    // TODO: 显示错误提示
                    // ToastManager.shared.showError("添加到空间失败")
                }
            }
        } else {
            DispatchQueue.main.async {
                print("❌ 创建录音记录失败")
                // TODO: 显示错误提示
                // ToastManager.shared.showError("创建内容失败")
            }
        }
    }
    
    private func editArticle(_ article: SpaceArticle, _ recording: AudioRecording) {
        print("🔧 edit-space-articalcard--- [editArticle] 开始设置编辑状态")
        print("   edit-space-articalcard--- article.id: \(article.id)")
        print("   edit-space-articalcard--- recording.id: \(recording.id)")
        print("   edit-space-articalcard--- recording.title: \(recording.title)")
        print("   edit-space-articalcard--- recording.polishedText 长度: \(recording.polishedText.count)")
        print("   edit-space-articalcard--- 设置前 editingArticle: \(editingArticle?.id.uuidString ?? "nil")")
        print("   edit-space-articalcard--- 设置前 editingRecording: \(editingRecording?.id.uuidString ?? "nil")")
        
        editingArticle = article
        editingRecording = recording
        
        print("   edit-space-articalcard--- 设置后 editingArticle: \(editingArticle?.id.uuidString ?? "nil")")
        print("   edit-space-articalcard--- 设置后 editingRecording: \(editingRecording?.id.uuidString ?? "nil")")
        
        showingEditContent = true
        print("   edit-space-articalcard--- showingEditContent 设置为: true")
    }
    
    private func handleContentEdit(_ saveData: EditContentData) {
        print("💾 edit-space-articalcard--- [handleContentEdit] 开始处理编辑保存")
        
        guard let editingArticle = editingArticle,
              let editingRecording = editingRecording else {
            print("   ❌ edit-space-articalcard--- 编辑数据为空，无法保存")
            print("   edit-space-articalcard--- editingArticle: \(editingArticle?.id.uuidString ?? "nil")")
            print("   edit-space-articalcard--- editingRecording: \(editingRecording?.id.uuidString ?? "nil")")
            return
        }
        
        // 更新录音记录
        let updatedRecording = AudioRecording(
            id: editingRecording.id,
            timestamp: editingRecording.timestamp,
            duration: editingRecording.duration,
            transcription: saveData.content,
            title: saveData.title,
            summary: saveData.content.prefix(100).description,
            tags: saveData.tags,
            audioData: editingRecording.audioData,
            enrichedContent: editingRecording.enrichedContent,
            polishedText: saveData.content,
            contentType: editingRecording.contentType
        )
        
        // 更新录音记录
        let recordingUpdated = DatabaseManager.shared.updateRecording(updatedRecording)
        
        if recordingUpdated {
            // 如果类别发生变化，更新文章的类别
            if editingArticle.categoryId != saveData.selectedCategoryId {
                let updateCategorySuccess = DatabaseManager.shared.updateRecordingCategory(
                    recordingId: editingRecording.id,
                    spaceId: space.id,
                    categoryId: saveData.selectedCategoryId
                )
                
                if updateCategorySuccess {
                    print("✅ 文章类别更新成功")
                } else {
                    print("❌ 文章类别更新失败")
                }
            }
            
            DispatchQueue.main.async {
                print("✅ edit-space-articalcard--- 内容编辑成功")
                
                print("🧹 edit-space-articalcard--- [handleContentEdit] 清理编辑状态")
                // 重置编辑状态
                self.editingArticle = nil
                self.editingRecording = nil
                
                // 刷新数据
                self.loadData()
                
                // TODO: 显示成功提示
                // ToastManager.shared.showSuccess("内容已更新")
            }
        } else {
            DispatchQueue.main.async {
                print("❌ 内容编辑失败")
                // TODO: 显示错误提示
                // ToastManager.shared.showError("内容更新失败")
            }
        }
    }
    
    private func toggleArticleMark(_ article: SpaceArticle) {
        if DatabaseManager.shared.toggleArticleImportantMark(articleId: article.id) {
            loadData()
        }
    }
    
    private func deleteArticle(_ article: SpaceArticle) {
        if DatabaseManager.shared.removeRecordingFromSpace(
            recordingId: article.audioRecordingId,
            spaceId: space.id
        ) {
            loadData()
        }
    }
    
    private func deleteSpace() {
        if DatabaseManager.shared.deleteSpace(id: space.id) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func updateSpace(_ updatedSpace: Space) {
        // 更新数据库中的空间信息
        if DatabaseManager.shared.updateSpace(updatedSpace) {
            // 更新本地的 space 状态以刷新 UI
            space = updatedSpace
            loadData()
        }
    }
}

// MARK: - Preview
struct SpaceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSpace = Space(name: "示例空间", description: "这是一个示例空间")
        
        Group {
            SpaceDetailView(space: sampleSpace)
                .previewDisplayName("Light Mode")
            
            SpaceDetailView(space: sampleSpace)
                .previewDisplayName("Dark Mode")
                .preferredColorScheme(.dark)
        }
    }
}
