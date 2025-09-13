//
//  SpaceDetailView.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import SwiftUI

// MARK: - 灵感数据模型
struct Inspiration: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let category: String
    let isHighlighted: Bool // 用于标记重要灵感
}

// MARK: - 空间详情页
struct SpaceDetailView: View {
    let space: SpaceCategory
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedCategory: String = ""
    @State private var inspirations: [Inspiration] = []
    
    // 过滤后的灵感
    private var filteredInspirations: [Inspiration] {
        if selectedCategory.isEmpty || selectedCategory == space.subcategories.first {
            return inspirations
        }
        return inspirations.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航
            headerView
            
            // 分类TabBar
            categoryTabBar
            
            // 灵感列表
            inspirationList
        }
        .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
        .navigationBarHidden(true)
        .onAppear {
            setupInitialData()
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
            
            // 添加按钮
            Button(action: {
                // 添加新灵感
            }) {
                Image(systemName: "plus")
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
                ForEach(space.subcategories, id: \.self) { category in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedCategory = category
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(category)
                                .font(.system(size: 14, weight: selectedCategory == category ? .medium : .regular))
                                .foregroundColor(selectedCategory == category ?
                                                (isDarkMode ? .white : .black) :
                                                (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
                                .tracking(0.3)
                            
                            // 极简指示线
                            Circle()
                                .fill(isDarkMode ? Color.white : Color.black)
                                .frame(width: 4, height: 4)
                                .opacity(selectedCategory == category ? 1 : 0)
                                .animation(.easeInOut(duration: 0.25), value: selectedCategory)
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
    
    // MARK: - 灵感列表
    private var inspirationList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 1) {
                ForEach(filteredInspirations) { inspiration in
                    MinimalistInspirationCard(
                        inspiration: inspiration,
                        isDarkMode: isDarkMode,
                        onDelete: {
                            // 删除灵感的逻辑
                            withAnimation(.spring()) {
                                inspirations.removeAll { $0.id == inspiration.id }
                            }
                        }
                    )
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - 初始化数据
    private func setupInitialData() {
        selectedCategory = space.subcategories.first ?? ""
        inspirations = Inspiration.mockInspirations(for: space)
    }
}

// MARK: - 极简灵感卡片
struct MinimalistInspirationCard: View {
    let inspiration: Inspiration
    let isDarkMode: Bool
    let onDelete: (() -> Void)?
    @State private var isPressed = false
    @State private var isMarked = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isDeleting = false
    @State private var hasTriggeredHaptic = false
    
    // 删除阈值（圆环完全闭合的滑动距离）
    private let deleteThreshold: CGFloat = -180
    private let maxSwipeDistance: CGFloat = -220
    private let markThreshold: CGFloat = 80
    
    // 计算删除进度 (0 到 1)
    private var deleteProgress: CGFloat {
        dragOffset < 0 ? min(abs(dragOffset) / abs(deleteThreshold), 1.0) : 0
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
        ZStack(alignment: .trailing) {
            // 背景层 - 删除区域（左滑时显示）
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
                .opacity(dragOffset < -10 ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: dragOffset < -10)
            }
            .padding(.trailing, 20)
            
            
            // 主内容
            HStack(alignment: .top, spacing: 16) {
                // 左侧时间线
                VStack(alignment: .center, spacing: 0) {
                    // 时间点 - 根据标记状态显示
                    Circle()
                        .fill(circleColor)
                        .frame(width: circleSize, height: circleSize)
                        .animation(.easeInOut(duration: 0.3), value: isMarked)
                    
                    // 连接线
                    Rectangle()
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                        .frame(width: 0.5)
                }
                .padding(.top, 8)
                
                // 内容区域
                VStack(alignment: .leading, spacing: 8) {
                    // 灵感文本
                    Text(inspiration.text)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85))
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                    
                    // 时间戳 - 极简风格
                    Text(formatMinimalTimestamp(inspiration.timestamp))
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
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring(response: 0.3)) {
                            if !isDragging {
                                isDragging = true
                            }
                            // 支持双向拖动
                            if value.translation.width < 0 {
                                // 向左滑动（删除）
                                dragOffset = max(value.translation.width, maxSwipeDistance)
                            } else {
                                // 向右滑动（标记）
                                dragOffset = min(value.translation.width, 120)
                            }
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isDragging = false
                            
                            if value.translation.width < 0 {
                                // 左滑处理
                                if deleteProgress >= 1.0 {
                                    // 执行删除
                                    isDeleting = true
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        dragOffset = -UIScreen.main.bounds.width
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onDelete?()
                                    }
                                } else {
                                    // 未达到删除阈值，回弹
                                    dragOffset = 0
                                }
                            } else if value.translation.width > markThreshold {
                                // 右滑超过阈值，标记这个灵感（不显示图标，只改变圆点状态）
                                isMarked.toggle()
                                dragOffset = 0
                                // 触发轻微震动反馈
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            } else {
                                // 未达到任何阈值，回弹
                                dragOffset = 0
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
            }
        }
    }
    
    // MARK: - 圆点样式计算
    private var circleColor: Color {
        if isMarked {
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
    
    // MARK: - 极简时间格式
    private func formatMinimalTimestamp(_ date: Date) -> String {
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

// MARK: - Mock数据扩展
extension Inspiration {
    static func mockInspirations(for space: SpaceCategory) -> [Inspiration] {
        let sampleTexts = [
            "让用户感到被理解和关怀的产品设计，比功能完善更重要。",
            "简洁不是减少，而是去除不必要的复杂性。",
            "用户体验的核心在于预期管理，超出预期才能带来惊喜。",
            "每个交互都应该有明确的反馈，让用户知道发生了什么。",
            "设计要为解决问题而存在，而不是为了展示技巧。",
            "好的产品会让用户忘记它的存在，专注于要完成的任务。",
            "数据驱动决策，但不能忽视用户情感和直觉。",
            "创新不一定是发明新东西，也可以是重新定义现有的东西。",
            "极简主义不是空无一物，而是恰到好处。",
            "细节决定品质，但整体决定成败。",
            "用户不会记得你说了什么，但会记得你让他们感受到什么。",
            "最好的设计是看不见的设计。"
        ]
        
        var inspirations: [Inspiration] = []
        
        for (index, text) in sampleTexts.enumerated() {
            let category = space.subcategories[index % space.subcategories.count]
            let timeOffset = -Double.random(in: 0...604800) // 过去一周内的随机时间
            let isHighlighted = index % 3 == 0 // 每3个标记一个为重要
            
            let inspiration = Inspiration(
                text: text,
                timestamp: Date().addingTimeInterval(timeOffset),
                category: category,
                isHighlighted: isHighlighted
            )
            
            inspirations.append(inspiration)
        }
        
        return inspirations.sorted { $0.timestamp > $1.timestamp }
    }
}


// MARK: - Preview
struct SpaceDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SpaceDetailView(space: SpaceCategory.mockSpaces[0])
                .previewDisplayName("Light Mode")
            
            SpaceDetailView(space: SpaceCategory.mockSpaces[0])
                .previewDisplayName("Dark Mode")
                .preferredColorScheme(.dark)
        }
    }
}
