//
//  MarkdownSectionView.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import SwiftUI
import MarkdownUI

// MARK: - 分段的 Markdown 视图
struct MarkdownSectionView: View {
    let content: String
    let headings: [HeadingNode]
    @Binding var selectedHeadingId: String?
    let scrollProxy: ScrollViewProxy?
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    // 将内容按标题分段
    private var sections: [MarkdownSection] {
        parseSections()
    }
    
    var body: some View {
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
                }
                // 只在非最后一个段落后添加间距
                .padding(.bottom, index < sections.count - 1 ? 8 : 0)
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