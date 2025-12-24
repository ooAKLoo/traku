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
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var viewModel: RecordingDetailViewModel
    @State private var scrollProxy: ScrollViewProxy? = nil
    @FocusState private var isAnyFieldFocused: Bool
    @State private var copyButtonShowsCheckmark = false
    
    init(recording: AudioRecording, audioManager: AudioRecordingService = AudioRecordingService.shared, onRecordingUpdated: ((AudioRecording) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: RecordingDetailViewModel(
            recording: recording,
            audioManager: audioManager,
            onRecordingUpdated: onRecordingUpdated
        ))
    }
    var body: some View {
        ZStack {
            // 极简背景
            (isDarkMode ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏 - 使用独立组件
                RecordingDetailNavigationBar(
                    audioManager: viewModel.audioManager,
                    recording: viewModel.recording,
                    isDarkMode: isDarkMode,
                    onDismiss: { 
                        viewModel.onDismiss = { dismiss() }
                        viewModel.deleteRecording()
                    },
                    onShare: viewModel.shareRecording,
                    onExport: viewModel.exportRecording,
                    onDelete: viewModel.deleteRecording,
                    onTogglePlayback: viewModel.togglePlayback,
                    onDownload: viewModel.downloadAudio
                )
                
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 标题区域 - 使用独立组件
                            RecordingDetailTitleView(
                                recording: viewModel.recording,
                                onTagTap: {
                                    isAnyFieldFocused = false
                                    viewModel.isTagEditModalPresented = true
                                },
                                onTitleChanged: viewModel.updateTitle
                            )
                            .focused($isAnyFieldFocused)
                            
                            // 转写文本部分 - 引用样式
                            VStack(alignment: .leading, spacing: 20) {
                                HStack(alignment: .top, spacing: 10) {
                                    // 引用符号
                                    Text("“")
                                        .font(.system(size: 48, weight: .semibold))
                                        .foregroundColor(isDarkMode ? Color.white.opacity(0.15) : Color.gray.opacity(0.2))
                                        .offset(y: -11)
                                    
                                    // 转写内容容器
                                    VStack(alignment: .leading, spacing: 12) {
                                        if viewModel.hasPolishedText {
                                            // 使用始终存在的视图和位移动画
                                            ZStack {
                                                // 原始转写
                                                AdaptiveTextView(
                                                    text: viewModel.originalTranscription,
                                                    maxLines: 4,
                                                    font: .system(size: 17, weight: .regular),
                                                    lineSpacing: 12
                                                )
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .offset(x: viewModel.currentTranscriptionPage == 0 ? 0 : -UIScreen.main.bounds.width)
                                                .opacity(viewModel.currentTranscriptionPage == 0 ? 1 : 0)
                                                
                                                // 润色版本
                                                AdaptiveTextView(
                                                    text: viewModel.polishedTranscription,
                                                    maxLines: 4,
                                                    font: .system(size: 17, weight: .regular),
                                                    lineSpacing: 12
                                                )
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .offset(x: viewModel.currentTranscriptionPage == 1 ? 0 : UIScreen.main.bounds.width)
                                                .opacity(viewModel.currentTranscriptionPage == 1 ? 1 : 0)
                                            }
                                            .clipped()
                                            .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscriptionPage)
                                        } else {
                                            // 无润色文本时直接显示原始转写
                                            AdaptiveTextView(
                                                text: viewModel.originalTranscription,
                                                maxLines: 4,
                                                font: .system(size: 17, weight: .regular),
                                                lineSpacing: 12
                                            )
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .italic()
                                    .foregroundColor(viewModel.currentTranscriptionPage == 0 ?
                                                    (isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.6)) :
                                                    (isDarkMode ? .white.opacity(0.65) : .gray.opacity(0.75)))
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscriptionPage)
                                }
                                .padding(.horizontal, 18)
                                .contentShape(Rectangle())
                                .simultaneousGesture(
                                    // 组合手势：同时支持点击和滑动
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            // 不做任何处理，只是为了捕获手势开始
                                        }
                                        .onEnded { value in
                                            let horizontalDrag = abs(value.translation.width)
                                            let verticalDrag = abs(value.translation.height)
                                            
                                            // 如果是明显的水平滑动且有润色文本
                                            if horizontalDrag > 50 && horizontalDrag > verticalDrag && viewModel.hasPolishedText {
                                                isAnyFieldFocused = false
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    if value.translation.width > 0 {
                                                        // 向右滑动，切换到原文
                                                        viewModel.currentTranscriptionPage = 0
                                                    } else {
                                                        // 向左滑动，切换到润色版
                                                        viewModel.currentTranscriptionPage = 1
                                                    }
                                                }
                                            } else if horizontalDrag < 10 && verticalDrag < 10 {
                                                // 如果是轻微移动，视为点击
                                                isAnyFieldFocused = false
                                                viewModel.showingFullTranscription = true
                                            }
                                        }
                                )
                                
                                // 条形分页指示器 - 仅在有润色版时显示
                                if viewModel.hasPolishedText {
                                    HStack(spacing: 8) {
                                        // 原文指示器
                                        HStack(spacing: 4) {
                                            Capsule()
                                                .fill(viewModel.currentTranscriptionPage == 0 ?
                                                      (isDarkMode ? Color.white.opacity(0.8) : Color.black.opacity(0.8)) :
                                                      (isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2)))
                                                .frame(width: viewModel.currentTranscriptionPage == 0 ? 20 : 6, height: 4)
                                                .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscriptionPage)
                                            
                                            Text(L("detail_transcript_original"))
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(viewModel.currentTranscriptionPage == 0 ?
                                                                (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)) :
                                                                (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                                                .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscriptionPage)
                                        }
                                        .onTapGesture {
                                            isAnyFieldFocused = false
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                viewModel.currentTranscriptionPage = 0
                                            }
                                        }
                                        
                                        // 润色版指示器
                                        HStack(spacing: 4) {
                                            Capsule()
                                                .fill(viewModel.currentTranscriptionPage == 1 ?
                                                      (isDarkMode ? Color.white.opacity(0.8) : Color.black.opacity(0.8)) :
                                                      (isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2)))
                                                .frame(width: viewModel.currentTranscriptionPage == 1 ? 20 : 6, height: 4)
                                                .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscriptionPage)
                                            
                                            Text(L("detail_transcript_polished"))
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(viewModel.currentTranscriptionPage == 1 ?
                                                                (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)) :
                                                                (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                                                .animation(.easeInOut(duration: 0.3), value: viewModel.currentTranscriptionPage)
                                        }
                                        .onTapGesture {
                                            isAnyFieldFocused = false
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                viewModel.currentTranscriptionPage = 1
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 28)
                                    .padding(.top, 12)
                                }
                            }
                            .padding(.bottom, 35)
                            
                            // 内容部分 - 根据类型显示不同内容
                            VStack(alignment: .leading, spacing: 24) {
                                
                                if viewModel.recording.contentType == "inspiration" {
                                    // 灵感类型：显示相似的其他条目
                                    SimilarInspirationView(
                                        currentRecording: viewModel.recording,
                                        isDarkMode: isDarkMode,
                                        audioManager: viewModel.audioManager,
                                        onRecordingUpdated: viewModel.onRecordingUpdated
                                    )
                                    .padding(.horizontal, 24)
                                    .padding(.top, 12)
                                } else {
                                    // 思考类型：显示AI总结
                                    if let enrichedContent = viewModel.recording.enrichedContent, !enrichedContent.isEmpty {
                                        VStack() {
                                            // AI总结内容
                                            MarkdownSectionView(
                                                content: viewModel.modifiedEnrichedContent.isEmpty ? enrichedContent : viewModel.modifiedEnrichedContent,
                                                headings: viewModel.headings,
                                                selectedHeadingId: $viewModel.selectedHeadingId,
                                                scrollProxy: scrollProxy,
                                                onEditSection: { index, content in
                                                    isAnyFieldFocused = false
                                                    viewModel.editSection(at: index, content: content)
                                                },
                                                onDeleteSection: { index in
                                                    isAnyFieldFocused = false
                                                    viewModel.deleteSection(at: index)
                                                }
                                            )
                                            .padding(.horizontal, 24)
                                            .padding(.top, 12)
                                            
                                            // 复制按钮 - 右下角
                                            HStack {
                                                Spacer()
                                                Button(action: {
                                                    // 显示对勾状态
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        copyButtonShowsCheckmark = true
                                                    }
                                                    
                                                    // 获取当前显示的 markdown 内容
                                                    let textToCopy = viewModel.modifiedEnrichedContent.isEmpty 
                                                        ? (viewModel.recording.enrichedContent ?? "")
                                                        : viewModel.modifiedEnrichedContent
                                                    
                                                    // 复制到剪贴板
                                                    UIPasteboard.general.string = textToCopy
                                                    
                                                    // 触觉反馈
                                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                    impactFeedback.impactOccurred()
                                                    
                                                    // 1秒后恢复复制图标
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                        withAnimation(.easeInOut(duration: 0.2)) {
                                                            copyButtonShowsCheckmark = false
                                                        }
                                                    }
                                                }) {
                                                    Image(systemName: copyButtonShowsCheckmark ? "checkmark" : "doc.on.doc")
                                                        .font(.system(size: 16, weight: .medium))
                                                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                                                        .frame(width: 32, height: 32)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                                        )
                                                        .animation(.easeInOut(duration: 0.2), value: copyButtonShowsCheckmark)
                                                        .contentShape(RoundedRectangle(cornerRadius: 8))
                                                }
                                                .frame(width: 40, height: 40)
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                            .padding(.horizontal, 24)
                                            .padding(.bottom, 16)
                                        }
                                    }
                                }
                            }
                            
                            // 底部留白（为章节标签栏预留空间）
                            Color.clear.frame(height: viewModel.headings.isEmpty ? 60 : 100)
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { _ in
                                isAnyFieldFocused = false
                            }
                    )
                }
            }
            
            // 底部浮动章节标签栏
            if !viewModel.headings.isEmpty {
                VStack {
                    Spacer()
                    ChapterTabBar(
                        headings: viewModel.headings,
                        selectedHeadingId: $viewModel.selectedHeadingId,
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
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.headings.count)
            }
        }
        .offset(x: viewModel.isPresented ? 0 : UIScreen.main.bounds.width)
        .animation(.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0.3), value: viewModel.isPresented)
        .onAppear {
            // 添加小延迟以确保视图完全准备好再触发动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                viewModel.onViewAppear()
            }
        }
        .sheet(isPresented: $viewModel.isTagEditModalPresented) {
            TagEditModal(
                isPresented: $viewModel.isTagEditModalPresented,
                tags: $viewModel.editableTags,
                recording: viewModel.recording,
                audioManager: viewModel.audioManager
            )
        }
        .sheet(isPresented: $viewModel.isEditingSectionPresented) {
            SectionEditModal(
                isPresented: $viewModel.isEditingSectionPresented,
                sectionContent: viewModel.editingSectionContent,
                sectionIndex: viewModel.editingSectionIndex,
                onSave: viewModel.updateSection
            )
        }
        .sheet(isPresented: $viewModel.showingFullTranscription) {
            FullTranscriptionSheet(
                originalText: viewModel.originalTranscription,
                polishedText: viewModel.hasPolishedText ? viewModel.polishedTranscription : nil,
                isDarkMode: isDarkMode,
                recordingId: viewModel.recording.id
            )
        }
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
                """,
                polishedText: "这是一段会议录音的转写内容，讨论了关于新产品开发的进度和计划。我们需要在下个季度完成主要功能的开发，并准备进行用户测试。产品的核心功能包括用户界面设计、后端API开发、数据库优化等多个方面。团队决定采用敏捷开发模式，确保项目能够按时交付。我们也需要考虑用户体验的优化，包括界面的友好性和功能的易用性。在技术选型方面，我们应该使用最新的开发框架和工具，以确保产品的技术先进性和稳定性。"
            ),
            audioManager: AudioRecordingService(skipDatabaseLoad: true)
        )
    }
}
