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
    @State private var recordings: [UUID: AudioRecording] = [:]
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var showingEditSpace = false
    
    init(space: Space) {
        self._space = State(initialValue: space)
    }
    
    // 过滤后的文章
    private var filteredArticles: [SpaceArticle] {
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
        .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
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
                    deleteSpace()
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
        .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
    }
    
    // MARK: - 分类TabBar
    private var categoryTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 32) {
                ForEach(categories) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedCategoryId = category.id
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(category.name)
                                .font(.system(size: 14, weight: selectedCategoryId == category.id ? .medium : .regular))
                                .foregroundColor(selectedCategoryId == category.id ?
                                                (isDarkMode ? .white : .black) :
                                                (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
                                .tracking(0.3)
                            
                            // 极简指示线
                            Rectangle()
                                .fill(isDarkMode ? Color.white : Color.black)
                                .frame(width: 16, height: 2)
                                .cornerRadius(1)
                                .opacity(selectedCategoryId == category.id ? 1 : 0)
                                .animation(.easeInOut(duration: 0.25), value: selectedCategoryId)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
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
        
        // 如果没有选中的分类且有分类，默认选中第一个
        if selectedCategoryId == nil && !categories.isEmpty {
            selectedCategoryId = categories.first?.id
        }
        
        // 加载文章
        spaceArticles = DatabaseManager.shared.getArticlesForSpace(space.id)
        
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

// MARK: - 文章卡片
struct ArticleCard: View {
    let article: SpaceArticle
    let recording: AudioRecording
    let isDarkMode: Bool
    let onToggleMark: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var isDeleting = false
    @State private var hasTriggeredHaptic = false
    
    // 删除阈值（圆环完全闭合的滑动距离）
    private let deleteThreshold: CGFloat = -180
    private let maxSwipeDistance: CGFloat = -220
    // 标记阈值（向右滑动标记的距离）
    private let markThreshold: CGFloat = 30
    private let maxMarkDistance: CGFloat = 50
    
    // 计算删除进度 (0 到 1)
    private var deleteProgress: CGFloat {
        guard offset < 0 else { return 0 }
        return min(abs(offset) / abs(deleteThreshold), 1.0)
    }
    
    // 根据进度计算颜色深度
    private var trashColor: Color {
        if deleteProgress < 0.5 {
            return Color.orange.opacity(0.7 + Double(deleteProgress * 0.3))
        } else {
            return Color.red.opacity(0.7 + Double(deleteProgress * 0.3))
        }
    }
    
    var body: some View {
        ZStack {
            // 右侧删除区域
            HStack {
                Spacer()
                
                // 圆环进度垃圾桶
                ZStack {
                    // 进度圆环
                    if deleteProgress < 1 {
                        Circle()
                            .trim(from: 0, to: deleteProgress)
                            .stroke(
                                trashColor,
                                style: StrokeStyle(
                                    lineWidth: 3,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: deleteProgress)
                    }
                    
                    // 垃圾桶图标或对勾
                    Image(systemName: deleteProgress == 1 ? "checkmark" : "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(deleteProgress == 1 ? Color.red : trashColor)
                        .scaleEffect(deleteProgress == 1 ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: deleteProgress)
                        .onChange(of: deleteProgress == 1) { showingCheckmark in
                            if showingCheckmark && !hasTriggeredHaptic {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                hasTriggeredHaptic = true
                            } else if !showingCheckmark {
                                hasTriggeredHaptic = false
                            }
                        }
                }
                .frame(width: 60)
                .opacity(offset < -10 ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: offset < -10)
            }
            
            // 主内容
            HStack(alignment: .top, spacing: 16) {
                // 左侧时间线
                VStack(alignment: .center, spacing: 0) {
                    // 时间点 - 根据标记状态显示
                    Circle()
                        .fill(circleColor)
                        .frame(width: circleSize, height: circleSize)
                        .onTapGesture {
                            onToggleMark()
                        }
                    
                    // 连接线
                    Rectangle()
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                        .frame(width: 0.5)
                }
                .padding(.top, 8)
                
                // 内容区域
                VStack(alignment: .leading, spacing: 8) {
                    // 润色后的内容，如果没有则显示标题
                    Text(recording.polishedText.isEmpty ? recording.title : recording.polishedText)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    
                    // 显示创建时间 - 极简风格
                    Text(ArticleCard.formatMinimalTimestamp(article.createdAt))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(isDarkMode ? .white.opacity(0.25) : .black.opacity(0.25))
                        .tracking(0.5)
                }
                .padding(.trailing, 20)
                .padding(.vertical, 16)
                
                Spacer(minLength: 0)
            }
            .padding(.leading, 20)
            .background(
                Rectangle()
                    .fill(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
            )
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring(response: 0.3)) {
                            if !isDragging {
                                isDragging = true
                            }
                            
                            let translation = value.translation.width
                            
                            // 向左滑动删除
                            if translation < 0 {
                                offset = max(translation, maxSwipeDistance)
                            }
                            // 向右滑动标记
                            else if translation > 0 {
                                offset = min(translation, maxMarkDistance)
                            }
                            // 从任何方向回到中心
                            else if offset != 0 {
                                offset = translation / 3
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isDragging = false
                            
                            // 向右滑动标记逻辑（轻微滑动即可触发）
                            if offset > markThreshold {
                                // 触发标记切换
                                onToggleMark()
                                // 弹回原位
                                offset = 0
                            }
                            // 向左滑动删除逻辑
                            else if deleteProgress >= 1.0 {
                                isDeleting = true
                                // 滑出屏幕动画
                                withAnimation(.easeOut(duration: 0.3)) {
                                    offset = -UIScreen.main.bounds.width
                                }
                                // 延迟后删除
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDelete()
                                }
                            }
                            // 其他情况弹回原位
                            else {
                                offset = 0
                            }
                        }
                    }
            )
        }
    }
    
    // MARK: - 圆点样式计算
    private var circleColor: Color {
        if article.isMarkedImportant {
            // 已标记：纯黑/纯白
            return isDarkMode ? Color.white : Color.black
        } else {
            // 未标记：半透明
            return isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
        }
    }
    
    private var circleSize: CGFloat {
        return 5  // 统一大小
    }
    
    // MARK: - Date Formatting
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        // 如果是今天
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        
        // 如果是昨天
        if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: date)
        }
        
        // 如果是今年
        let dateYear = calendar.component(.year, from: date)
        let currentYear = calendar.component(.year, from: now)
        
        if dateYear == currentYear {
            formatter.dateFormat = "M月d日 HH:mm"
        } else {
            formatter.dateFormat = "yyyy年M月d日 HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    // MARK: - 极简时间格式
    static func formatMinimalTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            if day == 1 {
                return "昨天"
            } else if day < 7 {
                return "\(day)天前"
            } else if day < 30 {
                return "\(day / 7)周前"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM.dd"
                return formatter.string(from: date)
            }
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        } else {
            return "刚刚"
        }
    }
}

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
                        categoriesSection
                        
                        // 添加类别
                        addCategorySection
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
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("类别管理", systemImage: "folder.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
                
                Spacer()
                
                Text("\(editableCategories.count) 个类别")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
            }
            
            if editableCategories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 24))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                    
                    Text("还没有类别")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(editableCategories) { category in
                        EditCategoryCard(
                            category: category,
                            isDarkMode: isDarkMode,
                            onDelete: {
                                deleteCategory(category)
                            }
                        )
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
    
    // MARK: - 添加类别区域
    private var addCategorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("添加新类别", systemImage: "plus.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.8))
            
            HStack(spacing: 12) {
                TextField("类别名称", text: $newCategoryName)
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

// MARK: - 编辑类别卡片
struct EditCategoryCard: View {
    let category: Category
    let isDarkMode: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(category.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isDarkMode ? .white : .black)
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.1), lineWidth: 0.5)
                )
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
