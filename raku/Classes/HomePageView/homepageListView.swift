//
//  homepageListView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 录音列表内容视图
struct HomepageListView: View {
    let filteredRecordings: [AudioRecording]
    let isDarkMode: Bool
    let onDelete: (AudioRecording) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(Array(filteredRecordings.enumerated()), id: \.element.id) { index, recording in
                    NavigationLink(destination:
                        RecordingDetailView(recording: recording)
                            .navigationBarHidden(true)
                    ) {
                        RecordingCardView(
                            recording: recording,
                            isDarkMode: isDarkMode,
                            onDelete: { onDelete(recording) }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .scale)
                    ))
                    .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
            .background(.white)
        }
    }
}

// MARK: - Preview
struct HomepageListView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleRecordings = [
            AudioRecording(
                timestamp: Date(),
                duration: 120.5,
                transcription: "这是一段示例录音的转录内容，包含了语音识别的结果文本。",
                summary: "会议讨论 - 项目进度汇报",
                tags: ["会议", "工作", "项目"],
                audioData: Data(),
                enrichedContent: "这是丰富化内容的示例"
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-3600),
                duration: 45.2,
                transcription: "另一段录音内容，展示不同类型的语音记录。",
                summary: "个人笔记 - 想法记录",
                tags: ["个人", "笔记"],
                audioData: Data(),
                enrichedContent: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-7200),
                duration: 89.1,
                transcription: "第三段录音展示更多样化的内容和标签。",
                summary: "学习笔记 - 知识总结",
                tags: ["学习", "笔记", "总结"],
                audioData: Data(),
                enrichedContent: "详细的学习内容分析"
            )
        ]
        
        Group {
            // 浅色模式预览
            HomepageListView(
                filteredRecordings: sampleRecordings,
                isDarkMode: false,
                onDelete: { _ in print("Delete recording") }
            )
            .previewDisplayName("Light Mode")
            
            // 深色模式预览
            HomepageListView(
                filteredRecordings: sampleRecordings,
                isDarkMode: true,
                onDelete: { _ in print("Delete recording") }
            )
            .previewDisplayName("Dark Mode")
            .preferredColorScheme(.dark)
            
            // 空列表预览
            HomepageListView(
                filteredRecordings: [],
                isDarkMode: false,
                onDelete: { _ in print("Delete recording") }
            )
            .previewDisplayName("Empty List")
        }
    }
}