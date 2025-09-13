//
//  SectionEditModal.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import SwiftUI
import MarkdownUI

// MARK: - 段落编辑模态组件
struct SectionEditModal: View {
    @Binding var isPresented: Bool
    @State var sectionContent: String
    let sectionIndex: Int
    let onSave: (Int, String) -> Void
    
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showPreview = false
    @FocusState private var isTextEditorFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 预览/编辑切换
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPreview = false
                        }
                    }) {
                        Text("编辑")
                            .font(.system(size: 14, weight: showPreview ? .regular : .semibold))
                            .foregroundColor(showPreview ? 
                                (isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)) :
                                (isDarkMode ? .white : .black)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPreview = true
                            isTextEditorFocused = false
                        }
                    }) {
                        Text("预览")
                            .font(.system(size: 14, weight: showPreview ? .semibold : .regular))
                            .foregroundColor(showPreview ? 
                                (isDarkMode ? .white : .black) :
                                (isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                .background(
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .frame(width: geometry.size.width / 2)
                            .offset(x: showPreview ? geometry.size.width / 2 : 0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPreview)
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                
                // 内容区域
                if showPreview {
                    // Markdown 预览
                    ScrollView {
                        Markdown(sectionContent)
                            .markdownTheme(.customCompact)
                            .padding(16)
                    }
                    .background(isDarkMode ? Color.black : Color(white: 0.98))
                } else {
                    // 文本编辑器
                    TextEditor(text: $sectionContent)
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .scrollContentBackground(.hidden)
                        .background(isDarkMode ? Color.black : Color(white: 0.98))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .focused($isTextEditorFocused)
                        .onAppear {
                            isTextEditorFocused = true
                        }
                }
                
                // 底部工具栏（仅在编辑模式显示）
                if !showPreview {
                    Divider()
                        .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            MarkdownToolButton(symbol: "#", label: "标题") {
                                insertMarkdown("## ")
                            }
                            MarkdownToolButton(symbol: "B", label: "粗体") {
                                wrapSelection("**")
                            }
                            MarkdownToolButton(symbol: "I", label: "斜体") {
                                wrapSelection("*")
                            }
                            MarkdownToolButton(symbol: "•", label: "列表") {
                                insertMarkdown("- ")
                            }
                            MarkdownToolButton(symbol: "[ ]", label: "待办") {
                                insertMarkdown("- [ ] ")
                            }
                            MarkdownToolButton(symbol: ">", label: "引用") {
                                insertMarkdown("> ")
                            }
                            MarkdownToolButton(symbol: "</", label: "代码") {
                                wrapSelection("`")
                            }
                            MarkdownToolButton(symbol: "—", label: "分割线") {
                                insertMarkdown("\n---\n")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(isDarkMode ? Color(white: 0.08) : Color(white: 0.95))
                }
            }
            .navigationTitle("编辑段落")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(sectionIndex, sectionContent)
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    // Markdown 插入辅助函数
    private func insertMarkdown(_ text: String) {
        sectionContent.append(text)
    }
    
    private func wrapSelection(_ wrapper: String) {
        // 简单实现：在光标位置插入
        sectionContent.append("\(wrapper)文本\(wrapper)")
    }
}

// MARK: - Markdown 工具按钮原子组件
struct MarkdownToolButton: View {
    let symbol: String
    let label: String
    let action: () -> Void
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(symbol)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
            .frame(minWidth: 44, minHeight: 44)
        }
    }
}

// MARK: - 预览
struct SectionEditModal_Previews: PreviewProvider {
    static var previews: some View {
        SectionEditModal(
            isPresented: .constant(true),
            sectionContent: """
            ## 示例标题
            
            这是一段 **Markdown** 文本，包含了 *斜体* 和 `代码` 样式。
            
            - 列表项 1
            - 列表项 2
            - [ ] 待办事项
            
            > 这是一段引用文本
            """,
            sectionIndex: 0,
            onSave: { _, _ in }
        )
    }
}