//
//  TagSplitView.swift
//  raku
//
//  Created by Assistant on 2025/9/16.
//

import SwiftUI

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
    
    private let databaseManager = DatabaseManager.shared
    
    enum SplitStep {
        case selectTag
        case assignRecords
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 步骤指示器
                    stepIndicator
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if currentStep == .selectTag {
                                tagSelectionStep
                            } else {
                                recordAssignmentStep
                            }
                        }
                        .padding()
                    }
                    
                    // 底部按钮
                    bottomButtons
                }
            }
            .navigationTitle("拆分标签")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var stepIndicator: some View {
        HStack {
            StepIndicatorItem(
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
            
            StepIndicatorItem(
                number: 2,
                title: "分配记录",
                isActive: currentStep == .assignRecords,
                isCompleted: false,
                isDarkMode: isDarkMode
            )
        }
        .padding()
        .background(
            Rectangle()
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .ignoresSafeArea(edges: .horizontal)
        )
    }
    
    private var tagSelectionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("第一步：选择要拆分的标签")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Text("选择一个标签，然后为其下的记录分配到新的标签中")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
            }
            
            LazyVStack(spacing: 8) {
                ForEach(allTags, id: \.self) { tag in
                    TagSelectionRow(
                        tag: tag,
                        usageCount: tagUsageCount[tag] ?? 0,
                        isSelected: selectedTag == tag,
                        isDarkMode: isDarkMode
                    ) {
                        selectedTag = tag
                        loadRecordingsForTag(tag)
                    }
                }
            }
        }
    }
    
    private var recordAssignmentStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("第二步：分配记录到新标签")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Text("为每个记录选择要分配到的新标签")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
            }
            
            // 新标签名称输入
            VStack(alignment: .leading, spacing: 12) {
                Text("新标签名称")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                ForEach(0..<newTagNames.count, id: \.self) { index in
                    HStack {
                        TextField("标签 \(index + 1)", text: $newTagNames[index])
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                            )
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        if newTagNames.count > 2 {
                            Button(action: { removeNewTagField(at: index) }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 20))
                            }
                        }
                    }
                }
                
                Button(action: addNewTagField) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("添加标签")
                            .foregroundColor(.blue)
                    }
                    .font(.system(size: 14))
                }
            }
            
            // 记录分配
            if !recordingsWithTag.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("记录分配（\(recordingsWithTag.count) 个记录）")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(recordingsWithTag, id: \.id) { recording in
                            RecordingAssignmentRow(
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
            }
        }
    }
    
    private var bottomButtons: some View {
        VStack(spacing: 12) {
            if currentStep == .selectTag {
                Button(action: proceedToAssignment) {
                    Text("下一步")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedTag.isEmpty ? Color.gray : Color.blue)
                        )
                }
                .disabled(selectedTag.isEmpty)
            } else {
                HStack(spacing: 12) {
                    Button(action: { currentStep = .selectTag }) {
                        Text("上一步")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            )
                    }
                    
                    Button(action: performSplit) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 16))
                            }
                            
                            Text(isProcessing ? "处理中..." : "拆分标签")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(canPerformSplit ? Color.blue : Color.gray)
                        )
                    }
                    .disabled(!canPerformSplit || isProcessing)
                }
            }
            
            Button("取消") {
                isPresented = false
            }
            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
        }
        .padding()
        .background(
            Rectangle()
                .fill(isDarkMode ? Color.black : Color(white: 0.95))
                .ignoresSafeArea(edges: .horizontal)
        )
    }
    
    private var validNewTagNames: [String] {
        newTagNames.compactMap { name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
    
    private var canPerformSplit: Bool {
        !validNewTagNames.isEmpty &&
        recordingTagAssignments.values.allSatisfy { !$0.isEmpty }
    }
    
    private func loadRecordingsForTag(_ tag: String) {
        recordingsWithTag = databaseManager.loadRecordings().filter { recording in
            recording.tags.contains(tag)
        }
        
        recordingTagAssignments.removeAll()
        
        for recording in recordingsWithTag {
            recordingTagAssignments[recording.id] = validNewTagNames.first ?? ""
        }
    }
    
    private func proceedToAssignment() {
        if selectedTag.isEmpty { return }
        
        loadRecordingsForTag(selectedTag)
        currentStep = .assignRecords
    }
    
    private func addNewTagField() {
        newTagNames.append("")
    }
    
    private func removeNewTagField(at index: Int) {
        guard newTagNames.count > 2 && index < newTagNames.count else { return }
        newTagNames.remove(at: index)
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

struct StepIndicatorItem: View {
    let number: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(circleColor)
                    .frame(width: 30, height: 30)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textColor)
                }
            }
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(titleColor)
        }
    }
    
    private var circleColor: Color {
        if isCompleted {
            return .green
        } else if isActive {
            return .blue
        } else {
            return isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
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

struct RecordingAssignmentRow: View {
    let recording: AudioRecording
    let availableTagNames: [String]
    let selectedTag: String
    let isDarkMode: Bool
    let onTagSelected: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .lineLimit(1)
                    
                    Text(recording.transcription.prefix(50) + "...")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        .lineLimit(2)
                }
                
                Spacer()
            }
            
            if !availableTagNames.isEmpty {
                HStack {
                    Text("分配到：")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    
                    Picker("", selection: Binding(
                        get: { selectedTag },
                        set: { onTagSelected($0) }
                    )) {
                        ForEach(availableTagNames, id: \.self) { tagName in
                            Text(tagName)
                                .font(.system(size: 12))
                                .tag(tagName)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .accentColor(isDarkMode ? .white : .black)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}