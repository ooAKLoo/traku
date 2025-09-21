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
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var showingEditSpace = false
    @State private var showUncategorized = false
    @State private var showingDeleteConfirmation = false
    
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
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(
                spaceId: space.id,
                isDarkMode: isDarkMode,
                onSave: { categoryName in
                    createCategory(name: categoryName)
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
                    showingAddCategory = true
                }) {
                    Label("添加", systemImage: "plus")
                }
                Button(action: {
                    showingEditSpace = true
                }) {
                    Label("编辑", systemImage: "pencil")
                }
                Button(role: .destructive, action: {
                    showingDeleteConfirmation = true
                }) {
                    Label("删除", systemImage: "trash")
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
    private func createCategory(name: String) {
        let category = Category(spaceId: space.id, name: name)
        if DatabaseManager.shared.createCategory(category) {
            loadData()
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
