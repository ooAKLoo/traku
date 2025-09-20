//
//  FullTranscriptionSheet.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 全文转写内容显示视图
struct FullTranscriptionSheet: View {
    let originalText: String
    let polishedText: String?
    let isDarkMode: Bool
    let recordingId: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage: Int = 0
    @State private var contentOffset: CGFloat = 0
    @State private var editedOriginalText: String = ""
    @State private var editedPolishedText: String = ""
    
    var body: some View {
        ZStack {
            // 极简背景
            (isDarkMode ? Color.black : Color(hex: "FAFAFA"))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏 - 极简设计
                HStack {
                    // 关闭按钮 - 圆形设计
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    // 标题 - 细字体
                    Text(L("detail_transcript_full_view"))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        .tracking(0.5)
                    
                    Spacer()
                    
                    // 复制按钮
                    Button(action: copyCurrentText) {
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                if let polishedText = polishedText {
                    // 极简Tab切换器
                    HStack(spacing: 32) {
                        TabButton(
                            title: L("detail_transcript_original"),
                            isSelected: currentPage == 0,
                            isDarkMode: isDarkMode
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage = 0
                            }
                        }
                        
                        // 分隔符
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2))
                            .frame(width: 3, height: 3)
                        
                        TabButton(
                            title: L("detail_transcript_polished"),
                            isSelected: currentPage == 1,
                            isDarkMode: isDarkMode
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage = 1
                            }
                        }
                    }
                    .padding(.vertical, 20)
                    
                    // 内容区域 - 使用TabView
                    TabView(selection: $currentPage) {
                        // 原文页面 - 直接可编辑
                        EditableTextFieldView(
                            text: $editedOriginalText,
                            isDarkMode: isDarkMode,
                            fontStyle: .serif,
                            onSave: { saveEditedContent() }
                        )
                        .tag(0)
                        
                        // 润色版页面 - 直接可编辑
                        EditableTextFieldView(
                            text: $editedPolishedText,
                            isDarkMode: isDarkMode,
                            fontStyle: .default,
                            onSave: { saveEditedContent() }
                        )
                        .tag(1)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    
                } else {
                    // 只有原文时的显示 - 直接可编辑
                    EditableTextFieldView(
                        text: $editedOriginalText,
                        isDarkMode: isDarkMode,
                        fontStyle: .serif,
                        onSave: { saveEditedContent() }
                    )
                }
            }
        }
        .onAppear {
            initializeEditableText()
        }
    }
    
    // 复制当前文本
    private func copyCurrentText() {
        let textToCopy = currentPage == 0 ? editedOriginalText : editedPolishedText
        UIPasteboard.general.string = textToCopy
        
        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // 初始化编辑文本
    private func initializeEditableText() {
        editedOriginalText = originalText
        editedPolishedText = polishedText ?? ""
    }
    
    // 保存编辑内容到数据库
    private func saveEditedContent() {
        Task {
            let success = await updateRecordingInDatabase()
            
            if !success {
                print("保存失败")
            }
        }
    }
    
    // 更新数据库中的录音记录
    @MainActor
    private func updateRecordingInDatabase() async -> Bool {
        guard let recording = DatabaseManager.shared.getRecording(by: recordingId.uuidString) else {
            print("未找到录音记录: \(recordingId.uuidString)")
            return false
        }
        
        // 根据编辑的内容决定更新哪些字段
        let newTranscription: String
        let newPolishedText: String
        
        // 只更新被编辑的内容
        if currentPage == 0 {
            // 编辑的是原文
            newTranscription = editedOriginalText
            newPolishedText = recording.polishedText // 保持润色文本不变
        } else {
            // 编辑的是润色版
            newTranscription = recording.transcription // 保持原文不变
            newPolishedText = editedPolishedText
        }
        
        // 创建更新后的录音记录（因为transcription是let常量，需要创建新实例）
        let updatedRecording = AudioRecording(
            id: recording.id,
            timestamp: recording.timestamp,
            duration: recording.duration,
            transcription: newTranscription,
            title: recording.title,
            summary: recording.summary,
            tags: recording.tags,
            audioData: recording.audioData,
            enrichedContent: recording.enrichedContent,
            polishedText: newPolishedText,
            contentType: recording.contentType,
            weatherType: recording.weatherType,
            weatherLocation: recording.weatherLocation
        )
        
        // 保存到数据库
        let success = DatabaseManager.shared.updateRecording(updatedRecording)
        
        if success {
            // 重要：通知RecordingUpdateManager更新UI
            RecordingUpdateManager.shared.updateRecording(updatedRecording)
            
            let editedContent = currentPage == 0 ? "原文" : "润色版"
            print("✅ \(editedContent)内容更新成功")
        } else {
            print("❌ 转写内容更新失败")
        }
        
        return success
    }
}

// MARK: - 可编辑文本字段视图
struct EditableTextFieldView: View {
    @Binding var text: String
    let isDarkMode: Bool
    var fontStyle: Font.Design = .default
    let onSave: () -> Void
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部留白
                Color.clear.frame(height: 20)
                
                // 可编辑文本区域 - 样式与ContentScrollView一致
                TextField("", text: $text, axis: .vertical)
                    .font(.system(size: 17, weight: .regular, design: fontStyle))
                    .foregroundColor(isDarkMode ? .white.opacity(0.85) : Color(hex: "1A1A1A"))
                    .lineSpacing(10)
                    .tracking(0.2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: text) { _, _ in
                        // 文本变化时自动保存
                        onSave()
                    }
                
                // 底部留白
                Color.clear.frame(height: 100)
            }
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).origin.y
                    )
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
        .overlay(
            // 顶部渐隐遮罩 - 滚动时显示（与ContentScrollView一致）
            VStack {
                if scrollOffset < -10 {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: isDarkMode ? .black : Color(hex: "FAFAFA"), location: 0),
                            .init(color: isDarkMode ? .black.opacity(0) : Color(hex: "FAFAFA").opacity(0), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 30)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: scrollOffset)
        )
    }
}

// MARK: - 内容滚动视图
struct ContentScrollView: View {
    let text: String
    let isDarkMode: Bool
    var fontStyle: Font.Design = .default
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // 顶部留白
                Color.clear.frame(height: 20)
                
                // 文本内容 - 优化排版
                Text(text)
                    .font(.system(size: 17, weight: .regular, design: fontStyle))
                    .foregroundColor(isDarkMode ? .white.opacity(0.85) : Color(hex: "1A1A1A"))
                    .lineSpacing(10)
                    .tracking(0.2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                
                // 底部留白
                Color.clear.frame(height: 100)
            }
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("scroll")).origin.y
                    )
                }
            )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = value
        }
        .overlay(
            // 顶部渐隐遮罩 - 滚动时显示
            VStack {
                if scrollOffset < -10 {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: isDarkMode ? .black : Color(hex: "FAFAFA"), location: 0),
                            .init(color: isDarkMode ? .black.opacity(0) : Color(hex: "FAFAFA").opacity(0), location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 30)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: scrollOffset)
        )
    }
}

// MARK: - ScrollOffset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 极简Tab按钮组件
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(
                        isSelected ?
                        (isDarkMode ? .white : .black) :
                        (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                    )
                    .tracking(0.3)
                
                // 下划线指示器
                Rectangle()
                    .fill(isDarkMode ? .white : .black)
                    .frame(height: isSelected ? 1.5 : 0)
                    .frame(width: 30)
                    .opacity(isSelected ? 1 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            }
        }
    }
}

// MARK: - 预览
struct FullTranscriptionSheet_Previews: PreviewProvider {
    static var previews: some View {
        FullTranscriptionSheet(
            originalText: "这是原始转写内容，包含了一些语气词和不太规范的表达。",
            polishedText: "这是润色后的内容，表达更加清晰规范。",
            isDarkMode: true,
            recordingId: UUID()
        )
    }
}
