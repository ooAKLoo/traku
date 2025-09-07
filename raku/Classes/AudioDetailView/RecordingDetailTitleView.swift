//
//  RecordingDetailTitleView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

struct RecordingDetailTitleView: View {
    let recording: AudioRecording
    let onTagTap: () -> Void
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(extractTitle(from: recording.summary))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.95))
                .lineLimit(2)
            
            // 时间和标签在同一行
            HStack(spacing: 22) {
                Text(recording.timestamp.smartFormatted)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                
                // 标签 - 更简洁，支持点击
                if !recording.tags.isEmpty {
                    Button(action: onTagTap) {
                        HStack(spacing: 8) {
                            ForEach(recording.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isDarkMode ? Color.gray.opacity(0.2) : Color.gray.opacity(0.15))
                                    )
                            }
                            
                            // 编辑图标提示
                            Image(systemName: "pencil.circle")
                                .font(.system(size: 12))
                                .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                        }
                    }
                } else {
                    // 没有标签时显示添加按钮
                    Button(action: onTagTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                            
                            Text("添加标签")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 50)
    }
    
    private func extractTitle(from summary: String) -> String {
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
}

// MARK: - 预览
struct RecordingDetailTitleView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingDetailTitleView(
            recording: AudioRecording(
                timestamp: Date(),
                duration: 185,
                transcription: "这是一段会议录音的转写内容",
                summary: "产品开发会议总结：确定了Q2的开发目标，包括核心功能完成、用户界面优化和测试计划制定。",
                tags: ["会议", "产品", "开发"],
                audioData: nil,
                enrichedContent: nil
            ),
            onTagTap: {}
        )
        .background(Color.black)
    }
}