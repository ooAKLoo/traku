//
//  TagMergeView.swift
//  raku
//
//  Created by Assistant on 2025/9/16.
//

import SwiftUI

struct TagMergeView: View {
    let allTags: [String]
    let tagUsageCount: [String: Int]
    let isDarkMode: Bool
    @Binding var isPresented: Bool
    let onTagsUpdated: () -> Void
    
    @State private var selectedTags: Set<String> = []
    @State private var targetTagName: String = ""
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let databaseManager = DatabaseManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 说明文本
                    VStack(alignment: .leading, spacing: 8) {
                        Text("合并标签")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Text("选择要合并的标签，然后输入新的标签名称")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    // 目标标签输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新标签名称")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        TextField("输入新标签名称", text: $targetTagName)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                            )
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    .padding(.horizontal)
                    
                    // 标签选择列表
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("选择要合并的标签")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Spacer()
                            
                            Text("已选择 \(selectedTags.count)")
                                .font(.system(size: 12))
                                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(allTags, id: \.self) { tag in
                                    TagSelectionRow(
                                        tag: tag,
                                        usageCount: tagUsageCount[tag] ?? 0,
                                        isSelected: selectedTags.contains(tag),
                                        isDarkMode: isDarkMode
                                    ) {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // 操作按钮
                    VStack(spacing: 12) {
                        Button(action: performMerge) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.merge")
                                        .font(.system(size: 16))
                                }
                                
                                Text(isProcessing ? "处理中..." : "合并标签")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(canPerformMerge ? Color.blue : Color.gray)
                            )
                        }
                        .disabled(!canPerformMerge || isProcessing)
                        
                        Button("取消") {
                            isPresented = false
                        }
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("合并标签")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var canPerformMerge: Bool {
        !targetTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedTags.count >= 2
    }
    
    private func performMerge() {
        guard canPerformMerge else { return }
        
        isProcessing = true
        
        let trimmedTargetTag = targetTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tagsToMerge = Array(selectedTags)
        
        Task {
            let success = await mergeTags(sourceTags: tagsToMerge, targetTag: trimmedTargetTag)
            
            DispatchQueue.main.async {
                self.isProcessing = false
                
                if success {
                    self.alertMessage = "成功合并 \(tagsToMerge.count) 个标签为「\(trimmedTargetTag)」"
                    self.showingAlert = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.onTagsUpdated()
                        self.isPresented = false
                    }
                } else {
                    self.alertMessage = "合并失败，请稍后重试"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func mergeTags(sourceTags: [String], targetTag: String) async -> Bool {
        let recordings = databaseManager.loadRecordings()
        var updatedCount = 0
        
        for var recording in recordings {
            var modified = false
            var newTags = recording.tags
            
            for sourceTag in sourceTags {
                if let index = newTags.firstIndex(of: sourceTag) {
                    newTags.remove(at: index)
                    modified = true
                }
            }
            
            if modified && !newTags.contains(targetTag) {
                newTags.append(targetTag)
            }
            
            if modified {
                recording.tags = newTags
                if databaseManager.updateRecording(recording) {
                    updatedCount += 1
                }
            }
        }
        
        print("✅ 标签合并完成，更新了 \(updatedCount) 条记录")
        return updatedCount > 0
    }
}

struct TagSelectionRow: View {
    let tag: String
    let usageCount: Int
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag)
                        .font(.system(size: 16))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("\(usageCount) 个记录")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? 
                          (isDarkMode ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05)) :
                          (isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}