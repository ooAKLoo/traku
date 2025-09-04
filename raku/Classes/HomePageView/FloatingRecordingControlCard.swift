//
//  FloatingRecordingControlCard.swift
//  raku
//
//  Created by 杨东举 on 2025/9/4.
//

import SwiftUI
import Combine

// MARK: - 悬浮录音控制卡片
struct FloatingRecordingControlCard: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 连接状态提示区域
            if !audioManager.isConnected || isExpanded {
                connectionStatusView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // 录音控制按钮区域
            recordingControlsView
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isDarkMode ? Color.black.opacity(0.9) : Color.white)
                .shadow(
                    color: Color.black.opacity(isDarkMode ? 0.6 : 0.15),
                    radius: 20,
                    x: 0,
                    y: -5
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .onReceive(audioManager.$isRecording) { recording in
            withAnimation(.spring()) {
                isRecording = recording
            }
            
            if recording {
                startTimer()
            } else {
                stopTimer()
            }
        }
        .onTapGesture {
            if !audioManager.isConnected {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    // MARK: - 连接状态视图
    private var connectionStatusView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // 连接状态指示器
                Circle()
                    .fill(audioManager.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(audioManager.isConnected ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: audioManager.isConnected)
                
                Text("连接状态: \(audioManager.isConnected ? "已连接" : "未连接")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(audioManager.isConnected ? Color.green : Color.red)
                
                Spacer()
                
                Text(audioManager.connectionStatus)
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
            }
            
            if let device = audioManager.connectedDevice {
                HStack {
                    Image(systemName: "wifi")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    
                    Text("设备: \(device.name)")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    
                    Spacer()
                    
                    Text(device.ipAddress)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                }
            } else if !audioManager.isConnected {
                Text("请先连接ESP32设备后再录音")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isDarkMode ? Color.yellow.opacity(0.8) : Color.orange)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - 录音控制视图
    private var recordingControlsView: some View {
        HStack(spacing: 20) {
            // 录音时间显示（仅在录音时显示）
            if isRecording {
                VStack(spacing: 4) {
                    Text(FormatHelper.formatDurationWithDecimal(recordingTime))
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("录音中...")
                        .font(.system(size: 11))
                        .foregroundColor(Color.red)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale),
                    removal: .opacity
                ))
            }
            
            Spacer()
            
            // 开始录音按钮
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isRecording ?
                                    [Color.red, Color.red.opacity(0.8)] :
                                    (audioManager.isConnected ?
                                        [Color.blue, Color.purple] :
                                        [Color.gray.opacity(0.3), Color.gray.opacity(0.5)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isRecording ? 65 : 60, height: isRecording ? 65 : 60)
                        .shadow(
                            color: isRecording ?
                                Color.red.opacity(0.4) :
                                (audioManager.isConnected ? Color.blue.opacity(0.3) : Color.clear),
                            radius: isRecording ? 15 : 8
                        )
                    
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: isRecording ? 28 : 24))
                        .foregroundColor(.white)
                        .scaleEffect(isRecording ? 0.9 : 1.0)
                }
            }
            .disabled(!audioManager.isConnected)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
            .animation(.easeInOut(duration: 0.2), value: audioManager.isConnected)
            
            Spacer()
            
            // 波形可视化（仅在录音时显示）
            if isRecording && audioManager.isRecording {
                MiniAudioWaveformView(levels: audioManager.audioLevels, isDarkMode: isDarkMode)
                    .frame(width: 60, height: 30)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale),
                        removal: .opacity
                    ))
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
    }
    
    // MARK: - 私有方法
    private func toggleRecording() {
        if isRecording {
            audioManager.stopRecording()
        } else {
            audioManager.startRecording()
        }
    }
    
    private func startTimer() {
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingTime = 0
    }
}

// MARK: - 迷你音频波形视图
struct MiniAudioWaveformView: View {
    let levels: [Float]
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<15, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [
                                colorForLevel(getLevel(at: index)),
                                colorForLevel(getLevel(at: index)).opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: CGFloat(4 + getLevel(at: index) * 22))
                    .animation(.easeInOut(duration: 0.1), value: levels)
            }
        }
    }
    
    func getLevel(at index: Int) -> Float {
        let scaledIndex = Int(Float(index) * Float(levels.count) / 15.0)
        guard scaledIndex < levels.count else { return 0.1 }
        return levels[scaledIndex]
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

// MARK: - 预览
struct FloatingRecordingControlCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                FloatingRecordingControlCard(audioManager: AudioManagerAdapter())
            }
        }
        .previewDisplayName("Floating Control Card")
    }
}