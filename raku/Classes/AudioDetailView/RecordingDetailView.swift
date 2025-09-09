//
//  RecordingDetailView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI
import AVFoundation
import Combine
import MarkdownUI

// MARK: - 录音详情视图
struct RecordingDetailView: View {
    let recording: AudioRecording
    @State private var playProgress: Double = 0
    @State private var isTagEditModalPresented = false
    @State private var editableTags: [String]
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    @StateObject private var audioManager: AudioManagerAdapter
    @State private var headings: [HeadingNode] = []
    @State private var selectedHeadingId: String? = nil
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var isEditingSectionPresented = false
    @State private var editingSectionIndex: Int = 0
    @State private var editingSectionContent: String = ""
    @State private var modifiedEnrichedContent: String = ""
    @State private var currentTranscriptionPage: Int = 0
    @State private var originalTranscription: String = ""
    @State private var polishedTranscription: String = ""
    
    init(recording: AudioRecording) {
        self.recording = recording
        self._audioManager = StateObject(wrappedValue: AudioManagerAdapter())
        self._editableTags = State(initialValue: recording.tags)
    }

    init(recording: AudioRecording, audioManager: AudioManagerAdapter) {
        self.recording = recording
        self._audioManager = StateObject(wrappedValue: audioManager)
        self._editableTags = State(initialValue: recording.tags)
    }
    
    var body: some View {
        ZStack {
            // 极简背景
            (isDarkMode ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏 - 更加精简
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // 播放控件 - 更简洁
                    HStack(spacing: 12) {
                        Button(action: togglePlayback) {
                            HStack(spacing: 8) {
                                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14))
                                    .contentTransition(.symbolEffect(.replace.downUp))
                                Text(FormatHelper.formatDuration(recording.duration))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                            }
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: audioManager.isPlaying)
                        
                        // 下载按钮 - 只在播放时显示
                        if audioManager.isPlaying {
                            Button(action: downloadAudio) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                            }
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: audioManager.isPlaying)
                    
                    Spacer()
                    
                    Menu {
                        Button(action: shareRecording) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        Button(action: exportRecording) {
                            Label("导出", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive, action: deleteRecording) {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                        // 标题区域 - 使用独立组件
                        RecordingDetailTitleView(
                            recording: AudioRecording(
                                timestamp: recording.timestamp,
                                duration: recording.duration,
                                transcription: recording.transcription,
                                title: recording.title,
                                summary: recording.summary,
                                tags: editableTags,
                                audioData: recording.audioData,
                                enrichedContent: recording.enrichedContent
                            ),
                            onTagTap: {
                                isTagEditModalPresented = true
                            }
                        )
                        
                        // 转写文本部分 - 引用样式
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top, spacing: 10) {
                                // 引用符号
                                Text("“")
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundColor(isDarkMode ? Color.white.opacity(0.15) : Color.gray.opacity(0.2))
                                    .offset(y: -11)
                                
                                // 转写内容 - 原文/润色版切换
                                VStack {
                                    TabView(selection: $currentTranscriptionPage) {
                                        // 第一页：原始转写
                                        ScrollView {
                                            Text(originalTranscription)
                                                .font(.system(size: 17, weight: .regular))
                                                .italic()
                                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.6))
                                                .lineSpacing(12)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxHeight: 120) // 约4行高度
                                        .tag(0)
                                        
                                        // 第二页：润色版本
                                        ScrollView {
                                            Text(polishedTranscription)
                                                .font(.system(size: 17, weight: .regular))
                                                .italic()
                                                .foregroundColor(isDarkMode ? .white.opacity(0.65) : .gray.opacity(0.75))
                                                .lineSpacing(12)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxHeight: 120) // 约4行高度
                                        .tag(1)
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 120)
                                }
                            }
                            .padding(.horizontal, 18)
                            
                            // 条形分页指示器 - 原文/润色版
                            HStack(spacing: 8) {
                                // 原文指示器
                                HStack(spacing: 4) {
                                    Capsule()
                                        .fill(currentTranscriptionPage == 0 ? 
                                              (isDarkMode ? Color.white.opacity(0.8) : Color.black.opacity(0.8)) :
                                              (isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2)))
                                        .frame(width: currentTranscriptionPage == 0 ? 20 : 6, height: 4)
                                        .animation(.easeInOut(duration: 0.3), value: currentTranscriptionPage)
                                    
                                    Text("原文")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(currentTranscriptionPage == 0 ? 
                                                        (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)) :
                                                        (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                                        .animation(.easeInOut(duration: 0.3), value: currentTranscriptionPage)
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentTranscriptionPage = 0
                                    }
                                }
                                
                                // 润色版指示器  
                                HStack(spacing: 4) {
                                    Capsule()
                                        .fill(currentTranscriptionPage == 1 ? 
                                              (isDarkMode ? Color.white.opacity(0.8) : Color.black.opacity(0.8)) :
                                              (isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2)))
                                        .frame(width: currentTranscriptionPage == 1 ? 20 : 6, height: 4)
                                        .animation(.easeInOut(duration: 0.3), value: currentTranscriptionPage)
                                    
                                    Text("润色版")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(currentTranscriptionPage == 1 ? 
                                                        (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)) :
                                                        (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                                        .animation(.easeInOut(duration: 0.3), value: currentTranscriptionPage)
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentTranscriptionPage = 1
                                    }
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 12)
                        }
                        .padding(.bottom, 35)
                        
                        // AI总结部分 - 黑体强调，无标题
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // 增强内容 - 使用分段Markdown渲染
                            if let enrichedContent = recording.enrichedContent, !enrichedContent.isEmpty {
                                MarkdownSectionView(
                                    content: modifiedEnrichedContent.isEmpty ? enrichedContent : modifiedEnrichedContent,
                                    headings: headings,
                                    selectedHeadingId: $selectedHeadingId,
                                    scrollProxy: scrollProxy,
                                    onEditSection: { index, content in
                                        editingSectionIndex = index
                                        editingSectionContent = content
                                        isEditingSectionPresented = true
                                    },
                                    onDeleteSection: { index in
                                        deleteSection(at: index)
                                    }
                                )
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                            }
                        }
                        
                        // 底部留白（为章节标签栏预留空间）
                        Color.clear.frame(height: headings.isEmpty ? 60 : 100)
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
            }
            
            // 底部浮动章节标签栏
            if !headings.isEmpty {
                VStack {
                    Spacer()
                    ChapterTabBar(
                        headings: headings,
                        selectedHeadingId: $selectedHeadingId,
                        onHeadingSelected: { index in
                            // 跳转到对应章节
                            withAnimation(.easeInOut(duration: 0.4)) {
                                scrollProxy?.scrollTo("section_\(index)", anchor: .top)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                    .background(
                        (isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                            .mask(
                                // 上边沿渐变虚化
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .black, location: 0.3),
                                        .init(color: .black, location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .ignoresSafeArea(edges: .bottom)
                    )
                    .offset(y:20)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: headings.count)
            }
        }
        .onAppear {
            // 初始化转写文本内容
            setupTranscriptionContent()
            
            if let enrichedContent = recording.enrichedContent, !enrichedContent.isEmpty {
                // 初始化修改后的内容
                modifiedEnrichedContent = enrichedContent
                
                let headingTree = MarkdownHeadingParser.parseHeadings(from: enrichedContent)
                
                // 更新标题列表
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.headings = headingTree.flatList
                    // 默认选中第一个标题
                    if !headingTree.flatList.isEmpty {
                        self.selectedHeadingId = "0"
                    }
                }
                
                // 打印调试信息
                print("=== 标题层级结构 ===")
                print("目录结构:")
                print(headingTree.getTableOfContents())
                print("\n层级映射:")
                for heading in headingTree.flatList {
                    print("- '\(heading.text)': 原始\(heading.originalLevel)级 → 正则化\(heading.normalizedLevel)级")
                }
                print("==================")
            }
        }
        .sheet(isPresented: $isTagEditModalPresented) {
            TagEditModal(
                isPresented: $isTagEditModalPresented,
                tags: $editableTags
            )
        }
        .sheet(isPresented: $isEditingSectionPresented) {
            SectionEditModal(
                isPresented: $isEditingSectionPresented,
                sectionContent: editingSectionContent,
                sectionIndex: editingSectionIndex,
                onSave: { index, newContent in
                    updateSection(at: index, with: newContent)
                }
            )
        }
    }
    
    // 辅助函数
    
    private func extractTitle(from summary: String) -> String {
        // 从总结中提取第一句作为标题
        let sentences = summary.components(separatedBy: CharacterSet(charactersIn: "。！？"))
        if let firstSentence = sentences.first, !firstSentence.isEmpty {
            // 限制标题长度
            if firstSentence.count > 30 {
                return String(firstSentence.prefix(30)) + "..."
            }
            return firstSentence
        }
        return "录音记录"
    }
    
    func shareRecording() {
        // 实现分享功能
        let text = """
        \(extractTitle(from: recording.summary))
        
        转写内容：
        \(recording.transcription)
        
        总结：
        \(recording.summary)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func exportRecording() {
        // 实现导出功能
        copySummary()
    }
    
    func deleteRecording() {
        // 实现删除功能
        dismiss()
    }
    
    func downloadAudio() {
        guard let audioData = recording.audioData else {
            print("没有音频数据可供下载")
            showErrorAlert(message: "没有可用的音频数据")
            return
        }
        
        // 验证是否为模拟数据
        if MockDataService.shared.isMockAudioData(audioData) {
            print("检测到模拟音频数据，无法下载")
            showErrorAlert(message: MockDataService.shared.demoModeMessage + "，无法下载音频")
            return
        }
        
        // 检查是否已经是WAV格式（WAV文件以"RIFF"开头）
        let wavHeaderBytes = [UInt8](audioData.prefix(4))
        let isWAV = wavHeaderBytes == [0x52, 0x49, 0x46, 0x46] // "RIFF"的ASCII值
        
        // 如果不是WAV格式，说明数据可能有问题
        if !isWAV {
            print("音频数据格式无效，不是有效的WAV文件")
            showErrorAlert(message: "音频数据格式无效")
            return
        }
        
        // 验证音频数据大小（WAV文件头至少44字节）
        if audioData.count < 44 {
            print("音频数据太小，无效的WAV文件: \(audioData.count) bytes")
            showErrorAlert(message: "音频数据无效")
            return
        }
        
        // 生成安全的文件名
        let title = extractTitle(from: recording.summary)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
        let fileName = "\(title)_\(recording.timestamp.fileFormatted).wav"
        
        // 使用临时目录避免权限问题
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            // 直接写入WAV数据（数据已经是WAV格式）
            try audioData.write(to: fileURL)
            print("音频文件已保存到: \(fileURL)")
            print("文件大小: \(audioData.count) bytes")
            
            // 创建分享界面
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            // 设置完成回调，清理临时文件
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("临时文件已清理")
                } catch {
                    print("清理临时文件失败: \(error)")
                }
            }
            
            // 展示分享界面
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                // iPad需要设置popover
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("保存音频文件失败: \(error)")
            showErrorAlert(message: "保存音频文件失败: \(error.localizedDescription)")
        }
    }
    
    func copySummary() {
        let fullContent = """
        \(recording.transcription)
        
        ---
        
        \(recording.summary)
        """
        UIPasteboard.general.string = fullContent
    }
    
    func togglePlayback() {
        if audioManager.isPlaying {
            audioManager.stopPlaying()
        } else {
            if let audioData = recording.audioData {
                if MockDataService.shared.isMockAudioData(audioData) {
                    showMockDataAlert()
                } else {
                    audioManager.playRecording(recording)
                }
            }
        }
    }
    
    private func showMockDataAlert() {
        // 模拟播放状态，3秒后自动停止
        audioManager.isPlaying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            audioManager.isPlaying = false
        }
    }
    
    
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "提示",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
    
    // MARK: - 段落编辑功能
    private func updateSection(at index: Int, with newContent: String) {
        guard !modifiedEnrichedContent.isEmpty else { return }
        
        // 解析当前内容的段落
        let parser = MarkdownSectionParser(content: modifiedEnrichedContent)
        var sections = parser.parseSections()
        
        // 更新指定段落
        guard index < sections.count else { return }
        sections[index] = newContent
        
        // 重新组合内容
        modifiedEnrichedContent = sections.joined(separator: "\n\n")
        
        // 更新数据库
        saveModifiedContent()
        
        // 重新解析标题
        updateHeadings()
        
        // 显示成功提示
        ToastManager.shared.showSuccess("段落已更新")
    }
    
    private func deleteSection(at index: Int) {
        guard !modifiedEnrichedContent.isEmpty else { return }
        
        // 解析当前内容的段落
        let parser = MarkdownSectionParser(content: modifiedEnrichedContent)
        var sections = parser.parseSections()
        
        // 删除指定段落
        guard index < sections.count else { return }
        sections.remove(at: index)
        
        // 重新组合内容
        modifiedEnrichedContent = sections.joined(separator: "\n\n")
        
        // 更新数据库
        saveModifiedContent()
        
        // 重新解析标题
        updateHeadings()
        
        // 显示成功提示
        ToastManager.shared.showSuccess("段落已删除")
    }
    
    private func saveModifiedContent() {
        // 更新录音记录的增强内容
        var updatedRecording = recording
        updatedRecording.enrichedContent = modifiedEnrichedContent
        
        // 保存到数据库
        DatabaseManager.shared.updateRecording(updatedRecording)
    }
    
    private func updateHeadings() {
        let headingTree = MarkdownHeadingParser.parseHeadings(from: modifiedEnrichedContent)
        withAnimation(.easeInOut(duration: 0.3)) {
            self.headings = headingTree.flatList
        }
    }
    
    // 设置转写文本内容
    private func setupTranscriptionContent() {
        // 原始转写内容
        originalTranscription = recording.transcription
        
        // 润色版本（暂时使用相同内容，后续可接入AI服务）
        polishedTranscription = recording.transcription
    }
    
}

// MARK: - Markdown段落解析器
private class MarkdownSectionParser {
    let content: String
    
    init(content: String) {
        self.content = content
    }
    
    func parseSections() -> [String] {
        var sections: [String] = []
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        var currentSection: [String] = []
        
        for line in lines {
            // 检查是否是标题行（新段落开始）
            if isHeadingLine(line) && !currentSection.isEmpty {
                // 保存当前段落
                sections.append(currentSection.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
                currentSection = [line]
            } else {
                currentSection.append(line)
            }
        }
        
        // 保存最后一个段落
        if !currentSection.isEmpty {
            let sectionContent = currentSection.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !sectionContent.isEmpty {
                sections.append(sectionContent)
            }
        }
        
        return sections
    }
    
    private func isHeadingLine(_ line: String) -> Bool {
        let pattern = "^#{1,6}\\s+.+$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        let range = NSRange(location: 0, length: line.utf16.count)
        return regex.firstMatch(in: line, options: [], range: range) != nil
    }
}

// MARK: - 预览
struct RecordingDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingDetailView(
            recording: AudioRecording(
                timestamp: Date(),
                duration: 185,
                transcription: "嗯，这个，就是一段会议录音的转写内容，讨论了关于新产品开发的进度和计划。我觉得我们需要在下个季度完成主要功能的开发，并准备进行用户测试。那个产品的核心功能包括用户界面设计、后端API开发、数据库优化等多个方面。然后团队决定采用敏捷开发模式，确保项目能够按时交付。其实我们也需要考虑用户体验的优化，包括界面的友好性和功能的易用性。在技术选型方面，我们应该使用最新的开发框架和工具，以确保产品的技术先进性和稳定性。",
                title: "产品开发会议总结",
                summary: "确定了Q2的开发目标，包括核心功能完成、用户界面优化和测试计划制定。团队将采用敏捷开发方法，每两周进行一次迭代评审。",
                tags: ["会议", "产品", "开发"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: """
                ## 明确目标
                > 3个月内完成1个科技艺术项目原型，实现AI生成艺术作品并线下展览
                
                ## 行动清单
                - [ ] **优先级高**：调研科技艺术趋势与用户需求
                - [ ] **优先级高**：确定技术实现方案与艺术形式
                - [ ] **优先级中**：收集艺术素材与训练数据
                - [ ] **优先级低**：寻找技术与艺术合作资源
                
                ## 📦 所需资源
                | 资源类型 | 具体内容 |
                |---------|---------|
                | 时间 | 调研1周，方案设计1周，素材收集2周，技术开发4周，展览筹备2周 |
                | 工具 | AI工具（Midjourney/Stable Diffusion）、设计软件（PS/Blender）、项目管理工具（Trello） |
                | 支持 | 技术伙伴、艺术指导、线下展览场地资源 |
                
                ## 时间规划
                **短期（1周内）**：每日2小时调研科技艺术案例，周末输出趋势报告与用户需求分析
                **中期（1月内）**：前2周完成技术方案设计（含AI模型选型），后2周收集艺术素材与训练数据
                **长期（3月内）**：第3-6周开发AI生成模型并测试优化，第7-8周筹备线下展览（布展/宣传）
                
                ## 潜在挑战
                1. **挑战**：AI生成艺术效果未达预期 → **应对**：先小范围测试不同模型，参考艺术指导调整参数
                2. **挑战**：缺乏技术/艺术合作资源 → **应对**：在艺术社群/高校发布招募信息，优先合作学生团队降低成本
                """
            ),
            audioManager: AudioManagerAdapter(skipDatabaseLoad: true)
        )
    }
}
