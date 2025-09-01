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
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    @StateObject private var audioManager = AudioManagerAdapter()
    
    var body: some View {
        ZStack {
            // 极简背景
            (isDarkMode ? Color.black : Color(white: 0.98))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏 - 更加精简
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // 播放控件 - 更简洁
                    Button(action: togglePlayback) {
                        HStack(spacing: 8) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                            Text(formatTime(recording.duration))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
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
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题区域 - 更紧凑
                        VStack(alignment: .leading, spacing: 8) {
                            Text(formatDate(recording.timestamp))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                            
                            Text(extractTitle(from: recording.summary))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.95))
                                .lineLimit(2)
                            
                            // 标签 - 更简洁
                            if !recording.tags.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(recording.tags.prefix(3), id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                        
                        // 转写文本部分 - 引用样式
                        VStack(alignment: .leading, spacing: 16) {
                            // 引用符号
                            Image(systemName: "quote.opening")
                                .font(.system(size: 20))
                                .foregroundColor(isDarkMode ? .white.opacity(0.15) : .black.opacity(0.15))
                                .padding(.leading, 24)
                            
                            // 转写内容 - 浅色斜体
                            Text(recording.transcription)
                                .font(.system(size: 15, weight: .regular))
                                .italic()
                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                                .lineSpacing(10)
                                .padding(.horizontal, 32)
                        }
                        .padding(.bottom, 48)
                        
                        // AI总结部分 - 黑体强调，无标题
                        VStack(alignment: .leading, spacing: 20) {
                            // 总结内容 - 黑体醒目
                            Text(recording.summary)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                .lineSpacing(12)
                                .padding(.horizontal, 24)
                            
                            // 要点提炼 - 如果有的话
                            if !extractKeyPoints(from: recording.summary).isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(extractKeyPoints(from: recording.summary), id: \.self) { point in
                                        HStack(alignment: .top, spacing: 12) {
                                            Circle()
                                                .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                                                .frame(width: 3, height: 3)
                                                .offset(y: 8)
                                            
                                            Text(point)
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(isDarkMode ? .white.opacity(0.75) : .black.opacity(0.75))
                                                .lineSpacing(8)
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                            }
                        }
                        
                        // 底部留白
                        Color.clear.frame(height: 60)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // 辅助函数
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // 判断是否为今天
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "今天 HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "昨天 HH:mm"
        } else if let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            formatter.dateFormat = "EEEE HH:mm"
        } else {
            formatter.dateFormat = "MM月dd日 HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    func extractTitle(from summary: String) -> String {
        // 从总结中提取第一句作为标题
        let sentences = summary.components(separatedBy: CharacterSet(charactersIn: "。！？"))
        if let firstSentence = sentences.first, !firstSentence.isEmpty {
            // 限制标题长度
            if firstSentence.count > 30 {
                return String(firstSentence.prefix(30)) + "..."
            }
            return firstSentence
        }
        return "录音记录"
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
        let text = """
        \(extractTitle(from: recording.summary))
        
        转写内容：
        \(recording.transcription)
        
        总结：
        \(recording.summary)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func exportRecording() {
        // 实现导出功能
        copySummary()
    }
    
    func deleteRecording() {
        // 实现删除功能
        dismiss()
    }
    
    func copySummary() {
        let fullContent = """
        \(recording.transcription)
        
        ---
        
        \(recording.summary)
        """
        UIPasteboard.general.string = fullContent
    }
    
    func togglePlayback() {
        if isPlaying {
            audioManager.stopPlaying()
            isPlaying = false
        } else {
            if let audioData = recording.audioData {
                let dataString = String(data: audioData, encoding: .utf8)
                if dataString?.contains("mock audio data") == true {
                    showMockDataAlert()
                } else {
                    audioManager.playRecording(recording)
                    isPlaying = true
                }
            }
        }
    }
    
    private func showMockDataAlert() {
        isPlaying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isPlaying = false
        }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 预览
struct RecordingDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingDetailView(
            recording: AudioRecording(
                timestamp: Date(),
                duration: 185,
                transcription: "这是一段会议录音的转写内容，讨论了关于新产品开发的进度和计划。我们需要在下个季度完成主要功能的开发，并准备进行用户测试。",
                summary: "产品开发会议总结：确定了Q2的开发目标，包括核心功能完成、用户界面优化和测试计划制定。团队将采用敏捷开发方法，每两周进行一次迭代评审。",
                tags: ["会议", "产品", "开发"],
                audioData: "mock audio data".data(using: .utf8)
            )
        )
    }
}
