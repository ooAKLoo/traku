//
//  TagFilterTabBar.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import SwiftUI

// MARK: - 标签过滤 TabBar
struct TagFilterTabBar: View {
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
                HStack(spacing: 8) {
                    // "全部" 选项
                    TagFilterItem(
                        title: "全部",
                        count: allRecordings.count,
                        isSelected: selectedTag == nil,
                        isDarkMode: isDarkMode
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTag = nil
                        }
                    }
                    
                    // 各个标签选项
                    ForEach(allTags, id: \.self) { tag in
                        TagFilterItem(
                            title: tag,
                            count: getTagCount(tag),
                            isSelected: selectedTag == tag,
                            isDarkMode: isDarkMode
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(
                // 简洁背景，与 header 保持一致
                (isDarkMode ? Color.black : Color.white)
            )
//            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - 标签过滤项
struct TagFilterItem: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(
                        isSelected 
                        ? (isDarkMode ? .black : .white)
                        : (isDarkMode ? .white.opacity(0.7) : .gray)
                    )
                
                // 数量标签
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(
                        isSelected
                        ? (isDarkMode ? .black.opacity(0.6) : .white.opacity(0.7))
                        : (isDarkMode ? .white.opacity(0.4) : .gray.opacity(0.6))
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(
                                isSelected
                                ? (isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                                : (isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.15))
                            )
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        isSelected
                        ? (isDarkMode ? Color.white : Color.black)
                        : (isDarkMode ? Color.white.opacity(0.12) : Color.gray.opacity(0.1))
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - 预览
struct TagFilterTabBar_Previews: PreviewProvider {
    static var previews: some View {
        let sampleRecordings = [
            AudioRecording(
                timestamp: Date(),
                duration: 120.5,
                transcription: "会议录音",
                summary: "项目讨论",
                tags: ["会议", "工作"],
                audioData: Data(),
                enrichedContent: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-3600),
                duration: 45.2,
                transcription: "学习笔记",
                summary: "知识总结",
                tags: ["学习", "笔记"],
                audioData: Data(),
                enrichedContent: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-7200),
                duration: 89.1,
                transcription: "个人想法",
                summary: "灵感记录",
                tags: ["个人", "想法", "创意"],
                audioData: Data(),
                enrichedContent: nil
            )
        ]
        
        ZStack {
            Color.gray.opacity(0.1)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                TagFilterTabBar(
                    allRecordings: sampleRecordings,
                    selectedTag: .constant("会议")
                )
            }
        }
        .preferredColorScheme(.light)
    }
}
