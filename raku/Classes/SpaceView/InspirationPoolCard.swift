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
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var sparkleRotation = 0.0
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 灵动的图标容器
                ZStack {
                    // 背景光晕效果
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (isDarkMode ? Color.yellow.opacity(0.15) : Color.orange.opacity(0.2)),
                                    (isDarkMode ? Color.yellow.opacity(0.05) : Color.orange.opacity(0.05)),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 5,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)
                        .blur(radius: 3)
                        .scaleEffect(isHovered ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                    
                    Circle()
                        .fill(isDarkMode ? Color(hex: "2A2A2A") : Color.white)
                        .frame(width: 42, height: 42)
                        .shadow(color: (isDarkMode ? Color.yellow : Color.orange).opacity(0.2), radius: 8, x: 0, y: 2)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isDarkMode ? Color(hex: "FFD700") : Color(hex: "FF8C00"))
                        .rotationEffect(.degrees(sparkleRotation))
                        .scaleEffect(isHovered ? 1.1 : 1.0)
                }
                
                // 内容
                VStack(alignment: .leading, spacing: 6) {
                    Text("灵感资源池")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isDarkMode ? Color.yellow.opacity(0.6) : Color.orange.opacity(0.6))
                        
                        Text("\(inspirationCount) 条闪光时刻")
                            .font(.system(size: 13))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // 动态箭头
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.4))
                    .offset(x: isHovered ? 3 : 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isDarkMode ? Color(hex: "1A1A1A") : Color.white)
                    .shadow(
                        color: (isDarkMode ? Color.yellow : Color.orange).opacity(0.1),
                        radius: 16,
                        x: 0,
                        y: 8
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
            if hovering {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    sparkleRotation = 10
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    sparkleRotation = 0
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }) {}
        .onAppear {
            loadInspirationCount()
            // 初始动画
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                isHovered = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.4)) {
                    isHovered = false
                }
            }
        }
    }
    
    // 从数据库加载灵感数量
    private func loadInspirationCount() {
        inspirationCount = DatabaseManager.shared.getInspirationCount()
    }
}

// MARK: - 灵感列表视图
struct InspirationListView: View {
    let isDarkMode: Bool
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var popupManager = GlobalPopupManager.shared
    @State private var inspirations: [AudioRecording] = []
    @State private var allInspirations: [AudioRecording] = []  // 保存所有灵感
    @State private var usedInspirations: [AudioRecording] = []  // 已使用的灵感
    @State private var unusedInspirations: [AudioRecording] = []  // 未使用的灵感
    @State private var stats: (used: Int, unused: Int) = (0, 0)
    @State private var isSelectionMode = false
    @State private var selectedInspirations: Set<UUID> = []
    @State private var showingBatchSpaceSelection = false
    @State private var filterType: FilterType = .all  // 筛选类型
    @State private var emptyAnimationScale: CGFloat = 1.0
    @State private var emptyAnimationOpacity: Double = 0.3
    @State private var emptyIconRotation: Double = 0
    
    enum FilterType {
        case all
        case used
        case unused
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖拽指示器
            dragIndicator
            
            // 标题区域
            headerSection
            
            // 内容区域
            contentSection
        }
        .background(isDarkMode ? Color.black : Color.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(isDarkMode ? Color.black : Color.white)
        .globalPopup()  // 在 sheet 中也需要添加全局浮窗支持
        .environmentObject(popupManager)  // 确保 popupManager 可用
        .onAppear {
            loadInspirations()
        }
        .globalBatchSelectionToolbar(
            isPresented: $isSelectionMode,
            selectedCount: selectedInspirations.count,
            totalCount: inspirations.count,
            actionTitle: "添加到空间",
            actionIcon: "plus.circle.fill",
            onSelectAll: {
                selectedInspirations = Set(inspirations.map { $0.id })
            },
            onDeselectAll: {
                selectedInspirations.removeAll()
            },
            onAction: {
                showingBatchSpaceSelection = true
            }
        )
        .onChange(of: isSelectionMode) { newValue in
            if !newValue {
                selectedInspirations.removeAll()
            }
        }
    }
    
    // MARK: - 拖拽指示器
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.15))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 16)
    }
    
    // MARK: - 标题区域
    private var headerSection: some View {
        VStack(spacing: 20) {
            // 主标题
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(isDarkMode ? Color(hex: "FFD700") : Color(hex: "FF8C00"))
                            .shadow(color: (isDarkMode ? Color.yellow : Color.orange).opacity(0.5), radius: 4)
                        
                        Text("灵感资源池")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isDarkMode ? Color.green.opacity(0.8) : Color.green)
                            .frame(width: 6, height: 6)
                        
                        Text("\(allInspirations.count) 条闪光时刻")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                            .italic()
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // 筛选选项
            if !isSelectionMode {
                HStack(spacing: 12) {
                    FilterButton(
                        title: "全部",
                        isSelected: filterType == .all,
                        isDarkMode: isDarkMode
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            filterType = .all
                            updateFilteredInspirations()
                        }
                    }
                    
                    FilterButton(
                        title: "已使用",
                        count: stats.used,
                        isSelected: filterType == .used,
                        isDarkMode: isDarkMode
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            filterType = .used
                            updateFilteredInspirations()
                        }
                    }
                    
                    FilterButton(
                        title: "未使用",
                        count: stats.unused,
                        isSelected: filterType == .unused,
                        isDarkMode: isDarkMode
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            filterType = .unused
                            updateFilteredInspirations()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 12)
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
        VStack {
            Spacer()
            
            VStack(spacing: 24) {
                // 灵动的图标组合
                ZStack {
                    // 背景光环
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        (isDarkMode ? Color.yellow : Color.orange).opacity(0.2 - Double(index) * 0.05),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .frame(width: CGFloat(60 + index * 20), height: CGFloat(60 + index * 20))
                            .scaleEffect(emptyAnimationScale)
                            .opacity(emptyAnimationOpacity)
                            .animation(
                                Animation.easeInOut(duration: 2.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.3),
                                value: emptyAnimationScale
                            )
                    }
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(isDarkMode ? Color.yellow.opacity(0.5) : Color.orange.opacity(0.6))
                        .rotationEffect(.degrees(emptyIconRotation))
                        .animation(
                            Animation.easeInOut(duration: 4)
                                .repeatForever(autoreverses: true),
                            value: emptyIconRotation
                        )
                }
                
                VStack(spacing: 8) {
                    Text("灵感池空空如也")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                    
                    Text("记录你的第一个闪光时刻吧 ✨")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                }
            }
            .onAppear {
                emptyAnimationScale = 1.2
                emptyAnimationOpacity = 0.5
                emptyIconRotation = 15
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 灵感列表内容
    private var inspirationListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 4) {
                ForEach(inspirations.indices, id: \.self) { index in
                    let inspiration = inspirations[index]
                    InspirationRowView(
                        inspiration: inspiration, 
                        isDarkMode: isDarkMode,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedInspirations.contains(inspiration.id),
                        onSelectionToggle: {
                            toggleSelection(for: inspiration.id)
                        },
                        onLongPress: {
                            if !isSelectionMode {
                                toggleSelectionMode()
                                toggleSelection(for: inspiration.id)
                            }
                        },
                        onSwipeRight: {
                            if !isSelectionMode {
                                toggleSelectionMode()
                                toggleSelection(for: inspiration.id)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .offset(y: 20)),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: inspirations.count)
                    .padding()
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 34)
        }
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
        allInspirations = DatabaseManager.shared.getInspirationRecordings()
        
        // 分类已使用和未使用的灵感
        categorizeInspirations()
        
        // 加载优化的统计信息
        stats = DatabaseManager.shared.getInspirationUsageStats()
        
        // 根据当前筛选类型显示数据
        updateFilteredInspirations()
    }
    
    private func categorizeInspirations() {
        usedInspirations = []
        unusedInspirations = []
        
        for inspiration in allInspirations {
            // 检查这个灵感是否已经被添加到任何空间
            let spaces = DatabaseManager.shared.getAllSpaces()
            var isUsed = false
            
            for space in spaces {
                if DatabaseManager.shared.isRecordingInSpace(recordingId: inspiration.id, spaceId: space.id) {
                    isUsed = true
                    break
                }
            }
            
            if isUsed {
                usedInspirations.append(inspiration)
            } else {
                unusedInspirations.append(inspiration)
            }
        }
    }
    
    private func updateFilteredInspirations() {
        switch filterType {
        case .all:
            inspirations = allInspirations
        case .used:
            inspirations = usedInspirations
        case .unused:
            inspirations = unusedInspirations
        }
    }
    
    // MARK: - 批量操作方法
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedInspirations.removeAll()
            }
        }
        
        // 立即更新浮窗数据
        if isSelectionMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let data = BatchSelectionData(
                    selectedCount: selectedInspirations.count,
                    totalCount: inspirations.count,
                    actionTitle: "添加到空间",
                    actionIcon: "plus.circle.fill",
                    onSelectAll: {
                        selectedInspirations = Set(inspirations.map { $0.id })
                    },
                    onDeselectAll: {
                        selectedInspirations.removeAll()
                    },
                    onAction: {
                        showingBatchSpaceSelection = true
                    },
                    onDismiss: {
                        isSelectionMode = false
                    }
                )
                GlobalPopupManager.shared.batchSelectionData = data
            }
        }
    }
    
    private func exitSelectionMode() {
        // 立即隐藏浮窗
        GlobalPopupManager.shared.hideBatchSelectionImmediately()
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


// MARK: - 筛选按钮
struct FilterButton: View {
    let title: String
    var count: Int?
    let isSelected: Bool
    let isDarkMode: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            buttonContent
                .foregroundColor(textColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
//                .background(buttonBackground)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // MARK: - 子视图组件
    private var buttonContent: some View {
        HStack(spacing: 6) {
            selectionIndicator
            titleText
            countBadge
        }
    }
    
    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Circle()
                .fill(indicatorColor)
                .frame(width: 6, height: 6)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    private var titleText: some View {
        Text(title)
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
    }
    
    @ViewBuilder
    private var countBadge: some View {
        if let count = count {
            Text("\(count)")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(countBadgeBackground)
        }
    }
    
//    private var buttonBackground: some View {
//        RoundedRectangle(cornerRadius: 20)
//            .fill(backgroundColor)
//            .overlay(borderOverlay)
//    }
    
//    private var borderOverlay: some View {
//        RoundedRectangle(cornerRadius: 20)
//            .stroke(borderColor, lineWidth: 1)
//    }
    
    // MARK: - 计算属性
    private var indicatorColor: Color {
        isDarkMode ? Color.yellow : Color.orange
    }
    
    private var textColor: Color {
        if isSelected {
            return isDarkMode ? .white : .black
        } else {
            return isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5)
        }
    }
    
    private var countBadgeBackground: some View {
        let selectedColor = isDarkMode ? Color.yellow.opacity(0.2) : Color.orange.opacity(0.2)
        let unselectedColor = isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        let badgeColor = isSelected ? selectedColor : unselectedColor
        
        return Capsule().fill(badgeColor)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return isDarkMode ? Color.white.opacity(0.08) : Color(hex: "F5F5F2")
        } else {
            return Color.clear
        }
    }
    
//    private var borderColor: Color {
//        if isSelected {
//            return isDarkMode ? Color.yellow.opacity(0.3) : Color.orange.opacity(0.3)
//        } else {
//            return isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
//        }
//    }
}

// MARK: - 灵感行视图
struct InspirationRowView: View {
    let inspiration: AudioRecording
    let isDarkMode: Bool
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onSwipeRight: (() -> Void)?
    
    @State private var showingSpaceSelection = false
    @State private var dragOffset: CGFloat = 0
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            leadingElement
            
            // 主内容
            contentSection
            
            trailingElement
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(backgroundShape)
//        .overlay(overlayBorder)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .offset(x: dragOffset)
        .onHover { hovering in
            isHovered = hovering
        }
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
        .onLongPressGesture {
            onLongPress?()
        }
        .simultaneousGesture(dragGesture)
    }
    
    // MARK: - 子视图组件
    @ViewBuilder
    private var leadingElement: some View {
        if isSelectionMode {
            selectionButton
        }
//        else {
//            inspirationDot
//        }
    }
    
    private var selectionButton: some View {
        Button(action: {
            onSelectionToggle?()
        }) {
            let iconName = isSelected ? "checkmark.circle.fill" : "circle"
            let iconColor = isSelected ? Color.blue : (isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
            
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(iconColor)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
//    private var inspirationDot: some View {
//        let dotColor = isDarkMode ? Color.yellow : Color.orange
//        
//        return Circle()
//            .fill(
//                RadialGradient(
//                    colors: [
//                        dotColor.opacity(0.8),
//                        dotColor.opacity(0.3)
//                    ],
//                    center: .center,
//                    startRadius: 1,
//                    endRadius: 4
//                )
//            )
//            .frame(width: 8, height: 8)
//            .shadow(color: dotColor.opacity(0.6), radius: 4)
//            .scaleEffect(isHovered ? 1.3 : 1.0)
//            .animation(.easeInOut(duration: 0.2), value: isHovered)
//    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(inspiration.polishedText)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(isDarkMode ? .white : .black)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .italic()
            
            HStack(spacing: 12) {
                tagsSection
                Spacer()
                timeSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        if !inspiration.tags.isEmpty {
            HStack(spacing: 6) {
                ForEach(inspiration.tags.prefix(2), id: \.self) { tag in
                    tagView(tag)
                }
                
                if inspiration.tags.count > 2 {
                    extraTagsView
                }
            }
        }
    }
    
    private func tagView(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isDarkMode ? Color.blue.opacity(0.8) : Color.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isDarkMode ? Color.blue.opacity(0.1) : Color.blue.opacity(0.08))
            )
    }
    
    private var extraTagsView: some View {
        Text("+\(inspiration.tags.count - 2)")
            .font(.system(size: 12))
            .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            )
    }
    
    private var timeSection: some View {
        Text(formatDate(inspiration.timestamp))
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
    }
    
    @ViewBuilder
    private var trailingElement: some View {
        if !isSelectionMode {
            addButton
        }
    }
    
    private var addButton: some View {
        Button(action: {
            showingSpaceSelection = true
        }) {
            ZStack {
                Circle()
                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    .frame(width: 32, height: 32)
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.4))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundShape: some View {
        let selectedColor = isDarkMode ? Color.yellow.opacity(0.06) : Color.orange.opacity(0.03)
        let hoveredColor = isDarkMode ? Color.white.opacity(0.02) : Color.black.opacity(0.01)
        let backgroundColor = isSelected ? selectedColor : (isHovered ? hoveredColor : Color.clear)
        
        return RoundedRectangle(cornerRadius: 16)
            .fill(backgroundColor)
    }
    
    private var overlayBorder: some View {
        let borderColor = isSelected ? 
            (isDarkMode ? Color.yellow.opacity(0.2) : Color.orange.opacity(0.2)) : 
            Color.clear
        
        return RoundedRectangle(cornerRadius: 16)
            .stroke(borderColor, lineWidth: 1)
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if value.translation.width > 0 && abs(value.translation.width) > abs(value.translation.height) {
                    dragOffset = min(value.translation.width, 50)
                }
            }
            .onEnded { value in
                withAnimation(.spring()) {
                    dragOffset = 0
                }
                
                if value.translation.width > 80 && abs(value.translation.width) > abs(value.translation.height) * 2 {
                    onSwipeRight?()
                }
            }
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
                        // 立即隐藏浮窗
                        GlobalPopupManager.shared.hideBatchSelectionImmediately()
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
                // 立即隐藏浮窗
                GlobalPopupManager.shared.hideBatchSelectionImmediately()
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
                        // 立即隐藏浮窗
                        GlobalPopupManager.shared.hideBatchSelectionImmediately()
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
                // 立即隐藏浮窗
                GlobalPopupManager.shared.hideBatchSelectionImmediately()
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
