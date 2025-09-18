//
//  HomeContentListView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 录音卡片列表视图
struct HomeContentListView: View {
    let filteredRecordings: [AudioRecording]
    let isDarkMode: Bool
    let selectedFilter: String  // 新增：当前选择的筛选类型
    let onDelete: (AudioRecording) -> Void
    let audioManager: AudioRecordingService
    let onRecordingUpdated: ((AudioRecording) -> Void)?
    
    @State private var selectedRecording: AudioRecording? = nil
    @State private var cardStates: [String: Bool] = [:] // 记录每个卡片的拖拽状态
    @State private var isNavigating = false
    
    var body: some View {
        if filteredRecordings.isEmpty {
            // 空状态视图
            emptyStateView
                .background(navigationLink)
                .onChange(of: isNavigating) { _ in
                    resetSelection()
                }
        } else {
            // 根据筛选类型显示不同内容
            if selectedFilter == L("homepage_filter_space") {
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
                ForEach(filteredRecordings, id: \.id) { recording in
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
        .animation(.easeInOut(duration: 0.6), value: filteredRecordings.isEmpty)
    }
    
    @ViewBuilder
    private func cardView(for recording: AudioRecording) -> some View {
        RightSideWeatherCardView(
            recording: recording,
            isDarkMode: isDarkMode,
            onDelete: { onDelete(recording) },
//            onDragStateChanged: { isDragging in
//                cardStates[recording.id.uuidString] = isDragging
//            }
        )
        .onTapGesture {
            handleCardTap(recording: recording)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity
        ))
        .animation(.easeInOut(duration: 0.2), value: filteredRecordings.count)
    }
    
    private var navigationLink: some View {
        Group {
            if let recording = selectedRecording {
                NavigationLink(
                    destination: RecordingDetailView(recording: recording, audioManager: audioManager, onRecordingUpdated: onRecordingUpdated)
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
        let sampleRecordings = [
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
        
        Group {
            // 浅色模式预览
            HomeContentListView(
                filteredRecordings: sampleRecordings,
                isDarkMode: false,
                selectedFilter: "标签",
                onDelete: { _ in print("Delete recording") },
                audioManager: AudioRecordingService(skipDatabaseLoad: true),
                onRecordingUpdated: nil
            )
            .previewDisplayName("Light Mode")
            
            // 深色模式预览
            HomeContentListView(
                filteredRecordings: sampleRecordings,
                isDarkMode: true,
                selectedFilter: "标签",
                onDelete: { _ in print("Delete recording") },
                audioManager: AudioRecordingService(skipDatabaseLoad: true),
                onRecordingUpdated: nil
            )
            .previewDisplayName("Dark Mode")
            .preferredColorScheme(.dark)
            
            // 空间主题预览
            HomeContentListView(
                filteredRecordings: sampleRecordings,
                isDarkMode: true,
                selectedFilter: L("homepage_filter_space"),
                onDelete: { _ in print("Delete recording") },
                audioManager: AudioRecordingService(skipDatabaseLoad: true),
                onRecordingUpdated: nil
            )
            .previewDisplayName("Space Theme")
            .preferredColorScheme(.dark)
            
            // 空列表预览
            HomeContentListView(
                filteredRecordings: [],
                isDarkMode: false,
                selectedFilter: "标签",
                onDelete: { _ in print("Delete recording") },
                audioManager: AudioRecordingService(skipDatabaseLoad: true),
                onRecordingUpdated: nil
            )
            .previewDisplayName("Empty List")
        }
    }
}
