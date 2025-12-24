//
//  HomeContentCardView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI



struct HomeContentCardView: View {
    let recording: AudioRecording
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }

    // 处理状态相关
    @State private var processingStage: UIProcessingStage = .idle
    @StateObject private var updateManager = RecordingUpdateManager.shared
    
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var hasTriggeredHaptic = false
    @State private var isHorizontalDrag = false
    
    
    // 随机天气类型（基于录音ID生成稳定的随机数）
    private var weatherType: WeatherType {
        let hashValue = abs(recording.id.hashValue)
        let index = hashValue % WeatherType.allCases.count
        return WeatherType.allCases[index]
    }
    
    // 删除阈值（圆环完全闭合的滑动距离）- 增加距离防止误触
    private let deleteThreshold: CGFloat = -180
    private let maxSwipeDistance: CGFloat = -220
    
    // 计算进度 (0 到 1)
    private var progress: CGFloat {
        min(abs(offset) / abs(deleteThreshold), 1.0)
    }
    
    // 根据进度计算颜色深度
    private var trashColor: Color {
        // 从橙色逐渐过渡到红色，去掉无意义的灰色
        if progress < 0.5 {
            return Color.orange.opacity(0.7 + Double(progress * 0.3))
        } else {
            return Color.red.opacity(0.7 + Double(progress * 0.3))
        }
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
            HStack(alignment: .top, spacing: 16) {
                // 左侧内容区域
                VStack(alignment: .leading, spacing: 0) {
                    // 时间戳和处理状态
                    HStack(spacing: 8) {
                        Text(recording.timestamp.smartFormatted)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        
                        // 处理状态显示
                        if processingStage != .idle {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle(tint: processingStage.color))
                                
                                Text(processingStage.displayText)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(processingStage.color)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Spacer()
                        .frame(height: 10)
                    
                    // 标题
                    Text(recording.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                        .frame(height: 14)
                    
                    // 标签
                    HStack(spacing: 6) {
                        ForEach(recording.tags.prefix(3), id: \.self) { tag in
                            TagView(text: tag, isDarkMode: isDarkMode)
                        }
                        if recording.tags.count > 3 {
                            Text("+\(recording.tags.count - 3)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // 右侧天气图标和装饰
                if offset >= -10 {
                    VStack(spacing: 9) {
                        Spacer()
                            .frame(height: 6)
                        
                        WeatherIconView(
                            weatherType: weatherType,
                            isDarkMode: false,  // 设置为 false 让图标显示为白色
                            size: 28,
                            showBackground: false
                        )
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            weatherType.primaryColor.opacity(0.15),
                                            weatherType.primaryColor.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        
                        // 装饰性的颜色条
                        RoundedRectangle(cornerRadius: 2)
                            .fill(weatherType.primaryColor.opacity(0.6))
                            .frame(width: 20, height: 3)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
            )
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        // 首次判断滑动方向
                        if !isDragging {
                            // 只有明显的水平向左滑动才响应（水平位移是垂直的2倍以上，且向左）
                            let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 2
                            if isHorizontal && value.translation.width < -20 {
                                isHorizontalDrag = true
                                isDragging = true
                            } else {
                                return
                            }
                        }

                        // 如果不是水平拖拽，不处理
                        guard isHorizontalDrag else { return }

                        withAnimation(.interactiveSpring(response: 0.3)) {
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
                            isHorizontalDrag = false

                            // 如果圆环闭合（progress == 1），执行删除
                            if progress >= 1.0 {
                                // 滑出屏幕动画
                                withAnimation(.easeOut(duration: 0.3)) {
                                    offset = -UIScreen.main.bounds.width
                                }
                                // 延迟后删除
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDelete()
                                }
                            } else {
                                // 圆环未闭合，弹回原位
                                offset = 0
                            }
                        }
                    }
            )
            .onReceive(updateManager.$processingRecordings) { processingRecordings in
                if let status = processingRecordings[recording.id] {
                    processingStage = status.stage
                } else if processingStage != .idle {
                    processingStage = .idle
                }
            }
        }
        .padding(.horizontal, 4)
    }
}


// MARK: - Preview
struct HomeContentCardView_Previews: PreviewProvider {
    static let sampleRecording = AudioRecording(
        timestamp: Date(),
        duration: 45.5,
        transcription: "这是一段关于SwiftUI开发的音频记录",
        title: "SwiftUI开发最佳实践",
        summary: "SwiftUI框架构建现代化iOS应用的技巧",
        tags: ["SwiftUI", "iOS开发", "UI设计"],
        audioData: nil,
        enrichedContent: nil
    )

    static var previews: some View {
        Group {
            HomeContentCardView(recording: sampleRecording, onDelete: {})
                .padding()
                .background(Color(white: 0.95))
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Light Mode")
                .environment(\.colorScheme, .light)

            HomeContentCardView(recording: sampleRecording, onDelete: {})
                .padding()
                .background(Color.black)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Dark Mode")
                .environment(\.colorScheme, .dark)
        }
    }
}

