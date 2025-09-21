//
//  HomeContentListView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 录音卡片列表视图
struct HomeContentListView: View {
    @ObservedObject var viewModel: HomeContentViewModel
    @ObservedObject var audioManager: AudioRecordingService
    let isDarkMode: Bool
    
    @State private var selectedRecording: AudioRecording? = nil
    @State private var cardStates: [String: Bool] = [:] // 记录每个卡片的拖拽状态
    @State private var isNavigating = false
    
    var body: some View {
        if viewModel.filteredRecordings.isEmpty {
            // 空状态视图
            emptyStateView
                .background(navigationLink)
                .onChange(of: isNavigating) { _ in
                    resetSelection()
                }
        } else {
            // 根据筛选类型显示不同内容
            if viewModel.selectedFilter == L("homepage_filter_space") {
                // 显示空间分类网格
                SpaceGridView(isDarkMode: isDarkMode)
            } else {
                // 显示录音列表
                recordingListView
            }
        }
    }
    
    // MARK: - 录音列表视图
    private var recordingListView: some View {
        let scrollContent = ScrollView {
            LazyVStack(spacing: 15) {
                ForEach(viewModel.filteredRecordings, id: \.id) { recording in
                    cardView(for: recording)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .scrollDismissesKeyboard(.immediately)
        
        return scrollContent
            .background(navigationLink)
            .onChange(of: isNavigating) { _ in
                resetSelection()
            }
    }
    
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        EmptyStateView(
            config: .noRecordings,
            isDarkMode: isDarkMode
        )
        .animation(.easeInOut(duration: 0.6), value: viewModel.filteredRecordings.isEmpty)
    }
    
    @ViewBuilder
    private func cardView(for recording: AudioRecording) -> some View {
        HomeContentCardView(
            recording: recording,
            isDarkMode: isDarkMode,
            onDelete: { viewModel.deleteRecording(recording) },
            onDragStateChanged: { isDragging in
                cardStates[recording.id.uuidString] = isDragging
            }
        )
        .onTapGesture {
            handleCardTap(recording: recording)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity
        ))
        .animation(.easeInOut(duration: 0.2), value: viewModel.filteredRecordings.count)
    }
    
    private var navigationLink: some View {
        Group {
            if let recording = selectedRecording {
                NavigationLink(
                    destination: RecordingDetailView(recording: recording, audioManager: audioManager, onRecordingUpdated: viewModel.updateRecording)
                        .navigationBarHidden(true),
                    isActive: $isNavigating
                ) {
                    EmptyView()
                }
                .onChange(of: isNavigating) { navigating in
                    // 当离开 RecordingDetailView 时立即隐藏批量选择浮窗
                    if !navigating {
                        GlobalPopupManager.shared.hideBatchSelectionImmediately()
                    }
                }
                .hidden()
                .navigationViewStyle(StackNavigationViewStyle()) // 确保使用堆栈导航样式
            } else {
                EmptyView()
            }
        }
    }
    
    
    private func handleCardTap(recording: AudioRecording) {
        if cardStates[recording.id.uuidString] != true {
            selectedRecording = recording
            isNavigating = true
        }
    }
    
    private func resetSelection() {
        // 当导航状态变化时，清理选择状态
        if !isNavigating {
            selectedRecording = nil
        }
    }
}

// MARK: - Preview
struct HomeContentListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 浅色模式预览
            PreviewWrapper(isDarkMode: false)
                .previewDisplayName("Light Mode")
            
            // 深色模式预览
            PreviewWrapper(isDarkMode: true)
                .previewDisplayName("Dark Mode")
                .preferredColorScheme(.dark)
            
            // 空列表预览
            PreviewWrapper(isDarkMode: false, isEmpty: true)
                .previewDisplayName("Empty List")
        }
    }
}

// MARK: - Preview Wrapper
private struct PreviewWrapper: View {
    let isDarkMode: Bool
    let isEmpty: Bool
    
    @StateObject private var audioManager: AudioRecordingService
    @StateObject private var viewModel: HomeContentViewModel
    
    init(isDarkMode: Bool, isEmpty: Bool = false) {
        self.isDarkMode = isDarkMode
        self.isEmpty = isEmpty
        
        let manager = AudioRecordingService(skipDatabaseLoad: true)
        self._audioManager = StateObject(wrappedValue: manager)
        self._viewModel = StateObject(wrappedValue: HomeContentViewModel(audioManager: manager))
        
        // 设置示例数据
        if !isEmpty {
            manager.recordings = [
                AudioRecording(
                    timestamp: Date(),
                    duration: 120.5,
                    transcription: "这是一段示例录音的转录内容，包含了语音识别的结果文本。",
                    title: "项目进度汇报会议",
                    summary: "项目进度汇报讨论和下阶段规划",
                    tags: ["会议", "工作", "项目"],
                    audioData: Data(),
                    enrichedContent: "这是丰富化内容的示例"
                ),
                AudioRecording(
                    timestamp: Date().addingTimeInterval(-3600),
                    duration: 45.2,
                    transcription: "另一段录音内容，展示不同类型的语音记录。",
                    title: "个人想法记录",
                    summary: "想法记录和思考总结",
                    tags: ["个人", "笔记"],
                    audioData: Data(),
                    enrichedContent: nil
                ),
                AudioRecording(
                    timestamp: Date().addingTimeInterval(-7200),
                    duration: 89.1,
                    transcription: "第三段录音展示更多样化的内容和标签。",
                    title: "学习知识总结",
                    summary: "知识总结和要点梳理",
                    tags: ["学习", "笔记", "总结"],
                    audioData: Data(),
                    enrichedContent: "详细的学习内容分析"
                )
            ]
        }
    }
    
    var body: some View {
        HomeContentListView(
            viewModel: viewModel,
            audioManager: audioManager,
            isDarkMode: isDarkMode
        )
    }
}
