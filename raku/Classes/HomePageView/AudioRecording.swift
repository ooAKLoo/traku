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
    let summary: String
    let tags: [String]
    let audioData: Data?
    var isPlaying: Bool = false
    let enrichedContent: String?
    
    init(id: UUID? = nil, timestamp: Date, duration: TimeInterval, transcription: String, summary: String, tags: [String], audioData: Data?, enrichedContent: String?) {
        self.id = id ?? UUID()
        self.timestamp = timestamp
        self.duration = duration
        self.transcription = transcription
        self.summary = summary
        self.tags = tags
        self.audioData = audioData
        self.enrichedContent = enrichedContent
    }
    
    static func == (lhs: AudioRecording, rhs: AudioRecording) -> Bool {
        return lhs.id == rhs.id &&
               lhs.transcription == rhs.transcription &&
               lhs.summary == rhs.summary &&
               lhs.tags == rhs.tags &&
               lhs.enrichedContent == rhs.enrichedContent
    }
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var audioManager = AudioManagerAdapter()
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // 极简背景
                (isDarkMode ? Color.black : Color.white)
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
    
    
    var filteredRecordings: [AudioRecording] {
        if searchText.isEmpty {
            return audioManager.recordings
        } else {
            return audioManager.recordings.filter { recording in
                recording.summary.localizedCaseInsensitiveContains(searchText) ||
                recording.transcription.localizedCaseInsensitiveContains(searchText) ||
                recording.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
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
                
                // 录音列表
                HomepageListView(
                    filteredRecordings: filteredRecordings,
                    isDarkMode: isDarkMode
                )
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
}

// MARK: - 录音卡片视图
struct RecordingCardView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 卡片内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间戳
                Text(recording.timestamp.timeFormatted)
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                
                // 标题（总结的第一句）
                Text(recording.summary.prefix(50) + "...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                
                // 标签
                HStack(spacing: 8) {
                    ForEach(recording.tags, id: \.self) { tag in
                        TagView(text: tag, isDarkMode: isDarkMode)
                    }
                }
                
                // 时长
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text("\(Int(recording.duration))秒")
                        .font(.system(size: 12))
                }
                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .shadow(
                        color: Color.black.opacity(isDarkMode ? 0.3 : 0.05),
                        radius: isHovered ? 8 : 4,
                        x: 0,
                        y: isHovered ? 4 : 2
                    )
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
}

// MARK: - 标签视图
struct TagView: View {
    let text: String
    let isDarkMode: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
            )
    }
}


// MARK: - 主界面录音控制
struct RecordingControlView: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        VStack(spacing: 30) {
            // 音频波形可视化
            if audioManager.isRecording {
                AudioWaveformView(levels: audioManager.audioLevels, isDarkMode: isDarkMode)
                    .frame(height: 100)
                    .padding(.horizontal)
            }
            
            // 录音时间
            if isRecording {
                Text(FormatHelper.formatDurationWithDecimal(recordingTime))
                    .font(.system(size: 48, weight: .thin, design: .monospaced))
                    .foregroundColor(isDarkMode ? .white : .black)
            }
            
            // 录音按钮
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isRecording ?
                                    [Color.red, Color.red.opacity(0.8)] :
                                    [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: isRecording ? Color.red.opacity(0.5) : Color.blue.opacity(0.5),
                               radius: isRecording ? 20 : 10)
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .scaleEffect(isRecording ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isRecording)
                }
            }
            .disabled(!audioManager.isConnected)
            .opacity(audioManager.isConnected ? 1.0 : 0.5)
            
            // 连接状态提示
            if !audioManager.isConnected {
                Text("请先连接设备")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
            }
        }
        .padding()
    }
    
    func toggleRecording() {
        if isRecording {
            // 停止录音
            audioManager.stopRecording()
            timer?.invalidate()
            timer = nil
            recordingTime = 0
        } else {
            // 开始录音
            audioManager.startRecording()
            recordingTime = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingTime += 0.1
            }
        }
        
        withAnimation(.spring()) {
            isRecording.toggle()
        }
    }
    
}


// MARK: - Preview
// 预览专用的 ContentView 包装器，可以覆盖 isDarkMode 设置
struct PreviewContentView: View {
    let forcedDarkMode: Bool
    @StateObject private var audioManager = AudioManagerAdapter()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 极简背景
                (forcedDarkMode ? Color.black : Color(white: 0.98))
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
