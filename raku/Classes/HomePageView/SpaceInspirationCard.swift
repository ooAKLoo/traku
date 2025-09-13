//
//  SpaceInspirationCard.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import SwiftUI

// MARK: - 空间数据模型
struct SpaceCategory: Identifiable {
    let id = UUID()
    let name: String
    let subcategories: [String]
    
    // 获取灵感总数（从所有子分类汇总）
    var totalInspirations: Int {
        // 这里应该从实际数据库查询，现在使用mock数据
        return Int.random(in: 5...50)
    }
}

// MARK: - 空间分类卡片
struct SpaceInspirationCard: View {
    let space: SpaceCategory
    let isDarkMode: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    let onDragStateChanged: ((Bool) -> Void)?
    
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var isDeleting = false
    @State private var hasTriggeredHaptic = false
    
    // 删除阈值（圆环完全闭合的滑动距离）
    private let deleteThreshold: CGFloat = -180
    private let maxSwipeDistance: CGFloat = -220
    
    // 计算进度 (0 到 1)
    private var progress: CGFloat {
        min(abs(offset) / abs(deleteThreshold), 1.0)
    }
    
    // 根据进度计算颜色深度
    private var trashColor: Color {
        if progress < 0.5 {
            return Color.orange.opacity(0.7 + Double(progress * 0.3))
        } else {
            return Color.red.opacity(0.7 + Double(progress * 0.3))
        }
    }
    
    init(space: SpaceCategory, isDarkMode: Bool, onTap: @escaping () -> Void, onDelete: (() -> Void)? = nil, onDragStateChanged: ((Bool) -> Void)? = nil) {
        self.space = space
        self.isDarkMode = isDarkMode
        self.onTap = onTap
        self.onDelete = onDelete
        self.onDragStateChanged = onDragStateChanged
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 背景层 - 删除区域
            HStack {
                Spacer()
                
                // 圆环进度垃圾桶
                ZStack {
                    // 进度圆环
                    if progress < 1 {
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                trashColor,
                                style: StrokeStyle(
                                    lineWidth: 3,
                                    lineCap: .round
                                )
                            )
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.2), value: progress)
                    }
                    
                    // 垃圾桶图标或对勾
                    Image(systemName: progress == 1 ? "checkmark" : "trash")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(progress == 1 ? Color.red : trashColor)
                        .scaleEffect(progress == 1 ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
                        .onChange(of: progress == 1) { showingCheckmark in
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
            
            // 卡片内容
            VStack(alignment: .center, spacing: 12) {
                // 空间名称
                Text(space.name)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
            )
            .scaleEffect((isHovered && !isDragging) ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered && !isDragging)
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        withAnimation(.interactiveSpring(response: 0.3)) {
                            if !isDragging {
                                isDragging = true
                                onDragStateChanged?(true)
                            }
                            // 只允许向左滑动
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, maxSwipeDistance)
                            } else if offset < 0 {
                                // 允许向右恢复，但不超过原点
                                offset = min(0, offset + value.translation.width / 3)
                            }
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isDragging = false
                            onDragStateChanged?(false)
                            
                            // 如果圆环闭合（progress == 1），执行删除
                            if progress >= 1.0 {
                                isDeleting = true
                                // 滑出屏幕动画
                                withAnimation(.easeOut(duration: 0.3)) {
                                    offset = -UIScreen.main.bounds.width
                                }
                                // 延迟后删除
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDelete?()
                                }
                            } else {
                                // 圆环未闭合，弹回原位
                                offset = 0
                            }
                        }
                    }
            )
            .onHover { hovering in
                if !isDragging {
                    isHovered = hovering
                }
            }
        }
    }
}

// MARK: - Mock数据
extension SpaceCategory {
    static let mockSpaces = [
        SpaceCategory(
            name: "XXX APP",
            subcategories: ["slogan", "运营", "产品", "其它"]
        ),
        SpaceCategory(
            name: "工作项目",
            subcategories: ["会议", "想法", "计划", "总结"]
        ),
        SpaceCategory(
            name: "个人成长",
            subcategories: ["学习", "思考", "目标", "反思"]
        ),
        SpaceCategory(
            name: "生活记录",
            subcategories: ["日常", "感悟", "旅行", "美食"]
        ),
        SpaceCategory(
            name: "创意灵感",
            subcategories: ["设计", "写作", "音乐", "艺术"]
        ),
        SpaceCategory(
            name: "健康运动",
            subcategories: ["锻炼", "饮食", "睡眠", "心理"]
        )
    ]
}

// MARK: - Preview
struct SpaceInspirationCard_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSpaces = SpaceCategory.mockSpaces
        
        Group {
            // 浅色模式单个卡片
            SpaceInspirationCard(
                space: sampleSpaces[0],
                isDarkMode: false,
                onTap: { print("Space tapped: \(sampleSpaces[0].name)") },
                onDelete: { print("Space deleted: \(sampleSpaces[0].name)") }
            )
            .previewDisplayName("Light Mode")
            .padding(20)
            .background(Color.gray.opacity(0.1))
            
            // 深色模式单个卡片
            SpaceInspirationCard(
                space: sampleSpaces[0],
                isDarkMode: true,
                onTap: { print("Space tapped: \(sampleSpaces[0].name)") },
                onDelete: { print("Space deleted: \(sampleSpaces[0].name)") }
            )
            .previewDisplayName("Dark Mode")
            .padding(20)
            .background(Color.black)
            
            // 网格布局预览
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(Array(sampleSpaces.prefix(4).enumerated()), id: \.offset) { index, space in
                    SpaceInspirationCard(
                        space: space,
                        isDarkMode: true,
                        onTap: { print("Space tapped: \(space.name)") },
                        onDelete: { print("Space deleted: \(space.name)") }
                    )
                }
            }
            .previewDisplayName("Grid Layout")
            .padding(20)
            .background(Color.black)
        }
    }
}
