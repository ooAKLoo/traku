//
//  TagEditModal.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

struct TagEditModal: View {
    @Binding var isPresented: Bool
    @Binding var tags: [String]
    @State private var newTagText = ""
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    // 预设常用标签
    private let suggestedTags = ["会议", "学习", "工作", "生活", "重要", "灵感", "待办", "笔记"]
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.98))
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 当前标签
                    if !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("当前标签")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 80))
                            ], spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    HStack(spacing: 6) {
                                        Text("#\(tag)")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                                            .lineLimit(1)
                                        
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                removeTag(tag)
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // 添加新标签
                    VStack(alignment: .leading, spacing: 12) {
                        Text("添加标签")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                        
                        HStack {
                            TextField("输入标签名称", text: $newTagText)
                                .font(.system(size: 14))
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.1))
                                )
                                .onSubmit {
                                    addNewTag()
                                }
                            
                            Button(action: addNewTag) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                            }
                            .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 建议标签
                    VStack(alignment: .leading, spacing: 12) {
                        Text("常用标签")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 70))
                        ], spacing: 8) {
                            ForEach(suggestedTags.filter { !tags.contains($0) }, id: \.self) { tag in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        addTag(tag)
                                    }
                                }) {
                                    Text("#\(tag)")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("编辑标签")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                    .fontWeight(.medium)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    private func addNewTag() {
        let trimmedTag = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmedTag.isEmpty && !tags.contains(trimmedTag) else { return }
        
        addTag(trimmedTag)
        newTagText = ""
    }
    
    private func addTag(_ tag: String) {
        guard !tags.contains(tag) else { return }
        tags.append(tag)
    }
    
    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - 预览
struct TagEditModal_Previews: PreviewProvider {
    static var previews: some View {
        TagEditModal(
            isPresented: .constant(true),
            tags: .constant(["会议", "产品", "开发","sdfsdfwe","dfsds"])
        )
    }
}
