//
//  RecordingDetailView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//


import SwiftUI
import AVFoundation
import Combine

// MARK: - 录音详情视图
struct RecordingDetailView: View {
    let recording: AudioRecording
    @State private var isPlaying = false
    @State private var playProgress: Double = 0
    @State private var showTranscription = true
    @State private var showSummary = true
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            // 极简背景
            (isDarkMode ? Color.black : Color(white: 0.98))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                                    .shadow(
                                        color: Color.black.opacity(isDarkMode ? 0.3 : 0.08),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: shareRecording) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        Button(action: exportRecording) {
                            Label("导出", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive, action: deleteRecording) {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                                    .shadow(
                                        color: Color.black.opacity(isDarkMode ? 0.3 : 0.08),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 标题区域
                        VStack(alignment: .leading, spacing: 12) {
                            Text(formatDate(recording.timestamp))
                                .font(.system(size: 14))
                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                            
                            Text(extractTitle(from: recording.summary))
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            // 标签
                            HStack(spacing: 8) {
                                ForEach(recording.tags, id: \.self) { tag in
                                    TagView(text: tag, isDarkMode: isDarkMode)
                                }
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // 音频播放器模块
                        AudioPlayerCard(
                            duration: recording.duration,
                            isPlaying: $isPlaying,
                            progress: $playProgress
                        )
                        
                        // 转写文本模块
                        CollapsibleCard(
                            title: "转写文本",
                            icon: "text.alignleft",
                            isExpanded: $showTranscription
                        ) {
                            Text(recording.transcription)
                                .font(.system(size: 15))
                                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                .lineSpacing(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // 总结模块
                        CollapsibleCard(
                            title: "智能总结",
                            icon: "brain",
                            isExpanded: $showSummary
                        ) {
                            VStack(alignment: .leading, spacing: 15) {
                                // 概要段落
                                Text(recording.summary)
                                    .font(.system(size: 15))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                    .lineSpacing(8)
                                
                                Divider()
                                    .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                
                                // 要点列表
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("关键要点")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                    
                                    ForEach(extractKeyPoints(from: recording.summary), id: \.self) { point in
                                        HStack(alignment: .top, spacing: 10) {
                                            Circle()
                                                .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                                                .frame(width: 4, height: 4)
                                                .offset(y: 7)
                                            
                                            Text(point)
                                                .font(.system(size: 14))
                                                .foregroundColor(isDarkMode ? .white.opacity(0.85) : .black.opacity(0.85))
                                        }
                                    }
                                }
                                
                                // 复制按钮
                                Button(action: copySummary) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 14))
                                        Text("复制总结")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(isDarkMode ? .white : .black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                                    )
                                }
                                .padding(.top, 10)
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // 辅助函数
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
    
    func extractTitle(from summary: String) -> String {
        let sentences = summary.components(separatedBy: "。")
        return sentences.first ?? "录音记录"
    }
    
    func extractKeyPoints(from summary: String) -> [String] {
        // 这里可以集成AI来提取要点
        // 现在暂时返回模拟数据
        return [
            "讨论了项目的整体进度安排",
            "确定了下周的关键交付物",
            "分配了各团队成员的具体任务"
        ]
    }
    
    func shareRecording() {
        // 实现分享功能
    }
    
    func exportRecording() {
        // 实现导出功能
    }
    
    func deleteRecording() {
        // 实现删除功能
        dismiss()
    }
    
    func copySummary() {
        UIPasteboard.general.string = recording.summary
    }
}

// MARK: - 音频播放器卡片
struct AudioPlayerCard: View {
    let duration: TimeInterval
    @Binding var isPlaying: Bool
    @Binding var progress: Double
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        VStack(spacing: 20) {
            // 音波动画
            HStack(spacing: 3) {
                ForEach(0..<30) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isDarkMode ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                        .frame(width: 3, height: CGFloat.random(in: 10...40))
                        .animation(
                            isPlaying ?
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.05) :
                                .default,
                            value: isPlaying
                        )
                }
            }
            .frame(height: 40)
            
            // 播放控制
            HStack(spacing: 30) {
                // 播放按钮
                Button(action: { isPlaying.toggle() }) {
                    ZStack {
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                            .frame(width: 56, height: 56)
                            .shadow(
                                color: Color.black.opacity(isDarkMode ? 0.3 : 0.08),
                                radius: 6,
                                x: 0,
                                y: 3
                            )
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                
                // 进度条和时间
                VStack(spacing: 8) {
                    // 进度条
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isDarkMode ? Color.white : Color.black)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    // 时间显示
                    HStack {
                        Text(formatTime(duration * progress))
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Text(formatTime(duration))
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .shadow(
                    color: Color.black.opacity(isDarkMode ? 0.3 : 0.05),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 20)
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 可折叠卡片
struct CollapsibleCard<Content: View>: View {
    let title: String
    let icon: String
    @Binding var isExpanded: Bool
    let content: () -> Content
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }
            
            // 内容区域
            if isExpanded {
                content()
                    .padding(16)
                    .padding(.top, -8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .shadow(
                    color: Color.black.opacity(isDarkMode ? 0.3 : 0.05),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 20)
    }
}
