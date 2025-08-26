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
struct AudioRecording: Identifiable {
    let id = UUID()
    let timestamp: Date
    let duration: TimeInterval
    let transcription: String
    let summary: String
    let tags: [String]
    let audioData: Data?
    var isPlaying: Bool = false
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var selectedTab = 0
    @State private var showingDetail: AudioRecording? = nil
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color.black, Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 主要内容区域
                if selectedTab == 0 {
                    RecordingView(audioManager: audioManager)
                } else {
                    RecordingsListView(
                        audioManager: audioManager,
                        showingDetail: $showingDetail
                    )
                }
                
                // 底部标签栏
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 录音界面
struct RecordingView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack {
            Spacer()
            
            // 音频可视化
            AudioVisualizerView(audioManager: audioManager)
                .frame(height: 120)
                .padding(.horizontal, 30)
            
            Spacer()
            
            // 录音时长显示
            Text(formatTime(recordingTime))
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .foregroundColor(.white)
                .opacity(isRecording ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.3), value: isRecording)
            
            Spacer()
            
            // 录音按钮
            ZStack {
                // 呼吸光晕效果
                if isRecording {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: pulseAnimation
                        )
                }
                
                // 主按钮
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isRecording ? 
                                        [Color.red, Color.red.opacity(0.8)] :
                                        [Color.white, Color(white: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .shadow(
                                color: isRecording ? 
                                    Color.red.opacity(0.5) :
                                    Color.white.opacity(0.3),
                                radius: 10
                            )
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 30))
                            .foregroundColor(isRecording ? .white : .black)
                    }
                }
                .scaleEffect(isRecording ? 0.95 : 1.0)
                .animation(.spring(response: 0.3), value: isRecording)
            }
            .onAppear {
                pulseAnimation = true
            }
            
            // 状态文字
            Text(isRecording ? "轻触停止" : "轻触录音")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 30)
            
            Spacer()
            
            // 连接状态
            HStack {
                Circle()
                    .fill(audioManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(audioManager.isConnected ? "已连接设备" : "未连接")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.bottom, 40)
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        isRecording = true
        recordingTime = 0
        audioManager.startRecording()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        audioManager.stopRecording()
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}

// MARK: - 音频可视化视图
struct AudioVisualizerView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var waveformData: [CGFloat] = Array(repeating: 0.5, count: 50)
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<waveformData.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: geometry.size.width / CGFloat(waveformData.count) - 2)
                        .scaleEffect(y: waveformData[index], anchor: .center)
                        .animation(.linear(duration: 0.05), value: waveformData[index])
                }
            }
            .onReceive(audioManager.$audioLevels) { levels in
                updateWaveform(with: levels)
            }
        }
    }
    
    func updateWaveform(with levels: [Float]) {
        guard !levels.isEmpty else { return }
        
        // 更新波形数据
        for i in 0..<waveformData.count {
            let level = levels.count > i ? CGFloat(levels[i]) : 0.5
            waveformData[i] = max(0.1, min(1.0, level))
        }
    }
}

// MARK: - 录音列表视图
struct RecordingsListView: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var showingDetail: AudioRecording?
    @State private var selectedFilter = "全部"
    
    let filters = ["全部", "标签", "时间"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部筛选栏
            HStack(spacing: 20) {
                ForEach(filters, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(filter)
                                .font(.system(size: 16, weight: selectedFilter == filter ? .semibold : .regular))
                                .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.5))
                            
                            Rectangle()
                                .fill(Color.white)
                                .frame(height: 2)
                                .opacity(selectedFilter == filter ? 1 : 0)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            
            // 录音列表
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(audioManager.recordings) { recording in
                        RecordingCardView(recording: recording)
                            .onTapGesture {
                                showingDetail = recording
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .sheet(item: $showingDetail) { recording in
            RecordingDetailView(recording: recording)
        }
    }
}

// MARK: - 录音卡片视图
struct RecordingCardView: View {
    let recording: AudioRecording
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 时间线指示器
            VStack {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
            }
            
            // 卡片内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间戳
                Text(formatDate(recording.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                
                // 标题（总结的第一句）
                Text(recording.summary.prefix(50) + "...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                // 标签
                HStack(spacing: 8) {
                    ForEach(recording.tags, id: \.self) { tag in
                        TagView(text: tag)
                    }
                }
                
                // 时长
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text("\(Int(recording.duration))秒")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
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
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - 自定义标签栏
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "mic.circle",
                title: "录音",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            TabBarButton(
                icon: "list.bullet",
                title: "记录",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
        }
        .padding(.vertical, 10)
        .background(
            Color.black.opacity(0.8)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }
}

// MARK: - 标签栏按钮
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 10))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
        }
    }
}