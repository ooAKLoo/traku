//
//  TagRenameView.swift
//  raku
//
//  Created by Assistant on 2025/9/21.
//

import SwiftUI
import Combine
import Foundation

// MARK: - 标签重命名视图
struct TagRenameView: View {
    let allTags: [String]
    let tagUsageCount: [String: Int]
    let isDarkMode: Bool
    @Binding var isPresented: Bool
    let onTagsUpdated: () -> Void
    
    @State private var selectedTag: String = ""
    @State private var newTagName: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var searchText = ""
    
    private let databaseManager = DatabaseManager.shared
    
    // 过滤后的标签
    private var filteredTags: [String] {
        if searchText.isEmpty {
            return allTags
        } else {
            return allTags.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                tagSelectorSection
                
                if !selectedTag.isEmpty {
                    renameInputSection
                }
                
                Spacer()
            }
            .padding()
            .background(isDarkMode ? Color.black : Color(white: 0.95))
            .navigationTitle("重命名标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    @ViewBuilder
    private var tagSelectorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择要重命名的标签")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(titleColor)
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(searchIconColor)
                
                TextField("搜索标签...", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(searchTextColor)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(searchIconColor)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(searchBarBackground)
            
            // 标签选择器
            if filteredTags.isEmpty && !searchText.isEmpty {
                // 搜索无结果
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                    
                    Text("未找到匹配的标签")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    
                    Text("尝试其他搜索词")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(filteredTags, id: \.self) { tag in
                            tagButton(for: tag)
                        }
                    }
                }
                .frame(maxHeight: 300)
                
                // 搜索结果提示
                if !searchText.isEmpty {
                    Text("找到 \(filteredTags.count) 个标签")
                        .font(.system(size: 12))
                        .foregroundColor(subtitleColor)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sectionBackgroundColor)
        )
    }
    
    @ViewBuilder
    private func tagButton(for tag: String) -> some View {
        Button(action: {
            selectedTag = tag
            newTagName = tag
            searchText = "" // 清除搜索框
        }) {
            HStack {
                Text(tag)
                    .font(.system(size: 14))
                    .foregroundColor(titleColor)
                
                Spacer()
                
                Text("\(tagUsageCount[tag] ?? 0)")
                    .font(.system(size: 12))
                    .foregroundColor(subtitleColor)
                
                if selectedTag == tag {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(getTagButtonBackground(for: tag))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func getTagButtonBackground(for tag: String) -> some View {
        let isSelected = selectedTag == tag
        let fillColor = isSelected ? 
            (isDarkMode ? Color.blue.opacity(0.15) : Color.blue.opacity(0.1)) :
            (isDarkMode ? Color.white.opacity(0.05) : Color.white)
        let strokeColor = isSelected ? Color.blue.opacity(0.3) : Color.clear
        
        RoundedRectangle(cornerRadius: 8)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(strokeColor, lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var renameInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新的标签名称")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(titleColor)
            
            TextField("请输入新的标签名称", text: $newTagName)
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(textFieldBackground)
                .foregroundColor(titleColor)
            
            Text("将影响 \(tagUsageCount[selectedTag] ?? 0) 条录音")
                .font(.system(size: 14))
                .foregroundColor(subtitleColor)
            
            Button(action: performRename) {
                Text("重命名")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canRename ? Color.blue : Color.gray.opacity(0.5))
                    )
            }
            .disabled(!canRename)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sectionBackgroundColor)
        )
    }
    
    // MARK: - Computed Properties
    private var titleColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var subtitleColor: Color {
        isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var sectionBackgroundColor: Color {
        isDarkMode ? Color.white.opacity(0.05) : Color.white
    }
    
    private var searchIconColor: Color {
        isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    private var searchTextColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
    }
    
    @ViewBuilder
    private var textFieldBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3), lineWidth: 0.5)
            )
    }
    
    private var canRename: Bool {
        !selectedTag.isEmpty && 
        !newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        newTagName.trimmingCharacters(in: .whitespacesAndNewlines) != selectedTag
    }
    
    private func performRename() {
        let trimmedNewName = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查新标签名是否已存在
        if allTags.contains(trimmedNewName) {
            alertMessage = "标签\"\(trimmedNewName)\"已存在，请选择其他名称"
            showingAlert = true
            return
        }
        
        // 获取所有录音记录
        let recordings = databaseManager.loadRecordings()
        var updatedCount = 0
        
        // 更新每个录音的标签
        for var recording in recordings {
            if recording.tags.contains(selectedTag) {
                var updatedTags = recording.tags
                if let index = updatedTags.firstIndex(of: selectedTag) {
                    updatedTags[index] = trimmedNewName
                    
                    recording = AudioRecording(
                        id: recording.id,
                        timestamp: recording.timestamp,
                        duration: recording.duration,
                        transcription: recording.transcription,
                        title: recording.title,
                        summary: recording.summary,
                        tags: updatedTags,
                        audioData: recording.audioData,
                        enrichedContent: recording.enrichedContent,
                        polishedText: recording.polishedText,
                        contentType: recording.contentType
                    )
                    
                    if databaseManager.updateRecording(recording) {
                        updatedCount += 1
                    }
                }
            }
        }
        
        if updatedCount > 0 {
            alertMessage = "成功重命名标签，已更新 \(updatedCount) 条录音"
            showingAlert = true
            onTagsUpdated()
            
            // 发送标签更新通知，让 AudioRecordingService 刷新数据
            NotificationCenter.default.post(name: .tagsDidUpdate, object: nil)
            
            isPresented = false
        } else {
            alertMessage = "重命名失败，请重试"
            showingAlert = true
        }
    }
}

// MARK: - Preview
struct TagRenameView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 浅色模式预览
            TagRenameView(
                allTags: ["工作", "学习", "生活", "旅行", "健康", "美食", "技术", "设计"],
                tagUsageCount: ["工作": 15, "学习": 8, "生活": 22, "旅行": 5, "健康": 3, "美食": 7, "技术": 12, "设计": 4],
                isDarkMode: false,
                isPresented: .constant(true),
                onTagsUpdated: {}
            )
            .previewDisplayName("Light Mode")
            
            // 深色模式预览
            TagRenameView(
                allTags: ["工作", "学习", "生活", "旅行", "健康", "美食", "技术", "设计"],
                tagUsageCount: ["工作": 15, "学习": 8, "生活": 22, "旅行": 5, "健康": 3, "美食": 7, "技术": 12, "设计": 4],
                isDarkMode: true,
                isPresented: .constant(true),
                onTagsUpdated: {}
            )
            .previewDisplayName("Dark Mode")
            .preferredColorScheme(.dark)
        }
    }
}