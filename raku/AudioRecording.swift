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
    let id = UUID()
    let timestamp: Date
    let duration: TimeInterval
    let transcription: String
    let summary: String
    let tags: [String]
    let audioData: Data?
    var isPlaying: Bool = false
    
    static func == (lhs: AudioRecording, rhs: AudioRecording) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingDetail: AudioRecording? = nil
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            // 极简背景
            (isDarkMode ? Color.black : Color(white: 0.98))
                .ignoresSafeArea()
            
            RecordingsListView(
                audioManager: audioManager,
                showingDetail: $showingDetail,
                isDarkMode: isDarkMode
            )
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onAppear {
            // 加载模拟数据
            audioManager.loadMockData()
        }
    }
}


// MARK: - 录音列表视图
struct RecordingsListView: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var showingDetail: AudioRecording?
    let isDarkMode: Bool
    @State private var selectedFilter = "全部"
    @State private var showingSettings = false
    @State private var hoveredFilter: String? = nil
    @State private var searchText = ""
    @State private var showingConnectionConfig = false
    
    let filters = ["全部", "标签", "时间"]
    
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
        VStack(spacing: 0) {
            // 顶部栏
            VStack(spacing: 16) {
                // 第一行：设备连接状态、搜索框、设置按钮
                HStack(spacing: 16) {
                    // 设备连接圆环（左侧）
                    Button(action: {
                        showingConnectionConfig = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                                .frame(width: 44, height: 44)
                                .shadow(
                                    color: Color.black.opacity(isDarkMode ? 0.5 : 0.12),
                                    radius: 6,
                                    x: 0,
                                    y: 3
                                )
                            
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            // 连接状态指示器
                            if audioManager.isConnected {
                                Circle()
                                    .fill(isDarkMode ? Color.white : Color.black)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                    
                    // 搜索框（中间）
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                        
                        TextField("搜索录音...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                            .shadow(
                                color: isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.08),
                                radius: isDarkMode ? 10 : 8,
                                x: 0,
                                y: isDarkMode ? 2 : 4
                            )
                    )
                    
                    // 设置按钮（右侧）
                    Button(action: {
                        showingSettings = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                                .frame(width: 44, height: 44)
                                .shadow(
                                    color: Color.black.opacity(isDarkMode ? 0.5 : 0.12),
                                    radius: 6,
                                    x: 0,
                                    y: 3
                                )
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                        }
                    }
                }
                
                // 第二行：筛选栏
                HStack(spacing: 30) {
                    ForEach(filters, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)) {
                            selectedFilter = filter
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text(filter)
                                .font(.system(size: 16, weight: selectedFilter == filter ? .semibold : .regular))
                                .foregroundColor(selectedFilter == filter ? 
                                    (isDarkMode ? .white : .black) : 
                                    (hoveredFilter == filter ? 
                                        (isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)) :
                                        (isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))))
                                .animation(.easeInOut(duration: 0.2), value: selectedFilter)
                                .animation(.easeInOut(duration: 0.15), value: hoveredFilter)
                            
                            // 底部指示线
                            ZStack {
                                // 背景透明线条（占位）
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: 40, height: 2)
                                
                                // 实际显示的线条
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                (isDarkMode ? Color.white : Color.black).opacity(0.8),
                                                (isDarkMode ? Color.white : Color.black)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 24, height: 2)
                                    .cornerRadius(1)
                                    .scaleEffect(x: selectedFilter == filter ? 1 : 0, y: 1)
                                    .opacity(selectedFilter == filter ? 1 : 0)
                                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: selectedFilter)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHovered in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredFilter = isHovered ? filter : nil
                        }
                    }
                }
                
                Spacer()
            }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(
                (isDarkMode ? Color.black : Color.white)
            )
            
            // 录音列表
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(Array(filteredRecordings.enumerated()), id: \.element.id) { index, recording in
                        RecordingCardView(recording: recording, isDarkMode: isDarkMode)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingDetail = recording
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .scale)
                            ))
                            .animation(.easeInOut(duration: 0.3).delay(Double(index) * 0.05))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .sheet(item: $showingDetail) { recording in
            RecordingDetailView(recording: recording)
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
            // 时间线指示器
            VStack {
                Circle()
                    .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.15))
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .frame(width: 1)
            }
            
            // 卡片内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间戳
                Text(formatDate(recording.timestamp))
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
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
    @ObservedObject var audioManager: AudioManager
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
                Text(formatTime(recordingTime))
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
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
}

// MARK: - 音频波形视图
struct AudioWaveformView: View {
    let levels: [Float]
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<50, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                colorForLevel(getLevel(at: index)),
                                colorForLevel(getLevel(at: index)).opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: CGFloat(20 + getLevel(at: index) * 80))
                    .animation(.easeInOut(duration: 0.1), value: levels)
            }
        }
    }
    
    func getLevel(at index: Int) -> Float {
        guard index < levels.count else { return 0.1 }
        return levels[index]
    }
    
    func colorForLevel(_ level: Float) -> Color {
        if level > 0.7 {
            return Color.red
        } else if level > 0.4 {
            return Color.orange
        } else {
            return Color.green
        }
    }
}

// MARK: - Preview
// 预览专用的 ContentView 包装器，可以覆盖 isDarkMode 设置
struct PreviewContentView: View {
    let forcedDarkMode: Bool
    @StateObject private var audioManager = AudioManager()
    @State private var showingDetail: AudioRecording? = nil
    
    var body: some View {
        ZStack {
            // 极简背景
            (forcedDarkMode ? Color.black : Color(white: 0.98))
                .ignoresSafeArea()
            
            RecordingsListView(
                audioManager: audioManager,
                showingDetail: $showingDetail,
                isDarkMode: forcedDarkMode
            )
        }
        .preferredColorScheme(forcedDarkMode ? .dark : .light)
        .onAppear {
            // 加载模拟数据
            audioManager.loadMockData()
        }
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
