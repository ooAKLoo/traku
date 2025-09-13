////
////  SpaceDetailView.swift
////  raku
////
////  Created by Claude on 2025/1/7.
////
//
//import SwiftUI
//
//// MARK: - 灵感数据模型
//struct Inspiration: Identifiable {
//    let id = UUID()
//    let text: String
//    let timestamp: Date
//    let category: String
//    let isHighlighted: Bool // 用于标记重要灵感
//}
//
//// MARK: - 空间详情页
//struct SpaceDetailView: View {
//    let space: SpaceCategory
//    @AppStorage("isDarkMode") private var isDarkMode = false
//    @Environment(\.presentationMode) var presentationMode
//    
//    @State private var selectedCategory: String = ""
//    @State private var inspirations: [Inspiration] = []
//    
//    // 过滤后的灵感
//    private var filteredInspirations: [Inspiration] {
//        if selectedCategory.isEmpty || selectedCategory == space.subcategories.first {
//            return inspirations
//        }
//        return inspirations.filter { $0.category == selectedCategory }
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // 顶部导航
//            headerView
//            
//            // 分类TabBar
//            categoryTabBar
//            
//            // 灵感列表
//            inspirationList
//        }
//        .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
//        .navigationBarHidden(true)
//        .onAppear {
//            setupInitialData()
//        }
//    }
//    
//    // MARK: - 顶部导航
//    private var headerView: some View {
//        HStack(spacing: 16) {
//            // 返回按钮
//            Button(action: {
//                presentationMode.wrappedValue.dismiss()
//            }) {
//                Image(systemName: "arrow.left")
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
//                    .frame(width: 32, height: 32)
//            }
//            
//            Spacer()
//            
//            // 空间名称
//            Text(space.name)
//                .font(.system(size: 18, weight: .medium))
//                .foregroundColor(isDarkMode ? .white : .black)
//                .tracking(0.2)
//            
//            Spacer()
//            
//            // 添加按钮
//            Button(action: {
//                // 添加新灵感
//            }) {
//                Image(systemName: "plus")
//                    .font(.system(size: 16, weight: .regular))
//                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
//                    .frame(width: 32, height: 32)
//            }
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 12)
//        .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
//    }
//    
//    // MARK: - 分类TabBar
//    private var categoryTabBar: some View {
//        ScrollView(.horizontal, showsIndicators: false) {
//            HStack(spacing: 32) {
//                ForEach(space.subcategories, id: \.self) { category in
//                    Button(action: {
//                        withAnimation(.easeInOut(duration: 0.25)) {
//                            selectedCategory = category
//                        }
//                    }) {
//                        VStack(spacing: 6) {
//                            Text(category)
//                                .font(.system(size: 14, weight: selectedCategory == category ? .medium : .regular))
//                                .foregroundColor(selectedCategory == category ?
//                                                (isDarkMode ? .white : .black) :
//                                                (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
//                                .tracking(0.3)
//                            
//                            // 极简指示线
//                            Circle()
//                                .fill(isDarkMode ? Color.white : Color.black)
//                                .frame(width: 4, height: 4)
//                                .opacity(selectedCategory == category ? 1 : 0)
//                                .animation(.easeInOut(duration: 0.25), value: selectedCategory)
//                        }
//                    }
//                    .buttonStyle(PlainButtonStyle())
//                }
//            }
//            .padding(.horizontal, 20)
//            .padding(.vertical, 8)
//        }
//        .background(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
//    }
//    
//    // MARK: - 灵感列表
//    private var inspirationList: some View {
//        ScrollView(showsIndicators: false) {
//            LazyVStack(spacing: 1) {
//                ForEach(filteredInspirations) { inspiration in
//                    MinimalistInspirationCard(
//                        inspiration: inspiration,
//                        isDarkMode: isDarkMode
//                    )
//                }
//            }
//            .padding(.top, 8)
//            .padding(.bottom, 100)
//        }
//    }
//    
//    // MARK: - 初始化数据
//    private func setupInitialData() {
//        selectedCategory = space.subcategories.first ?? ""
//        inspirations = Inspiration.mockInspirations(for: space)
//    }
//}
//
//// MARK: - 极简灵感卡片
//struct MinimalistInspirationCard: View {
//    let inspiration: Inspiration
//    let isDarkMode: Bool
//    @State private var isPressed = false
//    @State private var isMarked = false
//    @State private var dragOffset: CGFloat = 0
//    
//    var body: some View {
//        HStack(alignment: .top, spacing: 16) {
//            // 左侧时间线
//            VStack(alignment: .center, spacing: 0) {
//                // 时间点 - 根据标记状态和高亮状态显示
//                Circle()
//                    .fill(circleColor)
//                    .frame(width: circleSize, height: circleSize)
//                    .animation(.easeInOut(duration: 0.3), value: isMarked)
//                
//                // 连接线
//                Rectangle()
//                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
//                    .frame(width: 0.5)
//            }
//            .padding(.top, 8)
//            
//            // 内容区域
//            VStack(alignment: .leading, spacing: 8) {
//                // 灵感文本
//                Text(inspiration.text)
//                    .font(.system(size: 15, weight: .regular))
//                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85))
//                    .lineSpacing(6)
//                    .fixedSize(horizontal: false, vertical: true)
//                    .multilineTextAlignment(.leading)
//                
//                // 时间戳 - 极简风格
//                Text(formatMinimalTimestamp(inspiration.timestamp))
//                    .font(.system(size: 11, weight: .regular))
//                    .foregroundColor(isDarkMode ? .white.opacity(0.25) : .black.opacity(0.25))
//                    .tracking(0.5)
//            }
//            .padding(.trailing, 20)
//            .padding(.vertical, 16)
//            
//            Spacer(minLength: 0)
//        }
//        .padding(.leading, 20)
//        .background(
//            Rectangle()
//                .fill(isDarkMode ? Color.black : Color(hex: "FAFAFA"))
//        )
//        .scaleEffect(isPressed ? 0.98 : 1.0)
//        .offset(x: dragOffset)
//        .gesture(
//            DragGesture()
//                .onChanged { value in
//                    // 只允许向右拖动
//                    dragOffset = max(0, value.translation.width)
//                }
//                .onEnded { value in
//                    if value.translation.width > 50 {
//                        // 右滑超过阈值，标记这个灵感
//                        withAnimation(.easeInOut(duration: 0.3)) {
//                            isMarked = true
//                            dragOffset = 0
//                        }
//                    } else {
//                        // 未达到阈值，回弹
//                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
//                            dragOffset = 0
//                        }
//                    }
//                }
//        )
//        .onTapGesture {
//            withAnimation(.easeInOut(duration: 0.1)) {
//                isPressed = true
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                withAnimation(.easeInOut(duration: 0.1)) {
//                    isPressed = false
//                }
//            }
//        }
//    }
//    
//    // MARK: - 圆点样式计算
//    private var circleColor: Color {
//        if isMarked {
//            // 已标记：纯黑/纯白
//            return isDarkMode ? Color.white : Color.black
//        } else if inspiration.isHighlighted {
//            // 高亮但未标记：半透明
//            return isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
//        } else {
//            // 普通状态：更淡的透明度
//            return isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
//        }
//    }
//    
//    private var circleSize: CGFloat {
//        if isMarked {
//            return 8  // 标记后稍微大一些
//        } else if inspiration.isHighlighted {
//            return 6  // 高亮状态中等大小
//        } else {
//            return 4  // 普通状态最小
//        }
//    }
//    
//    // MARK: - 极简时间格式
//    private func formatMinimalTimestamp(_ date: Date) -> String {
//        let calendar = Calendar.current
//        let now = Date()
//        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
//        
//        if let day = components.day, day > 0 {
//            if day == 1 {
//                return "昨天"
//            } else if day < 7 {
//                return "\(day)天前"
//            } else if day < 30 {
//                return "\(day / 7)周前"
//            } else {
//                let formatter = DateFormatter()
//                formatter.dateFormat = "MM.dd"
//                return formatter.string(from: date)
//            }
//        } else if let hour = components.hour, hour > 0 {
//            return "\(hour)小时前"
//        } else if let minute = components.minute, minute > 0 {
//            return "\(minute)分钟前"
//        } else {
//            return "刚刚"
//        }
//    }
//}
//
//// MARK: - Mock数据扩展
//extension Inspiration {
//    static func mockInspirations(for space: SpaceCategory) -> [Inspiration] {
//        let sampleTexts = [
//            "让用户感到被理解和关怀的产品设计，比功能完善更重要。",
//            "简洁不是减少，而是去除不必要的复杂性。",
//            "用户体验的核心在于预期管理，超出预期才能带来惊喜。",
//            "每个交互都应该有明确的反馈，让用户知道发生了什么。",
//            "设计要为解决问题而存在，而不是为了展示技巧。",
//            "好的产品会让用户忘记它的存在，专注于要完成的任务。",
//            "数据驱动决策，但不能忽视用户情感和直觉。",
//            "创新不一定是发明新东西，也可以是重新定义现有的东西。",
//            "极简主义不是空无一物，而是恰到好处。",
//            "细节决定品质，但整体决定成败。",
//            "用户不会记得你说了什么，但会记得你让他们感受到什么。",
//            "最好的设计是看不见的设计。"
//        ]
//        
//        var inspirations: [Inspiration] = []
//        
//        for (index, text) in sampleTexts.enumerated() {
//            let category = space.subcategories[index % space.subcategories.count]
//            let timeOffset = -Double.random(in: 0...604800) // 过去一周内的随机时间
//            let isHighlighted = index % 3 == 0 // 每3个标记一个为重要
//            
//            let inspiration = Inspiration(
//                text: text,
//                timestamp: Date().addingTimeInterval(timeOffset),
//                category: category,
//                isHighlighted: isHighlighted
//            )
//            
//            inspirations.append(inspiration)
//        }
//        
//        return inspirations.sorted { $0.timestamp > $1.timestamp }
//    }
//}
//
//
//// MARK: - Preview
//struct SpaceDetailView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            SpaceDetailView(space: SpaceCategory.mockSpaces[0])
//                .previewDisplayName("Light Mode")
//            
//            SpaceDetailView(space: SpaceCategory.mockSpaces[0])
//                .previewDisplayName("Dark Mode")
//                .preferredColorScheme(.dark)
//        }
//    }
//}
