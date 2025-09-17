//
//  RecordingsListViewModel.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import Foundation
import Combine

@MainActor
class RecordingsListViewModel: ObservableObject {
    @Published var selectedFilter = L("homepage_filter_tag")
    @Published var showingSettings = false
    @Published var hoveredFilter: String? = nil
    @Published var searchText = ""
    @Published var showingConnectionConfig = false
    @Published var selectedTag: String? = nil
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var searchError: SearchError?
    @Published var showingSpaceTemplateSheet = false
    
    private let audioManager: AudioRecordingService
    
    init(audioManager: AudioRecordingService) {
        self.audioManager = audioManager
    }
    
    var filteredRecordings: [AudioRecording] {
        var recordings: [AudioRecording]
        
        // 如果有搜索结果，优先显示搜索结果
        if !searchText.isEmpty && !searchResults.isEmpty {
            recordings = searchResults.compactMap { $0.recording }
        } else {
            // 现在可以安全访问，因为都在MainActor中
            recordings = audioManager.recordings
        }
        
        // 按标签过滤
        if let selectedTag = selectedTag {
            recordings = recordings.filter { $0.tags.contains(selectedTag) }
        }
        
        return recordings
    }
    
    func onFilterChanged(_ newFilter: String) {
        // 当切换到非标签过滤器时，清除选中的标签
        if newFilter != L("homepage_filter_tag") {
            selectedTag = nil
        }
    }
    
    func onSearchTextChanged(_ newValue: String) {
        performSearch(query: newValue)
    }
    
    func deleteRecording(_ recording: AudioRecording) {
        audioManager.deleteRecording(recording)
    }
    
    func updateRecording(_ updatedRecording: AudioRecording) {
        audioManager.updateRecording(updatedRecording)
    }
    
    func onSpaceCreated(_ space: Space) {
        print("✅ 空间创建成功: \(space.name)")
        print("📝 描述: \(space.description)")
        
        // 这里可以添加后续逻辑，比如：
        // - 显示成功提示
        // - 刷新空间列表
        // - 导航到新创建的空间
    }
    
    private func performSearch(query: String) {
        // 清空之前的结果和错误
        searchError = nil
        
        // 如果查询为空，清除搜索结果
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        // 开始搜索
        isSearching = true
        
        SearchEngine.shared.search(query: query) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSearching = false
                
                switch result {
                case .success(let results):
                    self.searchResults = results
                    self.searchError = nil
                    print("🔍 搜索完成，找到 \(results.count) 条结果")
                    
                case .failure(let error):
                    self.searchResults = []
                    self.searchError = error
                    print("❌ 搜索失败: \(error.localizedDescription)")
                }
            }
        }
    }
}