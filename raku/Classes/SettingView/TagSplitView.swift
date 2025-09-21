//
//  TagSplitView.swift
//  raku
//
//  Created by Assistant on 2025/9/16.
//

import SwiftUI
import Foundation


struct TagSplitView: View {
    let allTags: [String]
    let tagUsageCount: [String: Int]
    let isDarkMode: Bool
    @Binding var isPresented: Bool
    let onTagsUpdated: () -> Void
    
    @State private var selectedTag: String = ""
    @State private var recordingsWithTag: [AudioRecording] = []
    @State private var newTagNames: [String] = ["", ""]
    @State private var recordingTagAssignments: [UUID: String] = [:]
    @State private var isProcessing = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var currentStep: SplitStep = .selectTag
    @State private var searchText = ""
    @State private var selectedRecordingIds: Set<UUID> = []
    @State private var showBatchActions = false
    
    private let databaseManager = DatabaseManager.shared
    
    enum SplitStep {
        case selectTag
        case defineNewTags
        case assignRecords
    }
    
    var filteredTags: [String] {
        if searchText.isEmpty {
            return allTags
        } else {
            return allTags.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var validNewTagNames: [String] {
        newTagNames.compactMap { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
    
    var canPerformSplit: Bool {
        !validNewTagNames.isEmpty &&
        recordingTagAssignments.values.allSatisfy { !$0.isEmpty }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部导航栏
                    headerSection
                    
                    // 步骤指示器
                    stepIndicatorSection
                    
                    // 主要内容
                    ScrollView {
                        VStack(spacing: 24) {
                            switch currentStep {
                            case .selectTag:
                                tagSelectionStepView
                            case .defineNewTags:
                                defineNewTagsStepView
                            case .assignRecords:
                                recordAssignmentStepView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                    .background(isDarkMode ? Color.black : Color(white: 0.95))
                    
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
                Text("拆分标签")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Text("将一个标签拆分为多个")
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            
            Spacer()
            
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isDarkMode ? Color.black : Color(white: 0.95))
    }
    
    private var stepIndicatorSection: some View {
        HStack(spacing: 0) {
            StepIndicatorView(
                number: 1,
                title: "选择标签",
                isActive: currentStep == .selectTag,
                isCompleted: !selectedTag.isEmpty,
                isDarkMode: isDarkMode
            )
            
            Rectangle()
                .fill(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            
            StepIndicatorView(
                number: 2,
                title: "设置新标签",
                isActive: currentStep == .defineNewTags,
                isCompleted: !validNewTagNames.isEmpty,
                isDarkMode: isDarkMode
            )
            
            Rectangle()
                .fill(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            
            StepIndicatorView(
                number: 3,
                title: "分配记录",
                isActive: currentStep == .assignRecords,
                isCompleted: false,
                isDarkMode: isDarkMode
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isDarkMode ? Color.black : Color(white: 0.95))
    }
    
    private var tagSelectionStepView: some View {
        VStack(spacing: 20) {
            // 标题和说明
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "1.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("选择要拆分的标签")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Text("选择一个需要拆分的标签")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
            )
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                
                TextField("搜索标签", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                    )
            )
            
            // 标签列表
            if filteredTags.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 40))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                    
                    Text("没有找到标签")
                        .font(.system(size: 16))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                .frame(height: 160)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredTags, id: \.self) { tag in
                        SelectableTagCard(
                            tag: tag,
                            usageCount: tagUsageCount[tag] ?? 0,
                            isSelected: selectedTag == tag,
                            isDarkMode: isDarkMode
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTag = tag
                                loadRecordingsForTag(tag)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var defineNewTagsStepView: some View {
        VStack(spacing: 24) {
            // 步骤标题
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "2.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("设置新标签名称")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Text("将「\(selectedTag)」拆分为多个新标签")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
            )
            
            // 新标签输入区域
            newTagInputSection
            
            // 提示信息
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                
                Text("至少创建一个新标签，建议创建2-3个以便更好地组织记录")
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.05))
            )
        }
    }
    
    private var recordAssignmentStepView: some View {
        VStack(spacing: 24) {
            // 步骤标题
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "3.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("为记录分配新标签")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Text("标签「\(selectedTag)」有 \(recordingsWithTag.count) 个记录")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
            )
            
            // 智能分组建议
            if !recordingsWithTag.isEmpty && validNewTagNames.count >= 2 {
                intelligentGroupingSuggestion
            }
            
            // 记录分配区域
            if !recordingsWithTag.isEmpty {
                recordAssignmentSection
            }
        }
    }
    
    private var newTagInputSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "textformat")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                    .frame(width: 24)
                
                Text("新标签名称")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                Button(action: addNewTagField) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("添加")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.blue)
                }
            }
            
            VStack(spacing: 12) {
                ForEach(0..<newTagNames.count, id: \.self) { index in
                    HStack(spacing: 12) {
                        TextField("标签 \(index + 1)", text: $newTagNames[index])
                            .font(.system(size: 16))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color(white: 0.95))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                !newTagNames[index].isEmpty ? Color.green.opacity(0.3) : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                            )
                        
                        if newTagNames.count > 2 {
                            Button(action: { removeNewTagField(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
        )
    }
    
    private var intelligentGroupingSuggestion: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                Text("智能分组建议")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                // 按内容长度分组
                Button(action: groupByContentLength) {
                    VStack(spacing: 6) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        
                        Text("按长度分组")
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color(white: 0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // 按时间分组
                Button(action: groupByDate) {
                    VStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        
                        Text("按时间分组")
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color(white: 0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // 平均分配
                Button(action: distributeEvenly) {
                    VStack(spacing: 6) {
                        Image(systemName: "equal.square")
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                        
                        Text("平均分配")
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color(white: 0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var recordAssignmentSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)
                    .frame(width: 24)
                
                Text("记录分配")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                Text("\(recordingsWithTag.count) 个记录")
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            
            // 批量操作工具栏
            if showBatchActions {
                batchActionsToolbar
            }
            
            LazyVStack(spacing: 12) {
                ForEach(recordingsWithTag, id: \.id) { recording in
                    HStack(spacing: 12) {
                        // 选择框
                        if showBatchActions {
                            Button(action: { toggleSelection(for: recording.id) }) {
                                Image(systemName: selectedRecordingIds.contains(recording.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedRecordingIds.contains(recording.id) ? .blue : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                            }
                            .animation(.easeInOut(duration: 0.2), value: selectedRecordingIds.contains(recording.id))
                        }
                        
                        ModernRecordingCard(
                            recording: recording,
                            availableTagNames: validNewTagNames,
                            selectedTag: recordingTagAssignments[recording.id] ?? "",
                            isDarkMode: isDarkMode
                        ) { newTag in
                            recordingTagAssignments[recording.id] = newTag
                        }
                    }
                }
            }
            
            // 批量操作切换按钮
            Button(action: { withAnimation { showBatchActions.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: showBatchActions ? "xmark.circle" : "checkmark.circle")
                        .font(.system(size: 14))
                    Text(showBatchActions ? "退出批量模式" : "批量操作")
                        .font(.system(size: 14))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
        )
    }
    
    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            switch currentStep {
            case .selectTag:
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = .defineNewTags
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                        
                        Text("下一步")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(
                                selectedTag.isEmpty ? 
                                LinearGradient(colors: [Color.gray, Color.gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                            )
                            .shadow(color: selectedTag.isEmpty ? Color.clear : Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(selectedTag.isEmpty)
                .scaleEffect(selectedTag.isEmpty ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: selectedTag.isEmpty)
                
            case .defineNewTags:
                HStack(spacing: 12) {
                    Button(action: { 
                        withAnimation {
                            currentStep = .selectTag 
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.circle")
                                .font(.system(size: 16))
                            Text("上一步")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(isDarkMode ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        )
                    }
                    
                    Button(action: proceedToAssignment) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 16))
                            
                            Text("下一步")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    validNewTagNames.isEmpty ? 
                                    LinearGradient(colors: [Color.gray, Color.gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: validNewTagNames.isEmpty ? Color.clear : Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(validNewTagNames.isEmpty)
                    .scaleEffect(validNewTagNames.isEmpty ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: validNewTagNames.isEmpty)
                }
                
            case .assignRecords:
                HStack(spacing: 12) {
                    Button(action: { 
                        withAnimation {
                            currentStep = .defineNewTags 
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.circle")
                                .font(.system(size: 16))
                            Text("上一步")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(isDarkMode ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                        )
                    }
                    
                    Button(action: performSplit) {
                        HStack(spacing: 8) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 16))
                            }
                            
                            Text(isProcessing ? "拆分中..." : "开始拆分")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(
                                    canPerformSplit ? 
                                    LinearGradient(colors: [Color.orange, Color.orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                    LinearGradient(colors: [Color.gray, Color.gray.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                )
                                .shadow(color: canPerformSplit ? Color.orange.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(!canPerformSplit || isProcessing)
                    .scaleEffect(isProcessing ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isProcessing)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(isDarkMode ? Color.black : Color(white: 0.95))
    }
    
    // MARK: - Batch Actions Toolbar
    
    private var batchActionsToolbar: some View {
        HStack(spacing: 12) {
            // 全选/取消全选
            Button(action: toggleSelectAll) {
                HStack(spacing: 4) {
                    Image(systemName: selectedRecordingIds.count == recordingsWithTag.count ? "checkmark.square.fill" : "square")
                    Text(selectedRecordingIds.count == recordingsWithTag.count ? "取消全选" : "全选")
                }
                .font(.system(size: 14))
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
            }
            
            Spacer()
            
            // 显示选中数量
            if !selectedRecordingIds.isEmpty {
                Text("已选择 \(selectedRecordingIds.count) 个")
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            
            // 批量分配菜单
            if !selectedRecordingIds.isEmpty && !validNewTagNames.isEmpty {
                Menu {
                    ForEach(validNewTagNames, id: \.self) { tag in
                        Button(action: { batchAssignToTag(tag) }) {
                            Label(tag, systemImage: "tag")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                        Text("批量分配")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.orange)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
        )
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelection(for id: UUID) {
        if selectedRecordingIds.contains(id) {
            selectedRecordingIds.remove(id)
        } else {
            selectedRecordingIds.insert(id)
        }
    }
    
    private func toggleSelectAll() {
        if selectedRecordingIds.count == recordingsWithTag.count {
            selectedRecordingIds.removeAll()
        } else {
            selectedRecordingIds = Set(recordingsWithTag.map { $0.id })
        }
    }
    
    private func batchAssignToTag(_ tag: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            for id in selectedRecordingIds {
                recordingTagAssignments[id] = tag
            }
            // 清空选择并退出批量模式
            selectedRecordingIds.removeAll()
            showBatchActions = false
        }
    }
    
    private func loadRecordingsForTag(_ tag: String) {
        recordingsWithTag = databaseManager.loadRecordings().filter { recording in
            recording.tags.contains(tag)
        }
        
        recordingTagAssignments.removeAll()
        selectedRecordingIds.removeAll()
        
        // 智能分配：基于内容长度或其他规则
        let sortedRecordings = recordingsWithTag.sorted { $0.transcription.count > $1.transcription.count }
        let midPoint = sortedRecordings.count / 2
        
        for (index, recording) in sortedRecordings.enumerated() {
            if validNewTagNames.count >= 2 {
                // 长内容分配到第一个标签，短内容分配到第二个标签
                recordingTagAssignments[recording.id] = index < midPoint ? validNewTagNames[0] : validNewTagNames[1]
            } else {
                recordingTagAssignments[recording.id] = validNewTagNames.first ?? ""
            }
        }
    }
    
    private func proceedToAssignment() {
        if selectedTag.isEmpty || validNewTagNames.isEmpty { return }
        
        // 只有在第一次进入分配页面时才加载记录
        if recordingsWithTag.isEmpty {
            loadRecordingsForTag(selectedTag)
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .assignRecords
        }
    }
    
    private func addNewTagField() {
        newTagNames.append("")
    }
    
    private func removeNewTagField(at index: Int) {
        guard newTagNames.count > 2 && index < newTagNames.count else { return }
        newTagNames.remove(at: index)
    }
    
    private func groupByContentLength() {
        guard validNewTagNames.count >= 2 else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let sortedRecordings = recordingsWithTag.sorted { $0.transcription.count > $1.transcription.count }
            let midPoint = sortedRecordings.count / 2
            
            for (index, recording) in sortedRecordings.enumerated() {
                // 长内容分配到第一个标签，短内容分配到第二个标签
                recordingTagAssignments[recording.id] = index < midPoint ? validNewTagNames[0] : validNewTagNames[1]
            }
        }
    }
    
    private func groupByDate() {
        guard validNewTagNames.count >= 2 else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let sortedRecordings = recordingsWithTag.sorted { (first: AudioRecording, second: AudioRecording) in
                first.timestamp > second.timestamp
            }
            let midPoint = sortedRecordings.count / 2
            
            for (index, recording) in sortedRecordings.enumerated() {
                // 新记录分配到第一个标签，旧记录分配到第二个标签
                recordingTagAssignments[recording.id] = index < midPoint ? validNewTagNames[0] : validNewTagNames[1]
            }
        }
    }
    
    private func distributeEvenly() {
        guard !validNewTagNames.isEmpty else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let tagCount = validNewTagNames.count
            
            for (index, recording) in recordingsWithTag.enumerated() {
                // 平均分配到各个标签
                let tagIndex = index % tagCount
                recordingTagAssignments[recording.id] = validNewTagNames[tagIndex]
            }
        }
    }
    
    private func performSplit() {
        guard canPerformSplit else { return }
        
        isProcessing = true
        
        Task {
            let success = await splitTag()
            
            DispatchQueue.main.async {
                self.isProcessing = false
                
                if success {
                    self.alertMessage = "成功拆分标签「\(self.selectedTag)」"
                    self.showingAlert = true
                    
                    // 发送标签更新通知
                    NotificationCenter.default.post(name: .tagsDidUpdate, object: nil)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.onTagsUpdated()
                        self.isPresented = false
                    }
                } else {
                    self.alertMessage = "拆分失败，请稍后重试"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func splitTag() async -> Bool {
        var updatedCount = 0
        
        for var recording in recordingsWithTag {
            guard let newTag = recordingTagAssignments[recording.id],
                  !newTag.isEmpty else { continue }
            
            var newTags = recording.tags
            
            if let index = newTags.firstIndex(of: selectedTag) {
                newTags.remove(at: index)
            }
            
            if !newTags.contains(newTag) {
                newTags.append(newTag)
            }
            
            recording.tags = newTags
            
            if databaseManager.updateRecording(recording) {
                updatedCount += 1
            }
        }
        
        print("✅ 标签拆分完成，更新了 \(updatedCount) 条记录")
        return updatedCount > 0
    }
}

// MARK: - Supporting Views

struct StepIndicatorView: View {
    let number: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textColor)
                }
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(titleColor)
        }
    }
    
    private var circleColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .blue
        } else {
            return isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        if isActive {
            return .white
        } else {
            return isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
        }
    }
    
    private var titleColor: Color {
        if isActive || isCompleted {
            return isDarkMode ? .white : .black
        } else {
            return isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
        }
    }
}

struct SelectableTagCard: View {
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
    
    private var indicatorActiveColor: Color {
        Color.blue.opacity(0.7)
    }
    
    private var indicatorInactiveColor: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    private var backgroundFillColor: Color {
        if isSelected {
            return isDarkMode ? Color.blue.opacity(0.15) : Color.blue.opacity(0.08)
        } else {
            return isDarkMode ? Color.white.opacity(0.05) : Color(white: 0.98)
        }
    }
    
    private var strokeColor: Color {
        if isSelected {
            return Color.blue.opacity(0.5)
        } else {
            return isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
        }
    }
    
    private var strokeWidth: CGFloat {
        isSelected ? 2 : 1
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                cardHeader
                usageIndicator
            }
            .padding(16)
            .background(cardBackground)
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var cardHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tag)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(titleColor)
                    .lineLimit(1)
                
                Text("\(usageCount) 个记录")
                    .font(.system(size: 12))
                    .foregroundColor(subtitleColor)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var usageIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(indicatorColor(for: index))
                    .frame(height: 3)
            }
        }
    }
    
    private func indicatorColor(for index: Int) -> Color {
        let activeCount = min(5, max(1, usageCount / 3))
        return index < activeCount ? indicatorActiveColor : indicatorInactiveColor
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(backgroundFillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
    }
}

struct ModernRecordingCard: View {
    let recording: AudioRecording
    let availableTagNames: [String]
    let selectedTag: String
    let isDarkMode: Bool
    let onTagSelected: (String) -> Void
    
    private var titleColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var subtitleColor: Color {
        isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6)
    }
    
    private var durationBadgeColor: Color {
        isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)
    }
    
    private var durationBackgroundColor: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05)
    }
    
    private var labelColor: Color {
        isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)
    }
    
    private var menuTextColor: Color {
        if selectedTag.isEmpty {
            return isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)
        } else {
            return .blue
        }
    }
    
    private var chevronColor: Color {
        isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)
    }
    
    private var menuBackgroundColor: Color {
        isDarkMode ? Color.white.opacity(0.08) : Color(white: 0.98)
    }
    
    private var menuStrokeColor: Color {
        !selectedTag.isEmpty ? Color.blue.opacity(0.3) : Color.clear
    }
    
    private var cardBackgroundColor: Color {
        isDarkMode ? Color.white.opacity(0.05) : Color(white: 0.98)
    }
    
    private var cardStrokeColor: Color {
        if !selectedTag.isEmpty {
            return Color.green.opacity(0.3)
        } else {
            return isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            recordingInfoSection
            
            if !availableTagNames.isEmpty {
                tagSelectionSection
            }
        }
        .padding(16)
        .background(cardBackground)
    }
    
    private var recordingInfoSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(recording.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(titleColor)
                    .lineLimit(2)
                
                Text(recording.transcription)
                    .font(.system(size: 13))
                    .foregroundColor(subtitleColor)
                    .lineLimit(3)
            }
            
            Spacer()
            
            durationBadge
        }
    }
    
    private var durationBadge: some View {
        Text(String(format: "%.0fs", recording.duration))
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(durationBadgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(durationBackgroundColor)
            )
    }
    
    private var tagSelectionSection: some View {
        HStack {
            Text("分配到：")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(labelColor)
            
            tagMenu
            
            Spacer()
        }
    }
    
    private var tagMenu: some View {
        Menu {
            ForEach(availableTagNames, id: \.self) { tagName in
                Button(tagName) {
                    onTagSelected(tagName)
                }
            }
        } label: {
            menuLabel
        }
    }
    
    private var menuLabel: some View {
        HStack {
            Text(selectedTag.isEmpty ? "选择标签" : selectedTag)
                .font(.system(size: 14))
                .foregroundColor(menuTextColor)
            
            Image(systemName: "chevron.down")
                .font(.system(size: 12))
                .foregroundColor(chevronColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(menuBackground)
    }
    
    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(menuBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(menuStrokeColor, lineWidth: 1)
            )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(cardBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cardStrokeColor, lineWidth: 1)
            )
    }
}