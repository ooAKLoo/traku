//
//  HomepageMainView.swift
//  raku
//
//  首页主视图 - 合并了原ContentView和RecordingsPageView
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 首页主视图
struct HomepageMainView: View {
    @ObservedObject private var audioManager = AudioRecordingService.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var viewModel = HomeContentViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 极简背景
                (isDarkMode ? Color.black : Color.appBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部导航栏
                    HomepageHeaderView(
                        audioManager: audioManager,
                        isDarkMode: isDarkMode,
                        searchText: $viewModel.searchText,
                        showingSidebar: $viewModel.showingSidebar
                    )
                    .onChange(of: viewModel.searchText) { newValue in
                        viewModel.onSearchTextChanged(newValue)
                    }

                    // 标签过滤 TabBar
                    RecordingTagFilter(
                        allRecordings: viewModel.allRecordings,
                        selectedTag: $viewModel.selectedTag
                    )

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
                        HomeContentListView(viewModel: viewModel)
                    }
                }
                
                // 悬浮录音控制卡片
                VStack {
                    Spacer()
                    FloatingRecordingCard(
                        audioManager: audioManager,
                        isDarkMode: isDarkMode
                    )
                }
            }
            .sheet(isPresented: $viewModel.showingSettings) {
                SettingsView()
            }
            .overlay {
                // 侧边栏
                HomeSidebarView(
                    audioManager: audioManager,
                    isPresented: $viewModel.showingSidebar,
                    showingSettings: $viewModel.showingSettings,
                    isDarkMode: isDarkMode
                )
                .animation(.easeInOut(duration: 0.3), value: viewModel.showingSidebar)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .toastContainer()
    }
}

// MARK: - Preview
struct HomepageMainView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HomepageMainView()
                .environment(\.colorScheme, .light)
                .previewDisplayName("Light Mode")

            HomepageMainView()
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Dark Mode")
        }
    }
}