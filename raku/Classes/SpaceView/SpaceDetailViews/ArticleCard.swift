//
//  ArticleCard.swift
//  raku
//
//  Created by Assistant on 2025/9/21.
//

import SwiftUI
import UIKit

// MARK: - 文章卡片
struct ArticleCard: View {
    let article: SpaceArticle
    let recording: AudioRecording
    let isDarkMode: Bool
    let onToggleMark: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
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
                    Text(article.createdAt.minimalRelativeFormatted)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(isDarkMode ? .white.opacity(0.25) : .black.opacity(0.25))
                        .tracking(0.5)
                }
                .padding(.trailing, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle()) // 确保整个区域可点击
                .onTapGesture {
                    // 只有在没有滑动的时候才触发编辑
                    if !isDragging && offset == 0 {
                        print("📝 edit-space-articalcard--- [ArticleCard] 点击触发编辑")
                        print("   edit-space-articalcard--- isDragging: \(isDragging)")
                        print("   edit-space-articalcard--- offset: \(offset)")
                        print("   edit-space-articalcard--- article.id: \(article.id)")
                        print("   edit-space-articalcard--- recording.id: \(recording.id)")
                        onEdit()
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.leading, 20)
            .background(
                Rectangle()
                    .fill(isDarkMode ? Color.black : Color.white)
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
}