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
    @State private var showingAllTags = false

    private var allTags: [String] {
        let tags = Set(allRecordings.flatMap { $0.tags })
        return Array(tags).sorted()
    }

    private func getTagCount(_ tag: String) -> Int {
        return allRecordings.filter { $0.tags.contains(tag) }.count
    }

    private var backgroundColor: Color {
        isDarkMode ? Color.black : Color.appBackground
    }

    private var showExpandButton: Bool {
        allTags.count > 3
    }

    var body: some View {
        if !allTags.isEmpty {
            // 以 ScrollView 为主体，遮罩作为 overlay 覆盖
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UIConstants.TagFilter.tagSpacing) {
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
                .padding(.leading, UIConstants.horizontalPadding)
                .padding(.trailing, showExpandButton ? UIConstants.TagFilter.expandAreaWidth : UIConstants.horizontalPadding)
                .padding(.vertical, UIConstants.TagFilter.verticalPadding)
            }
            .background(backgroundColor)
            // 使用 overlay 放置遮罩，高度自动跟随主体
            .overlay(alignment: .trailing) {
                if showExpandButton {
                    HStack(spacing: 0) {
                        // 1. 渐变遮罩：保持原样
                        LinearGradient(
                            colors: [backgroundColor.opacity(0), backgroundColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: UIConstants.TagFilter.gradientWidth)

                        // 2. 组合区域：背景块 + 按钮图标
                        // 把背景色放在 ZStack 底层,而不是 Button 内部,这样点击按钮时背景不会变透明
                        ZStack {
                            backgroundColor // 稳定的底色

                            Button(action: { showingAllTags = true }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.4))
                                    .contentShape(Rectangle()) // 确保整个区域可点击
                            }
                            .buttonStyle(PlainButtonStyle()) // 禁用默认的透明度变化缩放效果
                            .padding(.bottom, 6) // 向上偏移，与底部横条对齐
                        }
                        .frame(width: UIConstants.TagFilter.expandButtonWidth)

                        // 3. 右侧 20pt 遮挡块：确保滚动到底部时完全盖住
                        backgroundColor
                            .frame(width: UIConstants.horizontalPadding)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .sheet(isPresented: $showingAllTags) {
                TagSelectionSheet(
                    allTags: allTags,
                    allRecordings: allRecordings,
                    selectedTag: $selectedTag,
                    isPresented: $showingAllTags,
                    isDarkMode: isDarkMode,
                    getTagCount: getTagCount
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
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