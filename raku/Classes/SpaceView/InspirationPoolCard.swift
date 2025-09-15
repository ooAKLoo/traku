//
//  InspirationPoolCard.swift
//  raku
//
//  Created by Claude on 2025/1/15.
//

import SwiftUI

// MARK: - 灵感资源池卡片
struct InspirationPoolCard: View {
    let isDarkMode: Bool
    let onTap: () -> Void
    
    @State private var inspirationCount: Int = 0
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // 图标
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isDarkMode ? .yellow : .orange)
                
                // 标题
                VStack(alignment: .leading, spacing: 4) {
                    Text("灵感资源池")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("共 \(inspirationCount) 条灵感")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                }
                
                Spacer()
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isDarkMode ? Color.yellow.opacity(0.3) : Color.orange.opacity(0.3),
                                    isDarkMode ? Color.orange.opacity(0.3) : Color.yellow.opacity(0.3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: (isDarkMode ? Color.white : Color.black).opacity(0.05), radius: 8, x: 0, y: 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadInspirationCount()
        }
    }
    
    // 从数据库加载灵感数量
    private func loadInspirationCount() {
        // 从数据库查询实际的灵感数量
        inspirationCount = DatabaseManager.shared.getInspirationCount()
    }
}

// MARK: - 灵感列表视图
struct InspirationListView: View {
    let isDarkMode: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var inspirations: [AudioRecording] = []
    @State private var stats: (used: Int, unused: Int) = (0, 0)
    @State private var isSelectionMode = false
    @State private var selectedInspirations: Set<UUID> = []
    @State private var showingBatchSpaceSelection = false
    
    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部拖拽指示器
                dragIndicator
                
                // 标题区域
                headerSection
                
                // 内容区域
                contentSection
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(isDarkMode ? Color.black : Color.white)
        .onAppear {
            loadInspirations()
        }
    }
    
    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                isDarkMode ? Color.black : Color.white,
                isDarkMode ? Color.gray.opacity(0.1) : Color.gray.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - 拖拽指示器
    private var dragIndicator: some View {
        VStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                .frame(width: 36, height: 5)
                .shadow(color: isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), radius: 1, y: 1)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - 标题区域
    private var headerSection: some View {
        VStack(spacing: 24) {
            // 主标题和操作按钮
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(isDarkMode ? .yellow : .orange)
                            .scaleEffect(1.1)
                        
                        Text("灵感资源池")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .tracking(-0.5)
                    }
                    
                    Text("收集与整理你的思维火花")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
                }
                
                Spacer()
                
                // 批量操作按钮
                if !inspirations.isEmpty {
                    Button(action: {
                        toggleSelectionMode()
                    }) {
                        Text(isSelectionMode ? "取消" : "批量")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // 批量操作工具栏
            if isSelectionMode {
                batchToolbar
            }
            
            // 统计信息
            if !isSelectionMode {
                HStack(spacing: 20) {
                    StatCard(
                        title: "已使用",
                        value: "\(stats.used)",
                        icon: "checkmark.circle.fill",
                        color: isDarkMode ? .green : .green,
                        isDarkMode: isDarkMode
                    )
                    
                    StatCard(
                        title: "未使用",
                        value: "\(stats.unused)",
                        icon: "circle.fill",
                        color: isDarkMode ? .orange : .orange,
                        isDarkMode: isDarkMode
                    )
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - 批量操作工具栏
    private var batchToolbar: some View {
        VStack(spacing: 16) {
            // 选择状态
            HStack {
                Text("已选择 \(selectedInspirations.count) 项")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                Spacer()
                
                Button(selectedInspirations.count == inspirations.count ? "取消全选" : "全选") {
                    if selectedInspirations.count == inspirations.count {
                        selectedInspirations.removeAll()
                    } else {
                        selectedInspirations = Set(inspirations.map { $0.id })
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            
            // 批量操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    showingBatchSpaceSelection = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                        
                        Text("添加到空间")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(selectedInspirations.isEmpty ? Color.gray : Color.blue)
                    )
                }
                .disabled(selectedInspirations.isEmpty)
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - 内容区域
    private var contentSection: some View {
        Group {
            if inspirations.isEmpty {
                emptyStateView
            } else {
                inspirationListContent
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.08))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                }
                
                VStack(spacing: 8) {
                    Text("暂无灵感记录")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    
                    Text("开始录制你的第一个想法吧")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 灵感列表内容
    private var inspirationListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(inspirations, id: \.id) { inspiration in
                    InspirationRowView(
                        inspiration: inspiration, 
                        isDarkMode: isDarkMode,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedInspirations.contains(inspiration.id),
                        onSelectionToggle: {
                            toggleSelection(for: inspiration.id)
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .animation(.easeInOut(duration: 0.3), value: inspirations.count)
        .sheet(isPresented: $showingBatchSpaceSelection) {
            BatchSpaceSelectionView(
                recordings: selectedInspirations.compactMap { id in
                    inspirations.first { $0.id == id }
                },
                isDarkMode: isDarkMode,
                isPresented: $showingBatchSpaceSelection,
                onCompleted: {
                    exitSelectionMode()
                }
            )
        }
    }
    
    private func loadInspirations() {
        // 从数据库加载实际的灵感数据
        inspirations = DatabaseManager.shared.getInspirationRecordings()
        // 加载优化的统计信息
        stats = DatabaseManager.shared.getInspirationUsageStats()
    }
    
    // MARK: - 批量操作方法
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedInspirations.removeAll()
            }
        }
    }
    
    private func exitSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSelectionMode = false
            selectedInspirations.removeAll()
        }
    }
    
    private func toggleSelection(for id: UUID) {
        if selectedInspirations.contains(id) {
            selectedInspirations.remove(id)
        } else {
            selectedInspirations.insert(id)
        }
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isDarkMode ? .white : .black)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(isDarkMode ? 0.1 : 0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 灵感项数据模型
struct InspirationItem: Identifiable {
    let id: String
    let originalText: String
    let polishedText: String
    let tags: [String]
    let createdAt: Date
    
    static let mockData = [
        InspirationItem(
            id: UUID().uuidString,
            originalText: "找合作伙伴不等于找朋友",
            polishedText: "找合作伙伴不等于找朋友",
            tags: ["商业", "合作"],
            createdAt: Date()
        ),
        InspirationItem(
            id: UUID().uuidString,
            originalText: "人生得意须尽欢，莫使金樽空对月",
            polishedText: "人生得意须尽欢，莫使金樽空对月",
            tags: ["诗词", "人生"],
            createdAt: Date().addingTimeInterval(-3600)
        ),
        InspirationItem(
            id: UUID().uuidString,
            originalText: "大道至简",
            polishedText: "大道至简",
            tags: ["哲学", "智慧"],
            createdAt: Date().addingTimeInterval(-7200)
        )
    ]
}

// MARK: - 灵感行视图
struct InspirationRowView: View {
    let inspiration: AudioRecording
    let isDarkMode: Bool
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)?
    
    @State private var showingSpaceSelection = false
    
    var body: some View {
        HStack {
            // 选择按钮（批量模式下显示）
            if isSelectionMode {
                Button(action: {
                    onSelectionToggle?()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isSelected ? .blue : (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            contentView
            
            // 添加到空间按钮（单条模式下显示）
            if !isSelectionMode {
                Button(action: {
                    showingSpaceSelection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isDarkMode ? .blue.opacity(0.8) : .blue)
                        .background(
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white)
                                .frame(width: 32, height: 32)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? (isDarkMode ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05)) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .sheet(isPresented: $showingSpaceSelection) {
            SpaceSelectionView(
                recording: inspiration,
                isDarkMode: isDarkMode,
                isPresented: $showingSpaceSelection
            )
        }
        .onTapGesture {
            if isSelectionMode {
                onSelectionToggle?()
            }
        }
    }
    
    // MARK: - 主内容
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspirationText
            tagsAndTime
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - 灵感文本
    private var inspirationText: some View {
        Text(inspiration.polishedText)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isDarkMode ? .white : .black)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }
    
    // MARK: - 标签和时间
    private var tagsAndTime: some View {
        HStack {
            tagsView
            Spacer()
            timeView
        }
    }
    
    // MARK: - 标签视图
    private var tagsView: some View {
        HStack(spacing: 6) {
            ForEach(inspiration.tags, id: \.self) { tag in
                tagItem(tag)
            }
        }
    }
    
    // MARK: - 单个标签
    private func tagItem(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 12))
            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tagItemBackground)
    }
    
    // MARK: - 标签背景
    private var tagItemBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
    }
    
    // MARK: - 时间视图
    private var timeView: some View {
        Text(formatDate(inspiration.timestamp))
            .font(.system(size: 12))
            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
    }
    
    // MARK: - 卡片背景
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 空间选择视图
struct SpaceSelectionView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    @Binding var isPresented: Bool
    
    @State private var spaces: [Space] = []
    @State private var selectedSpace: Space?
    @State private var categories: [Category] = []
    @State private var selectedCategory: Category?
    @State private var isLoading = false
    @State private var showingSuccessMessage = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 灵感预览
                inspirationPreview
                
                Divider()
                    .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                
                // 空间和类别选择
                selectionContent
            }
            .background(isDarkMode ? Color.black : Color.white)
            .navigationTitle("添加到空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        addToSpace()
                    }
                    .disabled(selectedSpace == nil || isLoading)
                    .foregroundColor(canAdd ? (isDarkMode ? .blue.opacity(0.9) : .blue) : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                }
            }
        }
        .onAppear {
            loadSpaces()
        }
        .alert("添加成功", isPresented: $showingSuccessMessage) {
            Button("确定") {
                isPresented = false
            }
        } message: {
            Text("灵感已成功添加到空间")
        }
    }
    
    // MARK: - 灵感预览
    private var inspirationPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .yellow : .orange)
                
                Text("即将添加的灵感")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                Spacer()
            }
            
            Text(recording.polishedText.isEmpty ? recording.title : recording.polishedText)
                .font(.system(size: 16))
                .foregroundColor(isDarkMode ? .white : .black)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            if !recording.tags.isEmpty {
                HStack {
                    ForEach(recording.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(20)
    }
    
    // MARK: - 选择内容
    private var selectionContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 空间选择
                spaceSelectionSection
                
                // 类别选择（如果选择了空间）
                if selectedSpace != nil {
                    categorySelectionSection
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 空间选择区域
    private var spaceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择空间")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
            }
            
            if spaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                    
                    Text("暂无空间")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    
                    Text("请先创建一个空间")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(spaces) { space in
                        SpaceSelectionCard(
                            space: space,
                            isSelected: selectedSpace?.id == space.id,
                            isDarkMode: isDarkMode
                        ) {
                            selectedSpace = space
                            loadCategories(for: space)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 类别选择区域
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择类别")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Text("（可选）")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                
                Spacer()
            }
            
            if categories.isEmpty {
                VStack(spacing: 8) {
                    Text("该空间暂无类别")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    
                    Text("灵感将被添加为未分类")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // 未分类选项
                CategorySelectionCard(
                    title: "未分类",
                    isSelected: selectedCategory == nil,
                    isDarkMode: isDarkMode
                ) {
                    selectedCategory = nil
                }
                
                // 类别列表
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(categories) { category in
                        CategorySelectionCard(
                            title: category.name,
                            isSelected: selectedCategory?.id == category.id,
                            isDarkMode: isDarkMode
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 计算属性
    private var canAdd: Bool {
        selectedSpace != nil && !isLoading
    }
    
    // MARK: - 数据加载方法
    private func loadSpaces() {
        spaces = DatabaseManager.shared.getAllSpaces()
    }
    
    private func loadCategories(for space: Space) {
        categories = DatabaseManager.shared.getCategories(for: space.id)
        selectedCategory = nil // 重置类别选择
    }
    
    // MARK: - 添加到空间
    private func addToSpace() {
        guard let space = selectedSpace else { return }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let success = DatabaseManager.shared.addRecordingToSpace(
                recordingId: recording.id,
                spaceId: space.id,
                categoryId: selectedCategory?.id
            )
            
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    showingSuccessMessage = true
                } else {
                    // 可以添加错误处理
                    print("添加到空间失败")
                }
            }
        }
    }
}

// MARK: - 空间选择卡片
struct SpaceSelectionCard: View {
    let space: Space
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            descriptionText
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    private var titleRow: some View {
        HStack {
            spaceNameText
            Spacer()
            selectionCheckmark
        }
    }
    
    private var spaceNameText: some View {
        Text(space.name)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isDarkMode ? .white : .black)
            .lineLimit(1)
    }
    
    private var selectionCheckmark: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var descriptionText: some View {
        Group {
            if !space.description.isEmpty {
                Text(space.description)
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .lineLimit(2)
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(backgroundFill)
            .overlay(backgroundStroke)
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return isDarkMode ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)
        } else {
            return isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.05)
        }
    }
    
    private var backgroundStroke: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(strokeColor, lineWidth: strokeWidth)
    }
    
    private var strokeColor: Color {
        if isSelected {
            return isDarkMode ? Color.blue.opacity(0.8) : Color.blue
        } else {
            return isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2)
        }
    }
    
    private var strokeWidth: CGFloat {
        return isSelected ? 2 : 1
    }
}

// MARK: - 类别选择卡片
struct CategorySelectionCard: View {
    let title: String
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var cardContent: some View {
        HStack {
            titleText
            Spacer()
            selectionIcon
        }
        .padding(12)
        .background(cardBackground)
    }
    
    private var titleText: some View {
        Text(title)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(isDarkMode ? .white : .black)
            .lineLimit(1)
    }
    
    private var selectionIcon: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(backgroundFill)
            .overlay(backgroundStroke)
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return isDarkMode ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1)
        } else {
            return isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.05)
        }
    }
    
    private var backgroundStroke: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(strokeColor, lineWidth: strokeWidth)
    }
    
    private var strokeColor: Color {
        if isSelected {
            return isDarkMode ? Color.blue.opacity(0.8) : Color.blue
        } else {
            return isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2)
        }
    }
    
    private var strokeWidth: CGFloat {
        return isSelected ? 2 : 1
    }
}

// MARK: - 批量空间选择视图
struct BatchSpaceSelectionView: View {
    let recordings: [AudioRecording]
    let isDarkMode: Bool
    @Binding var isPresented: Bool
    let onCompleted: () -> Void
    
    @State private var spaces: [Space] = []
    @State private var selectedSpace: Space?
    @State private var categories: [Category] = []
    @State private var selectedCategory: Category?
    @State private var isLoading = false
    @State private var showingSuccessMessage = false
    @State private var successCount = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 批量预览
                batchPreview
                
                Divider()
                    .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                
                // 空间和类别选择
                selectionContent
            }
            .background(isDarkMode ? Color.black : Color.white)
            .navigationTitle("批量添加到空间")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        batchAddToSpace()
                    }
                    .disabled(selectedSpace == nil || isLoading || recordings.isEmpty)
                    .foregroundColor(canAdd ? (isDarkMode ? .blue.opacity(0.9) : .blue) : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                }
            }
        }
        .onAppear {
            loadSpaces()
        }
        .alert("批量添加完成", isPresented: $showingSuccessMessage) {
            Button("确定") {
                onCompleted()
                isPresented = false
            }
        } message: {
            Text("成功添加 \(successCount) 条灵感到空间")
        }
    }
    
    // MARK: - 批量预览
    private var batchPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .yellow : .orange)
                
                Text("即将批量添加 \(recordings.count) 条灵感")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                Spacer()
            }
            
            // 显示前几条灵感预览
            VStack(alignment: .leading, spacing: 8) {
                ForEach(recordings.prefix(3), id: \.id) { recording in
                    HStack {
                        Circle()
                            .fill(isDarkMode ? Color.blue.opacity(0.6) : Color.blue)
                            .frame(width: 6, height: 6)
                        
                        Text(recording.polishedText.isEmpty ? recording.title : recording.polishedText)
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                if recordings.count > 3 {
                    HStack {
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                            .frame(width: 6, height: 6)
                        
                        Text("还有 \(recordings.count - 3) 条...")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    }
                }
            }
        }
        .padding(20)
    }
    
    // MARK: - 选择内容（复用单条选择的逻辑）
    private var selectionContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 空间选择
                spaceSelectionSection
                
                // 类别选择（如果选择了空间）
                if selectedSpace != nil {
                    categorySelectionSection
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 空间选择区域
    private var spaceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择空间")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
            }
            
            if spaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                    
                    Text("暂无空间")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    
                    Text("请先创建一个空间")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(spaces) { space in
                        SpaceSelectionCard(
                            space: space,
                            isSelected: selectedSpace?.id == space.id,
                            isDarkMode: isDarkMode
                        ) {
                            selectedSpace = space
                            loadCategories(for: space)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 类别选择区域
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择类别")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Text("（可选）")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                
                Spacer()
            }
            
            if categories.isEmpty {
                VStack(spacing: 8) {
                    Text("该空间暂无类别")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    
                    Text("灵感将被添加为未分类")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // 未分类选项
                CategorySelectionCard(
                    title: "未分类",
                    isSelected: selectedCategory == nil,
                    isDarkMode: isDarkMode
                ) {
                    selectedCategory = nil
                }
                
                // 类别列表
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(categories) { category in
                        CategorySelectionCard(
                            title: category.name,
                            isSelected: selectedCategory?.id == category.id,
                            isDarkMode: isDarkMode
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 计算属性
    private var canAdd: Bool {
        selectedSpace != nil && !isLoading && !recordings.isEmpty
    }
    
    // MARK: - 数据加载方法
    private func loadSpaces() {
        spaces = DatabaseManager.shared.getAllSpaces()
    }
    
    private func loadCategories(for space: Space) {
        categories = DatabaseManager.shared.getCategories(for: space.id)
        selectedCategory = nil // 重置类别选择
    }
    
    // MARK: - 批量添加到空间
    private func batchAddToSpace() {
        guard let space = selectedSpace else { return }
        
        isLoading = true
        successCount = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            for recording in recordings {
                let success = DatabaseManager.shared.addRecordingToSpace(
                    recordingId: recording.id,
                    spaceId: space.id,
                    categoryId: selectedCategory?.id
                )
                
                if success {
                    successCount += 1
                }
            }
            
            DispatchQueue.main.async {
                isLoading = false
                showingSuccessMessage = true
            }
        }
    }
}

// MARK: - Preview
struct InspirationPoolCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 浅色模式
            InspirationPoolCard(isDarkMode: false) {
                print("Tapped inspiration pool")
            }
            .padding(20)
            .background(Color.gray.opacity(0.1))
            .previewDisplayName("Light Mode")
            
            // 深色模式
            InspirationPoolCard(isDarkMode: true) {
                print("Tapped inspiration pool")
            }
            .padding(20)
            .background(Color.black)
            .previewDisplayName("Dark Mode")
            
            // 列表视图
            InspirationListView(isDarkMode: true)
                .previewDisplayName("Inspiration List")
        }
    }
}