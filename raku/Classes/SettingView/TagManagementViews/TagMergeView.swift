//
//  TagMergeView.swift
//  raku
//
//  Created by Assistant on 2025/9/16.
//

import SwiftUI
import Foundation


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
    @State private var searchText = ""
    
    private let databaseManager = DatabaseManager.shared
    
    var filteredTags: [String] {
        if searchText.isEmpty {
            return allTags
        } else {
            return allTags.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 标题区域
                    headerSection
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // 新标签输入区域
                            newTagInputSection
                            
                            // 标签选择区域
                            tagSelectionSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    
                    // 底部操作栏
                    bottomActionBar
                }
            }
            .navigationBarHidden(true)
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        )
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("合并标签")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("将多个标签合并为一个")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                
                Spacer()
                
                // 占位符保持布局平衡
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isDarkMode ? Color.black : Color(white: 0.95))
    }
    
    private var newTagInputSection: some View {
        VStack(spacing: 16) {
            newTagInputHeader
            newTagTextField
        }
        .padding(20)
        .background(newTagInputBackground)
    }
    
    private var newTagInputHeader: some View {
        HStack {
            Image(systemName: "textformat")
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text("新标签名称")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(newTagHeaderColor)
            
            Spacer()
        }
    }
    
    private var newTagTextField: some View {
        TextField("为合并后的标签输入名称", text: $targetTagName)
            .font(.system(size: 16))
            .foregroundColor(newTagTextColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(newTagTextFieldBackground)
    }
    
    private var newTagHeaderColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var newTagTextColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var newTagInputBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
    }
    
    private var newTagTextFieldBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isDarkMode ? Color.white.opacity(0.08) : Color(white: 0.95))
            .overlay(newTagTextFieldStroke)
    }
    
    private var newTagTextFieldStroke: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(newTagTextFieldStrokeColor, lineWidth: 1)
    }
    
    private var newTagTextFieldStrokeColor: Color {
        !targetTagName.isEmpty ? Color.blue.opacity(0.3 as Double) : Color.clear
    }
    
    private var tagSelectionSection: some View {
        VStack(spacing: 16) {
            tagSelectionHeader
            tagSearchBar
            tagGrid
        }
        .padding(20)
        .background(tagSelectionBackground)
    }
    
    private var tagSelectionHeader: some View {
        HStack {
            Image(systemName: "tag")
                .font(.system(size: 20))
                .foregroundColor(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("选择要合并的标签")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(tagHeaderTitleColor)
                
                Text("已选择 \(selectedTags.count) 个标签")
                    .font(.system(size: 12))
                    .foregroundColor(tagHeaderSubtitleColor)
            }
            
            Spacer()
            
            if !selectedTags.isEmpty {
                Button("清空") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTags.removeAll()
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(.blue)
            }
        }
    }
    
    private var tagSearchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(searchIconColor)
            
            TextField("搜索标签", text: $searchText)
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
    }
    
    private var tagGrid: some View {
        Group {
            if filteredTags.isEmpty {
                emptyTagsView
            } else {
                tagGridView
            }
        }
    }
    
    private var emptyTagsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tag.slash")
                .font(.system(size: 32))
                .foregroundColor(emptyStateIconColor)
            
            Text("没有找到标签")
                .font(.system(size: 14))
                .foregroundColor(emptyStateTextColor)
        }
        .frame(height: 120)
    }
    
    private var tagGridView: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 12) {
            ForEach(filteredTags, id: \.self) { tag in
                ModernTagCard(
                    tag: tag,
                    usageCount: tagUsageCount[tag] ?? 0,
                    isSelected: selectedTags.contains(tag),
                    isDarkMode: isDarkMode
                ) {
                    handleTagSelection(tag)
                }
            }
        }
    }
    
    // MARK: - Color Properties
    
    private var tagHeaderTitleColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var tagHeaderSubtitleColor: Color {
        isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var searchIconColor: Color {
        isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    private var searchTextColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var emptyStateIconColor: Color {
        isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)
    }
    
    private var emptyStateTextColor: Color {
        isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    // MARK: - Background Properties
    
    private var tagSelectionBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
    }
    
    private var searchBarBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
    }
    
    // MARK: - Helper Methods
    
    private func handleTagSelection(_ tag: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        }
    }
    
    private var bottomActionBar: some View {
        VStack(spacing: 16) {
            if !selectedTags.isEmpty {
                selectedTagsPreview
            }
            
            mergeButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(actionBarBackground)
    }
    
    private var selectedTagsPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedTags), id: \.self) { tag in
                    selectedTagChip(tag: tag)
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func selectedTagChip(tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 12))
                .foregroundColor(.white)
            
            Button(action: {
                withAnimation {
                    _ = selectedTags.remove(tag)
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
//        .background(
////            Capsule()
////                .fill(Color.orange)
//        )
    }
    
    private var mergeButton: some View {
        Button(action: performMerge) {
            mergeButtonContent
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(mergeButtonBackground)
        }
        .disabled(!canPerformMerge || isProcessing)
        .scaleEffect(isProcessing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isProcessing)
    }
    
    private var mergeButtonContent: some View {
        HStack(spacing: 8) {
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 16, weight: .medium))
            }
            
            Text(isProcessing ? "合并中..." : "开始合并")
                .font(.system(size: 16, weight: .semibold))
        }
    }
    
    private var mergeButtonBackground: some View {
        RoundedRectangle(cornerRadius: 25)
            .fill(mergeButtonGradient)
            .shadow(color: mergeButtonShadowColor, radius: 8, x: 0, y: 4)
    }
    
    private var mergeButtonGradient: LinearGradient {
        if canPerformMerge {
            return LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8 as Double)], 
                startPoint: .leading, 
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.gray, Color.gray.opacity(0.8 as Double)], 
                startPoint: .leading, 
                endPoint: .trailing
            )
        }
    }
    
    private var mergeButtonShadowColor: Color {
        canPerformMerge ? Color.blue.opacity(0.3 as Double) : Color.clear
    }
    
    private var actionBarBackground: some View {
        Rectangle()
            .fill(isDarkMode ? Color.black : Color(white: 0.95))
    }
    
    private var actionBarShadowColor: Color {
        isDarkMode ? Color.clear : Color.black.opacity(0.05)
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
                    
                    // 发送标签更新通知
                    NotificationCenter.default.post(name: .tagsDidUpdate, object: nil)
                    
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

struct ModernTagCard: View {
    let tag: String
    let usageCount: Int
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    
    private var titleColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var subtitleColor: Color {
        isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var iconColor: Color {
        if isSelected {
            return .blue
        } else {
            return isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)
        }
    }
    
    private var indicatorActiveColor: Color {
        Color.blue.opacity(0.6 as Double)
    }
    
    private var indicatorInactiveColor: Color {
        isDarkMode ? Color.white.opacity(0.1 as Double) : Color.black.opacity(0.1 as Double)
    }
    
    private var backgroundFillColor: Color {
        if isSelected {
            return isDarkMode ? Color.blue.opacity(0.15 as Double) : Color.blue.opacity(0.08 as Double)
        } else {
            return isDarkMode ? Color.white.opacity(0.05 as Double) : Color(white: 0.98)
        }
    }
    
    private var strokeColor: Color {
        isSelected ? Color.blue.opacity(0.4 as Double) : Color.clear
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                cardHeader
                usageIndicator
            }
            .padding(16)
            .background(cardBackground)
        }
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var cardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tag)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                
                Text("\(usageCount) 个记录")
                    .font(.system(size: 11))
                    .foregroundColor(subtitleColor)
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(iconColor)
        }
    }
    
    private var usageIndicator: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(indicatorColor(for: index))
                        .frame(height: 2)
                }
            }
        }
        .frame(height: 2)
    }
    
    private func indicatorColor(for index: Int) -> Color {
        let activeCount = min(5, max(1, usageCount / 2))
        return index < activeCount ? indicatorActiveColor : indicatorInactiveColor
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(backgroundFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(strokeColor, lineWidth: 1.5)
            )
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
                    .foregroundColor(isSelected ? .blue : (isDarkMode ? .white.opacity(0.3 as Double) : .black.opacity(0.3 as Double)))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag)
                        .font(.system(size: 16))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("\(usageCount) 个记录")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6 as Double) : .black.opacity(0.6 as Double))
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? 
                          (isDarkMode ? Color.blue.opacity(0.1 as Double) : Color.blue.opacity(0.05 as Double)) :
                          (isDarkMode ? Color.white.opacity(0.05 as Double) : Color(white: 0.98))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.blue.opacity(0.3 as Double) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
