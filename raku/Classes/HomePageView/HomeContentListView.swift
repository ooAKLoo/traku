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

    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }

    @State private var selectedRecording: AudioRecording? = nil
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
            // 显示录音列表
            recordingListView
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
            onDelete: { viewModel.deleteRecording(recording) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedRecording = recording
            isNavigating = true
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
            PreviewWrapper()
                .previewDisplayName("Light Mode")
                .environment(\.colorScheme, .light)

            PreviewWrapper()
                .previewDisplayName("Dark Mode")
                .environment(\.colorScheme, .dark)
        }
    }
}

// MARK: - Preview Wrapper
private struct PreviewWrapper: View {
    @StateObject private var audioManager: AudioRecordingService
    @StateObject private var viewModel: HomeContentViewModel

    init() {
        let manager = AudioRecordingService(skipDatabaseLoad: true)
        self._audioManager = StateObject(wrappedValue: manager)
        self._viewModel = StateObject(wrappedValue: HomeContentViewModel(audioManager: manager))

        manager.recordings = [
            AudioRecording(
                timestamp: Date(),
                duration: 120.5,
                transcription: "示例录音内容",
                title: "项目进度汇报会议",
                summary: "项目进度汇报讨论",
                tags: ["会议", "工作"],
                audioData: Data(),
                enrichedContent: nil
            )
        ]
    }

    var body: some View {
        HomeContentListView(
            viewModel: viewModel,
            audioManager: audioManager
        )
    }
}
