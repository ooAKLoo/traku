//
//  ChapterTabBar.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import SwiftUI

// MARK: - 章节标签栏
struct ChapterTabBar: View {
    let headings: [HeadingNode]
    @Binding var selectedHeadingId: String?
    let onHeadingSelected: ((Int) -> Void)?
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        if !headings.isEmpty {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(headings.indices, id: \.self) { index in
                            FloatingChapterTab(
                                heading: headings[index],
                                isSelected: selectedHeadingId == "\(index)",
                                isDarkMode: isDarkMode
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedHeadingId = "\(index)"
                                    onHeadingTapped(headings[index])
                                }
                            }
                            .id("\(index)")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: selectedHeadingId) { newValue in
                    if let newValue = newValue {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
            .background(
                // 浮动背景
                RoundedRectangle(cornerRadius: 24)
                    .fill(isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                    .shadow(
                        color: Color.black.opacity(isDarkMode ? 0.5 : 0.1),
                        radius: 20,
                        x: 0,
                        y: 5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
    
    private func onHeadingTapped(_ heading: HeadingNode) {
        // 查找标题的索引
        if let index = headings.firstIndex(where: { $0.text == heading.text && $0.normalizedLevel == heading.normalizedLevel }) {
            onHeadingSelected?(index)
        }
    }
}

// MARK: - 浮动章节标签
struct FloatingChapterTab: View {
    let heading: HeadingNode
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    
    // 计算显示文本
    private var displayText: String {
        let text = heading.text
        let cleanText = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if cleanText.count > 15 {
            return String(cleanText.prefix(12)) + "..."
        }
        return cleanText
    }
    
    var body: some View {
        Button(action: onTap) {
            Text(displayText)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(
                    isSelected 
                    ? (isDarkMode ? .black : .white)
                    : (isDarkMode ? .white.opacity(0.7) : .gray)
                )
                .lineLimit(1)
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

// MARK: - 带层级的标签样式
struct HierarchicalChapterTab: View {
    let heading: HeadingNode
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    
    private var displayText: String {
        let text = heading.text
        let cleanText = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if cleanText.count > 20 {
            return String(cleanText.prefix(17)) + "..."
        }
        return cleanText
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                // 层级指示器
                if heading.normalizedLevel > 1 {
                    ForEach(1..<heading.normalizedLevel, id: \.self) { _ in
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                            .frame(width: 2, height: 2)
                    }
                }
                
                // 标签内容
                Text(displayText)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(
                        isSelected 
                        ? (isDarkMode ? .white : .black)
                        : (isDarkMode ? .white.opacity(0.6) : .gray.opacity(0.8))
                    )
                    .padding(.vertical, 6)
                    .padding(.trailing, 12)
            }
            .padding(.leading, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected
                        ? (isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                        : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isSelected 
                        ? (isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                        : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 预览
struct ChapterTabBar_Previews: PreviewProvider {
    static var previews: some View {
        let sampleHeadings = [
            HeadingNode(text: "明确目标", originalLevel: 2, normalizedLevel: 1, range: NSRange()),
            HeadingNode(text: "行动清单", originalLevel: 2, normalizedLevel: 1, range: NSRange()),
            HeadingNode(text: "所需资源", originalLevel: 2, normalizedLevel: 1, range: NSRange()),
            HeadingNode(text: "时间规划", originalLevel: 2, normalizedLevel: 1, range: NSRange()),
            HeadingNode(text: "潜在挑战与应对措施的长标题示例", originalLevel: 2, normalizedLevel: 1, range: NSRange())
        ]
        
        ZStack {
            // 背景
            Color.gray.opacity(0.1)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                ChapterTabBar(
                    headings: sampleHeadings,
                    selectedHeadingId: .constant("1"),
                    onHeadingSelected: nil
                )
            }
        }
        .preferredColorScheme(.light)
    }
}