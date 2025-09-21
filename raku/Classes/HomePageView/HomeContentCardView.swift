//
//  HomeContentCardView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI



struct HomeContentCardView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    let onDelete: () -> Void
    let onDragStateChanged: ((Bool) -> Void)?
    
    // 处理状态相关
    @State private var processingStage: UIProcessingStage = .idle
    @State private var processingProgress: Float = 0.0
    @StateObject private var updateManager = RecordingUpdateManager.shared
    
    init(recording: AudioRecording, isDarkMode: Bool, onDelete: @escaping () -> Void, onDragStateChanged: ((Bool) -> Void)? = nil) {
        self.recording = recording
        self.isDarkMode = isDarkMode
        self.onDelete = onDelete
        self.onDragStateChanged = onDragStateChanged
    }
    
    @State private var isHovered = false
    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var isDeleting = false
    @State private var hasTriggeredHaptic = false
    
    
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
    
    // 将字符串颜色转换为Color
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "clear": return .clear
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "red": return .red
        default: return .primary
        }
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
                                    .progressViewStyle(CircularProgressViewStyle(tint: colorFromString(processingStage.color)))
                                
                                Text(processingStage.displayText)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(colorFromString(processingStage.color))
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
                                    onDelete()
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
            .onReceive(updateManager.$processingRecordings) { processingRecordings in
                if let status = processingRecordings[recording.id] {
                    processingStage = status.stage
                    processingProgress = status.progress
                    print("📱 HomeContentCardView: 更新状态 - \(recording.id): \(status.stage)")
                } else {
                    // 当处理状态被清除时，重置为 idle
                    if processingStage != .idle {
                        print("📱 HomeContentCardView: 重置状态为idle - \(recording.id)")
                    }
                    processingStage = .idle
                    processingProgress = 0.0
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
        transcription: "这是一段关于SwiftUI开发的音频记录，讨论了如何使用SwiftUI构建优美的用户界面，以及最佳实践和性能优化技巧。",
        title: "SwiftUI开发最佳实践",
        summary: "本音频记录详细介绍了使用SwiftUI框架构建现代化iOS应用的技巧和方法",
        tags: ["SwiftUI", "iOS开发", "UI设计"],
        audioData: nil,
        enrichedContent: "深度内容分析..."
    )
    
    @State static var recordings = [
        sampleRecording,
        AudioRecording(
            timestamp: Date().addingTimeInterval(-3600),
            duration: 75.2,
            transcription: "项目管理会议记录",
            title: "项目进展讨论",
            summary: "本次会议重点讨论了当前项目的进展情况和下一阶段的计划",
            tags: ["会议", "项目管理"],
            audioData: nil,
            enrichedContent: nil
        ),
        AudioRecording(
            timestamp: Date().addingTimeInterval(-7200),
            duration: 32.8,
            transcription: "学习笔记记录",
            title: "算法学习记录",
            summary: "今天学习了动态规划的基本概念和经典问题的解法",
            tags: ["学习", "算法"],
            audioData: nil,
            enrichedContent: nil
        )
    ]
    
    static var previews: some View {
        Group {
            // 浅色模式单个卡片
            HomeContentCardView(
                recording: sampleRecording,
                isDarkMode: false,
                onDelete: {},
                onDragStateChanged: nil
            )
            .padding()
            .background(Color(white: 0.95))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Light Mode - Single Card")
            
            // 深色模式单个卡片
            HomeContentCardView(
                recording: sampleRecording,
                isDarkMode: true,
                onDelete: {},
                onDragStateChanged: nil
            )
            .padding()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Dark Mode - Single Card")
            
            // 可交互的列表 - 浅色模式
            RecordingListPreview(isDarkMode: false)
                .previewDisplayName("Light Mode - Interactive List")
            
            // 可交互的列表 - 深色模式
            RecordingListPreview(isDarkMode: true)
                .previewDisplayName("Dark Mode - Interactive List")
            
            // iPad 预览
            HomeContentCardView(
                recording: sampleRecording,
                isDarkMode: true,
                onDelete: {},
                onDragStateChanged: nil
            )
            .padding()
            .background(Color.black)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
            .previewDisplayName("iPad Pro - Dark")
        }
    }
}

// MARK: - 用于预览的可交互列表
struct RecordingListPreview: View {
    let isDarkMode: Bool
    @State private var recordings = [
        AudioRecording(
            timestamp: Date(),
            duration: 45.5,
            transcription: "SwiftUI开发记录",
            title: "SwiftUI开发最佳实践",
            summary: "本音频记录详细介绍了使用SwiftUI框架构建现代化iOS应用的技巧和方法",
            tags: ["SwiftUI", "iOS开发", "UI设计"],
            audioData: nil,
            enrichedContent: "深度内容分析..."
        ),
        AudioRecording(
            timestamp: Date().addingTimeInterval(-3600),
            duration: 75.2,
            transcription: "项目管理会议记录",
            title: "项目进展讨论",
            summary: "本次会议重点讨论了当前项目的进展情况和下一阶段的计划",
            tags: ["会议", "项目管理"],
            audioData: nil,
            enrichedContent: nil
        ),
        AudioRecording(
            timestamp: Date().addingTimeInterval(-7200),
            duration: 32.8,
            transcription: "学习笔记记录",
            title: "算法学习记录", 
            summary: "今天学习了动态规划的基本概念和经典问题的解法",
            tags: ["学习", "算法"],
            audioData: nil,
            enrichedContent: nil
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(recordings, id: \.id) { recording in
                    HomeContentCardView(
                        recording: recording,
                        isDarkMode: isDarkMode,
                        onDelete: {
                            withAnimation(.spring()) {
                                recordings.removeAll { $0.id == recording.id }
                            }
                        },
                        onDragStateChanged: nil
                    )
                }
            }
            .padding()
        }
        .background(isDarkMode ? Color.black : Color(white: 0.95))
        .navigationTitle("录音列表")
        .navigationBarTitleDisplayMode(.inline)
    }
}

