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
                                            // 计算弹出位置，确保在可见区域内
                                            let localFrame = geometry.frame(in: .local)
                                            let namedFrame = geometry.frame(in: .named("markdownSectionView"))
                                            let globalFrame = geometry.frame(in: .global)
                                            
                                            let popupWidth: CGFloat = 88
                                            let popupHeight: CGFloat = 44
                                            
                                            print("=== 弹窗位置计算调试 ===")
                                            print("section \(index) 点击")
                                            print("local frame: \(localFrame)")
                                            print("named frame: \(namedFrame)")
                                            print("global frame: \(globalFrame)")
                                            print("弹窗尺寸: \(popupWidth) x \(popupHeight)")
                                            
                                            // 使用global坐标系进行计算，确保边界检查正确
                                            let frame = globalFrame
                                            
                                            // 获取容器的实际可视区域
                                            let containerWidth = UIScreen.main.bounds.width
                                            let containerHeight = UIScreen.main.bounds.height
                                            
                                            print("容器尺寸: \(containerWidth) x \(containerHeight)")
                                            print("使用frame: \(frame)")
                                            
                                            // 计算X坐标，确保不超出容器边界
                                            let preferredX = frame.midX
                                            let minX = popupWidth / 2 + 20
                                            let maxX = containerWidth - popupWidth / 2 - 20
                                            let adjustedX = max(minX, min(maxX, preferredX))
                                            
                                            print("X坐标计算: 期望=\(preferredX), 范围=[\(minX), \(maxX)], 最终=\(adjustedX)")
                                            
                                            // 计算Y坐标，优先显示在段落上方，如果空间不够则显示在下方
                                            var adjustedY: CGFloat
                                            if frame.minY > popupHeight + 60 {
                                                // 上方有足够空间，显示在段落上方
                                                adjustedY = frame.minY - 30
                                                print("Y坐标: 上方显示, frame.minY=\(frame.minY), adjustedY=\(adjustedY)")
                                            } else {
                                                // 上方空间不够，显示在段落下方
                                                adjustedY = frame.maxY + 30
                                                print("Y坐标: 下方显示, frame.maxY=\(frame.maxY), adjustedY=\(adjustedY)")
                                            }
                                            
                                            // 确保Y坐标在屏幕可见区域内（使用global坐标系）
                                            let safeAreaTop: CGFloat = 100  // 状态栏+导航栏高度
                                            let safeAreaBottom: CGFloat = 150  // 底部安全区域
                                            
                                            let minY = safeAreaTop + popupHeight / 2
                                            let maxY = containerHeight - safeAreaBottom - popupHeight / 2
                                            let originalY = adjustedY
                                            adjustedY = max(minY, min(maxY, adjustedY))
                                            
                                            print("Y坐标边界检查: 原始=\(originalY), 范围=[\(minY), \(maxY)], 最终=\(adjustedY)")
                                            
                                            // 将global坐标转换为named坐标系
                                            let globalToNamedOffsetY = namedFrame.minY - globalFrame.minY
                                            let namedY = adjustedY + globalToNamedOffsetY
                                            
                                            popupPosition = CGPoint(x: adjustedX, y: namedY)
                                            showingPopupForSection = index
                                            
                                            print("最终弹窗位置: \(popupPosition)")
                                            print("选中section: \(index), 弹窗显示: \(showingPopupForSection ?? -1)")
                                            print("======================\n")
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
                        print("编辑按钮点击 - section: \(index)")
                        onEditSection?(index, sections[index].content)
                    },
                    onDelete: { index in
                        print("删除按钮点击 - section: \(index)")
                        onDeleteSection?(index)
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
                .onAppear {
                    print("弹窗显示 - section: \(sectionIndex), position: \(popupPosition)")
                }
                .onDisappear {
                    print("弹窗消失 - section: \(sectionIndex)")
                }
            }
        }
        .coordinateSpace(name: "markdownSectionView")
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
        .onAppear {
            print("SectionPopupMenu显示 - section: \(sectionIndex)")
            print("弹窗实际位置: x=\(position.x), y=\(position.y)")
            print("在named坐标系中显示弹窗")
        }
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