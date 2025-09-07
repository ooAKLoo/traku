//
//  RecordingCardView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

struct RecordingCardView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 卡片内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间戳
                Text(recording.timestamp.timeFormatted)
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                
                // 标题（总结的第一句）
                Text(recording.summary.prefix(50) + "...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                
                // 标签
                HStack(spacing: 8) {
                    ForEach(recording.tags, id: \.self) { tag in
                        TagView(text: tag, isDarkMode: isDarkMode)
                    }
                }
                
                // 时长
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text("\(Int(recording.duration))秒")
                        .font(.system(size: 12))
                }
                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .shadow(
                        color: Color.black.opacity(isDarkMode ? 0.3 : 0.05),
                        radius: isHovered ? 8 : 4,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview
struct RecordingCardView_Previews: PreviewProvider {
    static let sampleRecording = AudioRecording(
        timestamp: Date(),
        duration: 45.5,
        transcription: "这是一段关于SwiftUI开发的音频记录，讨论了如何使用SwiftUI构建优美的用户界面，以及最佳实践和性能优化技巧。",
        summary: "SwiftUI开发最佳实践：本音频记录详细介绍了使用SwiftUI框架构建现代化iOS应用的技巧和方法...",
        tags: ["SwiftUI", "iOS开发", "UI设计"],
        audioData: nil,
        enrichedContent: "深度内容分析..."
    )
    
    static var previews: some View {
        Group {
            // 浅色模式单个卡片
            RecordingCardView(recording: sampleRecording, isDarkMode: false)
                .padding()
                .background(Color(white: 0.95))
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Light Mode - Single Card")
            
            // 深色模式单个卡片
            RecordingCardView(recording: sampleRecording, isDarkMode: true)
                .padding()
                .background(Color.black)
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Dark Mode - Single Card")
            
            // 列表中的多个卡片 - 浅色模式
            VStack(spacing: 12) {
                ForEach(0..<3) { index in
                    RecordingCardView(
                        recording: AudioRecording(
                            timestamp: Date().addingTimeInterval(-Double(index) * 3600),
                            duration: Double.random(in: 30...120),
                            transcription: "示例音频内容 \(index + 1)",
                            summary: "这是第\(index + 1)个录音的摘要，包含了一些重要的信息和洞察...",
                            tags: ["标签\(index + 1)", "示例"],
                            audioData: nil,
                            enrichedContent: nil
                        ),
                        isDarkMode: false
                    )
                }
            }
            .padding()
            .background(Color(white: 0.95))
            .previewDisplayName("Light Mode - List")
            
            // 列表中的多个卡片 - 深色模式
            VStack(spacing: 12) {
                ForEach(0..<3) { index in
                    RecordingCardView(
                        recording: AudioRecording(
                            timestamp: Date().addingTimeInterval(-Double(index) * 3600),
                            duration: Double.random(in: 30...120),
                            transcription: "示例音频内容 \(index + 1)",
                            summary: "这是第\(index + 1)个录音的摘要，包含了一些重要的信息和洞察...",
                            tags: ["标签\(index + 1)", "示例"],
                            audioData: nil,
                            enrichedContent: nil
                        ),
                        isDarkMode: true
                    )
                }
            }
            .padding()
            .background(Color.black)
            .previewDisplayName("Dark Mode - List")
            
            // iPad 预览
            RecordingCardView(recording: sampleRecording, isDarkMode: true)
                .padding()
                .background(Color.black)
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
                .previewDisplayName("iPad Pro - Dark")
        }
    }
}

