//
//  AudioRecording.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - 数据模型
struct AudioRecording: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let transcription: String
    var title: String
    let summary: String
    var tags: [String]
    let audioData: Data?
    var isPlaying: Bool = false
    var enrichedContent: String?
    var polishedText: String = ""  // 润色后的文本，默认为空
    
    init(id: UUID? = nil, timestamp: Date, duration: TimeInterval, transcription: String, title: String, summary: String, tags: [String], audioData: Data?, enrichedContent: String?, polishedText: String = "") {
        self.id = id ?? UUID()
        self.timestamp = timestamp
        self.duration = duration
        self.transcription = transcription
        self.title = title
        self.summary = summary
        self.tags = tags
        self.audioData = audioData
        self.enrichedContent = enrichedContent
        self.polishedText = polishedText
    }
    
    static func == (lhs: AudioRecording, rhs: AudioRecording) -> Bool {
        return lhs.id == rhs.id &&
               lhs.transcription == rhs.transcription &&
               lhs.title == rhs.title &&
               lhs.summary == rhs.summary &&
               lhs.tags == rhs.tags &&
               lhs.enrichedContent == rhs.enrichedContent &&
               lhs.polishedText == rhs.polishedText
    }
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var audioManager = AudioManagerAdapter()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 极简背景
                (isDarkMode ? Color.black : Color.appBackground)
                    .ignoresSafeArea()
                
                RecordingsListView(
                    audioManager: audioManager,
                    isDarkMode: isDarkMode
                )
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - 录音列表视图
struct RecordingsListView: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    let isDarkMode: Bool
    @State private var selectedFilter = "全部"
    @State private var showingSettings = false
    @State private var hoveredFilter: String? = nil
    @State private var searchText = ""
    @State private var showingConnectionConfig = false
    @State private var selectedTag: String? = nil
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var searchError: SearchError?
    
    var filteredRecordings: [AudioRecording] {
        var recordings: [AudioRecording]
        
        // 如果有搜索结果，优先显示搜索结果
        if !searchText.isEmpty && !searchResults.isEmpty {
            recordings = searchResults.compactMap { $0.recording }
        } else {
            recordings = audioManager.recordings
        }
        
        // 按标签过滤
        if let selectedTag = selectedTag {
            recordings = recordings.filter { $0.tags.contains(selectedTag) }
        }
        
        return recordings
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 顶部导航栏
                HomepageHeaderView(
                    audioManager: audioManager,
                    isDarkMode: isDarkMode,
                    selectedFilter: $selectedFilter,
                    showingSettings: $showingSettings,
                    hoveredFilter: $hoveredFilter,
                    searchText: $searchText,
                    showingConnectionConfig: $showingConnectionConfig
                )
                .onChange(of: selectedFilter) { newFilter in
                    // 当切换到非标签过滤器时，清除选中的标签
                    if newFilter != "标签" {
                        selectedTag = nil
                    }
                }
                .onChange(of: searchText) { newValue in
                    performSearch(query: newValue)
                }
                
                // 标签过滤 TabBar（当选择"标签"时显示在 header 下面）
                if selectedFilter == "标签" {
                    TagFilterTabBar(
                        allRecordings: audioManager.recordings,
                        selectedTag: $selectedTag
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                // 搜索状态指示器
                if isSearching && !searchText.isEmpty {
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
                if !searchText.isEmpty && searchResults.isEmpty && !isSearching {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                        
                        Text("未找到相关内容")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        
                        if let error = searchError {
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
                if !(!searchText.isEmpty && searchResults.isEmpty && !isSearching) {
                    HomepageListView(
                        filteredRecordings: filteredRecordings,
                        isDarkMode: isDarkMode,
                        selectedFilter: selectedFilter,
                        onDelete: deleteRecording,
                        audioManager: audioManager,
                        onRecordingUpdated: updateRecording
                    )
                }
            }
            
            // 悬浮录音控制卡片
            VStack {
                Spacer()
                FloatingRecordingControlCard(audioManager: audioManager)
            }
            
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingConnectionConfig) {
            ConnectionConfigView(audioManager: audioManager)
        }
    }
    
    private func deleteRecording(_ recording: AudioRecording) {
        audioManager.deleteRecording(recording)
    }
    
    private func updateRecording(_ updatedRecording: AudioRecording) {
        audioManager.updateRecording(updatedRecording)
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
        
        SearchEngine.shared.search(query: query) { [self] result in
            DispatchQueue.main.async {
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

// MARK: - 预览专用的 AudioManager
class PreviewAudioManager: AudioManagerAdapter {
    private var shouldSkipDatabaseInit = true
    
    init() {
        print("📱 PreviewAudioManager: 初始化预览数据管理器")
        super.init(skipDatabaseLoad: true)
        
        // 清空从数据库加载的数据，使用示例数据
        self.recordings = []
        self.recordings = [
            AudioRecording(
                timestamp: Date(),
                duration: 185.5,
                transcription: "这是一段会议录音的转写内容，讨论了关于新产品开发的进度和计划。我们需要在下个季度完成主要功能的开发，并准备进行用户测试。团队决定采用敏捷开发方法，每两周进行一次迭代评审。",
                title: "产品开发会议讨论",
                summary: "确定了Q2的开发目标，包括核心功能完成、用户界面优化和测试计划制定。",
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
                
                ## 时间规划
                **短期（1周内）**：每日2小时调研科技艺术案例，周末输出趋势报告与用户需求分析
                **中期（1月内）**：前2周完成技术方案设计（含AI模型选型），后2周收集艺术素材与训练数据
                **长期（3月内）**：第3-6周开发AI生成模型并测试优化，第7-8周筹备线下展览（布展/宣传）
                """
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-3600),
                duration: 45.2,
                transcription: "今天的学习笔记，主要学习了SwiftUI的高级动画技巧。包括自定义转场动画、弹簧动画的参数调节，以及如何优化动画性能。",
                title: "SwiftUI动画技巧学习",
                summary: "掌握了转场动画和弹簧动画的实现方法，了解了动画性能优化的关键点。",
                tags: ["学习", "SwiftUI", "动画"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: """
                ## 学习要点
                
                ### 转场动画
                - asymmetric 转场的使用
                - move 和 opacity 的组合效果
                
                ### 弹簧动画
                - response 和 dampingFraction 参数调节
                - 不同场景下的最佳参数选择
                """
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-7200),
                duration: 126.8,
                transcription: "团队周会录音，讨论了本周的工作进展和下周的计划安排。产品团队完成了新功能的设计稿，开发团队修复了几个重要的bug。",
                title: "团队周会总结",
                summary: "产品设计按计划完成，开发进度良好，下周将开始新功能开发。",
                tags: ["团队", "周会", "进度"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-10800),
                duration: 89.3,
                transcription: "个人想法记录：关于如何提升用户体验的一些思考，包括界面设计的简化、交互流程的优化，以及反馈机制的改进。",
                title: "用户体验优化思考",
                summary: "从界面、交互、反馈三个维度提出了改进建议。",
                tags: ["个人", "用户体验", "思考"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: """
                ## 用户体验优化方案
                
                ### 界面设计
                - 减少不必要的视觉元素
                - 提高对比度和可读性
                
                ### 交互优化
                - 简化操作步骤
                - 提供快捷操作方式
                
                ### 反馈机制
                - 及时的视觉反馈
                - 清晰的状态提示
                """
            )
        ]
        
        // 设置连接状态
        self.isConnected = true
        print("📱 PreviewAudioManager: 已加载 \(self.recordings.count) 条示例录音数据")
    }
}


// MARK: - 标签视图
struct TagView: View {
    let text: String
    let isDarkMode: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
    }
}

// MARK: - Preview
// 预览专用的 ContentView 包装器，可以覆盖 isDarkMode 设置
struct PreviewContentView: View {
    let forcedDarkMode: Bool
    @StateObject private var audioManager = PreviewAudioManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 极简背景
                (forcedDarkMode ? Color.black : Color.appBackground)
                    .ignoresSafeArea()
                
                RecordingsListView(
                    audioManager: audioManager,
                    isDarkMode: forcedDarkMode
                )
            }
        }
        .preferredColorScheme(forcedDarkMode ? .dark : .light)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 浅色模式预览
            PreviewContentView(forcedDarkMode: false)
                .previewDisplayName("Light Mode")
            
            // 深色模式预览
            PreviewContentView(forcedDarkMode: true)
                .previewDisplayName("Dark Mode")
            
            // iPad 预览
            PreviewContentView(forcedDarkMode: true)
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
                .previewDisplayName("iPad Pro - Dark")
            
            // 小屏幕设备预览
            PreviewContentView(forcedDarkMode: false)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
                .previewDisplayName("iPhone SE - Light")
        }
    }
}
