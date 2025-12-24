//
//  RecordingDetailTitleView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

struct RecordingDetailTitleView: View {
    @State private var recording: AudioRecording
    let onTagTap: () -> Void
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var editedTitle: String
    @FocusState var isTitleFieldFocused: Bool
    let onTitleChanged: ((String) -> Void)?
    @ObservedObject private var store = RecordingStore.shared
    
    init(recording: AudioRecording, onTagTap: @escaping () -> Void, onTitleChanged: ((String) -> Void)? = nil) {
        self._recording = State(initialValue: recording)
        self.onTagTap = onTagTap
        self.onTitleChanged = onTitleChanged
        self._editedTitle = State(initialValue: recording.title)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            TextField("标题", text: $editedTitle, axis: .vertical)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.95))
                .lineLimit(2)
                .focused($isTitleFieldFocused)
                .onTapGesture {
                    isTitleFieldFocused = true
                }
                .onChange(of: isTitleFieldFocused) { focused in
                    if !focused && editedTitle != recording.title {
                        saveTitleChange()
                    }
                }
            
            // 时间和标签在同一行
            HStack(spacing: 16) {
                // 时间 - 固定宽度，优先显示
                Text(recording.timestamp.smartFormatted)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                    .frame(minWidth: 80, alignment: .leading)
                    .layoutPriority(1)
                
                // 标签 - 占据剩余宽度
                if !recording.tags.isEmpty {
                    Button(action: onTagTap) {
                        HStack(spacing: 6) {
                            ForEach(recording.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(isDarkMode ? Color.gray.opacity(0.2) : Color.gray.opacity(0.15))
                                    )
                            }
                            
                            // 如果标签超过3个，显示省略指示
                            if recording.tags.count > 3 {
                                Text("...")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                                    .padding(.horizontal, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    // 没有标签时显示添加按钮
                    Button(action: onTagTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 12))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                            
                            Text("添加标签")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 40)
        .onReceive(store.$recordings) { recordings in
            if let updatedRecording = recordings.first(where: { $0.id == recording.id }) {
                // 只有在用户没有在编辑标题时才更新标题
                if !isTitleFieldFocused && updatedRecording.title != recording.title {
                    recording = updatedRecording
                    editedTitle = updatedRecording.title
                } else {
                    // 更新其他字段，但保持当前编辑的标题
                    var tempRecording = updatedRecording
                    tempRecording.title = recording.title
                    recording = tempRecording
                }
            }
        }
    }
    
    private func saveTitleChange() {
        print("🔄 RecordingDetailTitleView: 开始保存标题更改")
        print("🔄 原标题: '\(recording.title)'")
        print("🔄 新标题: '\(editedTitle)'")
        print("🔄 录音ID: \(recording.id)")
        
        var updatedRecording = recording
        updatedRecording.title = editedTitle
        
        let success = DatabaseManager.shared.updateRecording(updatedRecording)
        print("🔄 数据库更新结果: \(success)")
        
        if success {
            onTitleChanged?(editedTitle)
            print("🔄 已通知父组件标题更改")
        } else {
            print("❌ 数据库更新失败")
        }
    }
}

// MARK: - 预览
struct RecordingDetailTitleView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingDetailTitleView(
            recording: AudioRecording(
                timestamp: Date(),
                duration: 185,
                transcription: "这是一段会议录音的转写内容",
                title: "产品开发会议总结",
                summary: "确定了Q2的开发目标，包括核心功能完成、用户界面优化和测试计划制定。",
                tags: ["会议", "产品", "开发"],
                audioData: nil,
                enrichedContent: nil
            ),
            onTagTap: {}
        )
        .background(Color.black)
    }
}
