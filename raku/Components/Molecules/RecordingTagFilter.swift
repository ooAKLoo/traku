//
//  RecordingTagFilter.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 录音标签过滤器复合组件
struct RecordingTagFilter: View {
    let allRecordings: [AudioRecording]
    @Binding var selectedTag: String?
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    // 获取所有唯一标签
    private var allTags: [String] {
        let tags = Set(allRecordings.flatMap { $0.tags })
        return Array(tags).sorted()
    }
    
    // 获取标签统计
    private func getTagCount(_ tag: String) -> Int {
        return allRecordings.filter { $0.tags.contains(tag) }.count
    }
    
    var body: some View {
        if !allTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // "全部" 选项
                    FilterTagButton(
                        title: "全部",
                        count: allRecordings.count,
                        isSelected: selectedTag == nil,
                        isDarkMode: isDarkMode
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedTag = nil
                        }
                    }
                    
                    // 各个标签选项
                    ForEach(allTags, id: \.self) { tag in
                        FilterTagButton(
                            title: tag,
                            count: getTagCount(tag),
                            isSelected: selectedTag == tag,
                            isDarkMode: isDarkMode
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(
                (isDarkMode ? Color.black : Color.appBackground)
            )
        }
    }
}

// MARK: - 预览
struct RecordingTagFilter_Previews: PreviewProvider {
    static var previews: some View {
        let sampleRecordings = [
            AudioRecording(
                timestamp: Date(),
                duration: 120,
                transcription: "测试录音1",
                title: "工作会议",
                summary: "会议摘要",
                tags: ["工作", "会议"],
                audioData: nil,
                enrichedContent: nil
            ),
            AudioRecording(
                timestamp: Date(),
                duration: 90,
                transcription: "测试录音2",
                title: "学习笔记",
                summary: "学习摘要",
                tags: ["学习", "笔记"],
                audioData: nil,
                enrichedContent: nil
            ),
            AudioRecording(
                timestamp: Date(),
                duration: 150,
                transcription: "测试录音3",
                title: "个人想法",
                summary: "个人摘要",
                tags: ["个人", "想法", "工作"],
                audioData: nil,
                enrichedContent: nil
            )
        ]
        
        VStack(spacing: 20) {
            Text("录音标签过滤器")
                .font(.headline)
            
            VStack(spacing: 16) {
                // 浅色模式
                RecordingTagFilter(
                    allRecordings: sampleRecordings,
                    selectedTag: .constant(nil)
                )
                .background(Color.appBackground)
                
                // 深色模式（模拟选中状态）
                RecordingTagFilter(
                    allRecordings: sampleRecordings,
                    selectedTag: .constant("工作")
                )
                .background(Color.black)
                .environment(\.colorScheme, .dark)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}