//
//  TagManagementView.swift
//  raku
//
//  Created by Assistant on 2025/9/16.
//

import SwiftUI
import Combine
import Foundation


struct TagManagementView: View {
    @Environment(\.dismiss) var dismiss
    let isDarkMode: Bool
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @State private var showingMergeView = false
    @State private var showingSplitView = false
    @State private var showingRenameView = false
    @State private var allTags: [String] = []
    @State private var tagUsageCount: [String: Int] = [:]
    @State private var clusteringResult: TagClusteringResult?
    @State private var isAnalyzingClusters = false
    @StateObject private var clusteringManager = TagClusteringManager()
    
    private let databaseManager = DatabaseManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(spacing: 15) {
                        // 合并标签
                        Button(action: {
                            showingMergeView = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                    .frame(width: 30)
                                
                                Text("合并标签")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                            )
                        }
                        
                        // 重命名标签
                        Button(action: {
                            showingRenameView = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                    .frame(width: 30)
                                
                                Text("重命名标签")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                            )
                        }
                        
                        // 拆分标签
                        Button(action: {
                            showingSplitView = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                    .frame(width: 30)
                                
                                Text("拆分标签")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                            )
                        }
                        
                        // 标签统计
                        TagStatisticsView(
                            allTags: allTags,
                            tagUsageCount: tagUsageCount,
                            isDarkMode: isDarkMode
                        )
                        
                        // AI合并建议
                        TagClusteringSuggestionView(
                            allTags: allTags,
                            clusteringResult: clusteringResult,
                            isAnalyzing: isAnalyzingClusters,
                            isDarkMode: isDarkMode,
                            onAnalyze: analyzeTagClustering,
                            onApplyMerge: applyTagMerge
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle(L("tag_management_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common_done")) {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingMergeView) {
            TagMergeView(
                allTags: allTags,
                tagUsageCount: tagUsageCount,
                isDarkMode: isDarkMode,
                isPresented: $showingMergeView,
                onTagsUpdated: loadTagData
            )
        }
        .sheet(isPresented: $showingRenameView) {
            TagRenameView(
                allTags: allTags,
                tagUsageCount: tagUsageCount,
                isDarkMode: isDarkMode,
                isPresented: $showingRenameView,
                onTagsUpdated: loadTagData
            )
        }
        .sheet(isPresented: $showingSplitView) {
            TagSplitView(
                allTags: allTags,
                tagUsageCount: tagUsageCount,
                isDarkMode: isDarkMode,
                isPresented: $showingSplitView,
                onTagsUpdated: loadTagData
            )
        }
        .onAppear {
            loadTagData()
            setupTagClusteringService()
        }
    }
    
    private func loadTagData() {
        let recordings = databaseManager.loadRecordings()
        
        var tagCount: [String: Int] = [:]
        var uniqueTags: Set<String> = []
        
        for recording in recordings {
            for tag in recording.tags {
                uniqueTags.insert(tag)
                tagCount[tag, default: 0] += 1
            }
        }
        
        allTags = Array(uniqueTags).sorted()
        tagUsageCount = tagCount
    }
    
    private func setupTagClusteringService() {
        clusteringManager.onAnalysisComplete = { result in
            DispatchQueue.main.async {
                self.clusteringResult = result
                self.isAnalyzingClusters = false
            }
        }
        
        clusteringManager.onAnalysisError = { error in
            DispatchQueue.main.async {
                self.isAnalyzingClusters = false
                print("标签聚类分析失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func analyzeTagClustering() {
        guard !allTags.isEmpty else { return }
        isAnalyzingClusters = true
        clusteringManager.analyzeTags(allTags)
    }
    
    private func applyTagMerge(_ cluster: TagCluster) {
        let representative = cluster.representative
        let membersToMerge = cluster.members
        
        // 获取所有录音记录
        let recordings = databaseManager.loadRecordings()
        
        // 更新每个录音的标签
        for var recording in recordings {
            var updatedTags = recording.tags
            var hasChanges = false
            
            // 将所有要合并的标签替换为代表性标签
            for member in membersToMerge {
                if let index = updatedTags.firstIndex(of: member) {
                    updatedTags.remove(at: index)
                    hasChanges = true
                }
            }
            
            // 如果有变化且代表性标签不存在，则添加
            if hasChanges && !updatedTags.contains(representative) {
                updatedTags.append(representative)
            }
            
            // 更新录音记录
            if hasChanges {
                recording = AudioRecording(
                    id: recording.id,
                    timestamp: recording.timestamp,
                    duration: recording.duration,
                    transcription: recording.transcription,
                    title: recording.title,
                    summary: recording.summary,
                    tags: updatedTags,
                    audioData: recording.audioData,
                    enrichedContent: recording.enrichedContent,
                    polishedText: recording.polishedText,
                    contentType: recording.contentType
                )
                _ = databaseManager.updateRecording(recording)
            }
        }
        
        // 重新加载标签数据
        loadTagData()
        
        // 发送标签更新通知
        NotificationCenter.default.post(name: .tagsDidUpdate, object: nil)
        
        // 重新分析聚类
        analyzeTagClustering()
    }
}

struct TagStatisticsView: View {
    let allTags: [String]
    let tagUsageCount: [String: Int]
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar")
                    .font(.system(size: 20))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .frame(width: 30)
                
                Text("标签统计")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                Text("共 \(allTags.count) 个")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            
            if allTags.isEmpty {
                Text("暂无标签")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            HStack {
                                Text(tag)
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white : .black)
                                
                                Spacer()
                                
                                Text("\(tagUsageCount[tag] ?? 0)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white.opacity(0.7))
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

// MARK: - 标签聚类管理器

class TagClusteringManager: NSObject, ObservableObject, TagClusteringServiceDelegate {
    private let service = TagClusteringService()
    
    var onAnalysisComplete: ((TagClusteringResult) -> Void)?
    var onAnalysisError: ((TagClusteringError) -> Void)?
    
    override init() {
        super.init()
        service.delegate = self
    }
    
    func analyzeTags(_ tags: [String]) {
        service.analyzeTags(tags)
    }
    
    // MARK: - TagClusteringServiceDelegate
    
    func tagClusteringService(_ service: TagClusteringService, didCompleteAnalysis result: TagClusteringResult) {
        onAnalysisComplete?(result)
    }
    
    func tagClusteringService(_ service: TagClusteringService, didFailWithError error: TagClusteringError) {
        onAnalysisError?(error)
    }
}

// MARK: - AI合并建议视图

struct TagClusteringSuggestionView: View {
    let allTags: [String]
    let clusteringResult: TagClusteringResult?
    let isAnalyzing: Bool
    let isDarkMode: Bool
    let onAnalyze: () -> Void
    let onApplyMerge: (TagCluster) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .frame(width: 30)
                
                Text("AI合并建议")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                if !isAnalyzing {
                    Button("分析") {
                        onAnalyze()
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                }
            }
            
            if isAnalyzing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在分析标签聚类...")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                .padding(.horizontal)
            } else if let result = clusteringResult {
                if result.clusters.isEmpty {
                    Text("未发现可合并的标签组")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        .padding(.horizontal)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(result.clusters.enumerated()), id: \.offset) { index, cluster in
                                TagClusterItemView(
                                    cluster: cluster,
                                    index: index + 1,
                                    isDarkMode: isDarkMode,
                                    onApply: { onApplyMerge(cluster) }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    
                    if !result.analysisSummary.isEmpty {
                        Text(result.analysisSummary)
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                }
            } else if allTags.count >= 2 {
                Text("点击分析按钮开始AI标签聚类分析")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .padding(.horizontal)
            } else {
                Text("需要至少2个标签才能进行聚类分析")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

// MARK: - 标签聚类项视图

struct TagClusterItemView: View {
    let cluster: TagCluster
    let index: Int
    let isDarkMode: Bool
    let onApply: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(index). \(cluster.representative) ← \(cluster.members.joined(separator: ", "))")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                Button("应用") {
                    onApply()
                }
                .font(.system(size: 12))
                .foregroundColor(.blue)
            }
            
            Text(cluster.reason)
                .font(.system(size: 12))
                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white.opacity(0.7))
        )
    }
}

