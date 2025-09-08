//
//  MarkdownSectionView.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import SwiftUI
import MarkdownUI

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 分段的 Markdown 视图
struct MarkdownSectionView: View {
    let content: String
    let headings: [HeadingNode]
    @Binding var selectedHeadingId: String?
    let scrollProxy: ScrollViewProxy?
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    // 编辑和删除回调
    var onEditSection: ((Int, String) -> Void)?
    var onDeleteSection: ((Int) -> Void)?
    
    // 弹窗状态
    @State private var showingPopupForSection: Int? = nil
    @State private var popupPosition: CGPoint = .zero
    @State private var selectedSection: Int? = nil
    
    // 将内容按标题分段
    private var sections: [MarkdownSection] {
        parseSections()
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(sections.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 0) {
                        // 锚点（带偏移量，让内容不要紧贴顶部）
                        Color.clear
                            .frame(height: 1)
                            .padding(.top, -80) // 负偏移让锚点在内容上方
                            .id("section_\(index)")
                        
                        // 内容
                        Markdown(sections[index].content)
                            .markdownTheme(.customCompact)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    // 只在非最后一个段落后添加间距
                    .padding(.bottom, index < sections.count - 1 ? 8 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedSection == index ? Color(hex: "F5F5F5") : Color.clear)
                    )
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // 单击选中section
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if selectedSection == index && showingPopupForSection == index {
                                            // 如果已选中且显示浮窗，则取消选中
                                            selectedSection = nil
                                            showingPopupForSection = nil
                                        } else {
                                            selectedSection = index
                                            // 计算弹出位置
                                            let frame = geometry.frame(in: .global)
                                            popupPosition = CGPoint(
                                                x: frame.midX,
                                                y: frame.minY + 40
                                            )
                                            showingPopupForSection = index
                                        }
                                    }
                                }
                        }
                    )
                }
            }
            
            // 弹出菜单
            if let sectionIndex = showingPopupForSection {
                SectionPopupMenu(
                    isShowing: $showingPopupForSection,
                    sectionIndex: sectionIndex,
                    position: popupPosition,
                    isDarkMode: isDarkMode,
                    onEdit: { index in
                        onEditSection?(index, sections[index].content)
                    },
                    onDelete: { index in
                        onDeleteSection?(index)
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
    }
    
    // 解析内容，按标题分段
    private func parseSections() -> [MarkdownSection] {
        var sections: [MarkdownSection] = []
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        var currentSection = MarkdownSection(headingIndex: nil, content: "")
        var currentContent: [String] = []
        
        for line in lines {
            // 检查是否是标题行
            if let headingMatch = matchHeading(line) {
                // 保存当前段落
                if !currentContent.isEmpty || currentSection.headingIndex != nil {
                    currentSection.content = currentContent.joined(separator: "\n")
                    sections.append(currentSection)
                }
                
                // 开始新段落
                let headingIndex = findHeadingIndex(headingMatch.text, level: headingMatch.level)
                currentSection = MarkdownSection(headingIndex: headingIndex, content: "")
                currentContent = [line] // 包含标题行
            } else {
                currentContent.append(line)
            }
        }
        
        // 保存最后一个段落
        if !currentContent.isEmpty {
            currentSection.content = currentContent.joined(separator: "\n")
            sections.append(currentSection)
        }
        
        return sections
    }
    
    // 匹配标题
    private func matchHeading(_ line: String) -> (text: String, level: Int)? {
        let pattern = "^(#{1,6})\\s+(.+?)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }
        
        let hashesRange = match.range(at: 1)
        let textRange = match.range(at: 2)
        
        guard let hashesSwiftRange = Range(hashesRange, in: line),
              let textSwiftRange = Range(textRange, in: line) else { return nil }
        
        let hashes = String(line[hashesSwiftRange])
        let text = String(line[textSwiftRange])
        
        return (text: text, level: hashes.count)
    }
    
    // 查找标题索引
    private func findHeadingIndex(_ text: String, level: Int) -> Int? {
        let cleanText = text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        return headings.firstIndex { heading in
            let headingCleanText = heading.text
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            return headingCleanText == cleanText && heading.originalLevel == level
        }
    }
}

// MARK: - Markdown 段落
struct MarkdownSection {
    let headingIndex: Int?
    var content: String
}

// MARK: - 弹出菜单
struct SectionPopupMenu: View {
    @Binding var isShowing: Int?
    let sectionIndex: Int
    let position: CGPoint
    let isDarkMode: Bool
    let onEdit: (Int) -> Void
    let onDelete: (Int) -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 编辑按钮
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowing = nil
                }
                onEdit(sectionIndex)
            }) {
                Image(systemName: "pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .frame(width: 44, height: 44)
            }
            
            // 分割线
            Rectangle()
                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                .frame(width: 0.5, height: 24)
            
            // 删除按钮
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.red)
                    .frame(width: 44, height: 44)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color(white: 0.15) : Color.white)
                .shadow(
                    color: isDarkMode ? Color.black.opacity(0.5) : Color.black.opacity(0.15),
                    radius: 20,
                    x: 0,
                    y: 5
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05),
                    lineWidth: 0.5
                )
        )
        .frame(width: 88, height: 44)
        .position(x: position.x, y: position.y)
        .confirmationDialog(
            "确定要删除这个段落吗？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isShowing = nil
                }
                onDelete(sectionIndex)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销")
        }
        .onTapGesture {
            // 点击菜单外部关闭
        }
        .background(
            // 全屏透明背景，点击关闭菜单
            Color.clear
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isShowing = nil
                    }
                }
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
        )
    }
}