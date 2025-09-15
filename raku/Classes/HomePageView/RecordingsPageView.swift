//
//  RecordingsPageView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 录音页面视图
struct RecordingsPageView: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    let isDarkMode: Bool
    @StateObject private var viewModel: RecordingsListViewModel
    
    init(audioManager: AudioManagerAdapter, isDarkMode: Bool) {
        self.audioManager = audioManager
        self.isDarkMode = isDarkMode
        self._viewModel = StateObject(wrappedValue: RecordingsListViewModel(audioManager: audioManager))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 顶部导航栏
                HomepageHeaderView(
                    audioManager: audioManager,
                    isDarkMode: isDarkMode,
                    selectedFilter: $viewModel.selectedFilter,
                    showingSettings: $viewModel.showingSettings,
                    hoveredFilter: $viewModel.hoveredFilter,
                    searchText: $viewModel.searchText,
                    showingConnectionConfig: $viewModel.showingConnectionConfig
                )
                .onChange(of: viewModel.selectedFilter) { newFilter in
                    viewModel.onFilterChanged(newFilter)
                }
                .onChange(of: viewModel.searchText) { newValue in
                    viewModel.onSearchTextChanged(newValue)
                }
                
                // 标签过滤 TabBar（当选择"标签"时显示在 header 下面）
                if viewModel.selectedFilter == L("homepage_filter_tag") {
                    RecordingTagFilter(
                        allRecordings: audioManager.recordings,
                        selectedTag: $viewModel.selectedTag
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // 搜索状态指示器
                if viewModel.isSearching && !viewModel.searchText.isEmpty {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("搜索中...")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    }
                    .padding(.vertical, 8)
                }
                
                // 搜索结果为空时的提示
                if !viewModel.searchText.isEmpty && viewModel.searchResults.isEmpty && !viewModel.isSearching {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                        
                        Text("未找到相关内容")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        
                        if let error = viewModel.searchError {
                            Text(error.localizedDescription)
                                .font(.system(size: 14))
                                .foregroundColor(.red.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                }
                
                // 录音列表
                if !(!viewModel.searchText.isEmpty && viewModel.searchResults.isEmpty && !viewModel.isSearching) {
                    RecordingCardsView(
                        filteredRecordings: viewModel.filteredRecordings,
                        isDarkMode: isDarkMode,
                        selectedFilter: viewModel.selectedFilter,
                        onDelete: viewModel.deleteRecording,
                        audioManager: audioManager,
                        onRecordingUpdated: viewModel.updateRecording
                    )
                }
            }
            
            // 悬浮录音控制卡片
            VStack {
                Spacer()
                FloatingRecordingCard(
                    audioManager: audioManager,
                    selectedFilter: viewModel.selectedFilter,
                    isDarkMode: isDarkMode,
                    showingSpaceTemplateSheet: $viewModel.showingSpaceTemplateSheet
                )
            }
            
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $viewModel.showingConnectionConfig) {
            ConnectionConfigView(audioManager: audioManager)
        }
        .sheet(isPresented: $viewModel.showingSpaceTemplateSheet) {
            SpaceCreationView(
                isPresented: $viewModel.showingSpaceTemplateSheet,
                isDarkMode: isDarkMode,
                onTemplateSelected: { template in
                    viewModel.createSpaceFromTemplate(template)
                },
                onCustomSelected: {
                    // 自定义空间创建逻辑
                }
            )
        }
    }
}