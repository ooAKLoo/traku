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
    @State private var showingDetail: AudioRecording? = nil
    @State private var showingConnectionConfig = false
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: isDarkMode ? 
                    [Color.black, Color(white: 0.05)] :
                    [Color(white: 0.95), Color(white: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            RecordingsListView(
                audioManager: audioManager,
                showingDetail: $showingDetail,
                isDarkMode: isDarkMode
            )
            
            // 底部连接控制按钮
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ConnectionControlButton(
                        isConnected: audioManager.isConnected,
                        isDarkMode: isDarkMode
                    ) {
                        showingConnectionConfig = true
                    }
                    Spacer()
                }
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingConnectionConfig) {
            ConnectionConfigView(audioManager: audioManager)
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
                                .foregroundColor(selectedFilter == filter ? 
                                    (isDarkMode ? .white : .black) : 
                                    (isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)))
                            
                            Rectangle()
                                .fill(isDarkMode ? Color.white : Color.black)
                                .frame(height: 2)
                                .opacity(selectedFilter == filter ? 1 : 0)
                        }
                    }
                }
                
                Spacer()
                
                // 设置按钮
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                }
            }
            .padding(.trailing, 30)
            .padding(.vertical, 20)
            
            // 录音列表
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(audioManager.recordings) { recording in
                        RecordingCardView(recording: recording, isDarkMode: isDarkMode)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - 录音卡片视图
struct RecordingCardView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    
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
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
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
    let isDarkMode: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 设置选项列表
                    VStack(spacing: 15) {
                        // 外观设置
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                .frame(width: 30)
                            
                            Text("外观")
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Spacer()
                            
                            Picker("", selection: $isDarkMode) {
                                Text("深色").tag(true)
                                Text("浅色").tag(false)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 120)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                        )
                        
                        SettingsRowView(icon: "person.circle", title: "账户", isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "bell", title: "通知", isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "lock", title: "隐私", isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "questionmark.circle", title: "帮助", isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "info.circle", title: "关于", isDarkMode: isDarkMode, action: {})
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - 设置行视图
struct SettingsRowView: View {
    let icon: String
    let title: String
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .frame(width: 30)
                
                Text(title)
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
    }
}

// MARK: - 连接控制按钮
struct ConnectionControlButton: View {
    let isConnected: Bool
    let isDarkMode: Bool
    let action: () -> Void
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 背景圆圈
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isDarkMode ? 
                                [Color.white.opacity(0.1), Color.white.opacity(0.05)] :
                                [Color.black.opacity(0.05), Color.black.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                
                // 产品图片
                Image("product")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(
                            .linear(duration: 3.0)
                            .repeatForever(autoreverses: false)
                        ) {
                            rotation = 360
                        }
                    }
                
                // 连接状态指示器
                if isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .offset(x: 20, y: -20)
                        .overlay(
                            Circle()
                                .stroke(isDarkMode ? Color.black : Color.white, lineWidth: 2)
                                .frame(width: 8, height: 8)
                                .offset(x: 20, y: -20)
                        )
                }
            }
        }
        .shadow(
            color: isDarkMode ? .white.opacity(0.1) : .black.opacity(0.1),
            radius: 10,
            x: 0,
            y: 5
        )
    }
}

// MARK: - 连接配置视图
import SwiftUI

// MARK: - 增强的连接配置视图
struct ConnectionConfigView: View {
    @StateObject private var discoveryService = DeviceDiscoveryService()
    @ObservedObject var audioManager: AudioManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    @State private var selectedDevice: DeviceDiscoveryService.DiscoveredDevice?
    @State private var isConnecting = false
    @State private var showManualConfig = false
    @State private var manualIP = ""
    @State private var manualPort = "8888"
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                LinearGradient(
                    colors: isDarkMode ?
                        [Color.black, Color(white: 0.05)] :
                        [Color(white: 0.95), Color(white: 0.98)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 标题区域
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: isDarkMode ?
                                            [Color.blue.opacity(0.2), Color.purple.opacity(0.2)] :
                                            [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        
                        Text("设备连接")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        if audioManager.isConnected {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text(audioManager.connectionStatus)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.green)
                            }
                        } else {
                            Text("选择一个设备进行连接")
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                        }
                    }
                    .padding(.top, 20)
                    
                    // 设备列表
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("发现的设备")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Spacer()
                            
                            Button(action: {
                                discoveryService.refreshDevices()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                            }
                        }
                        .padding(.horizontal)
                        
                        if discoveryService.discoveredDevices.isEmpty {
                            // 没有发现设备
                            VStack(spacing: 15) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                                
                                Text("正在搜索设备...")
                                    .font(.system(size: 14))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: isDarkMode ? .white : .black))
                                    .scaleEffect(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal)
                        } else {
                            // 设备列表
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(discoveryService.discoveredDevices) { device in
                                        DeviceRowView(
                                            device: device,
                                            isSelected: selectedDevice?.id == device.id,
                                            isConnected: audioManager.connectedDevice?.id == device.id,
                                            isDarkMode: isDarkMode
                                        ) {
                                            selectedDevice = device
                                            connectToDevice(device)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(maxHeight: 200)
                        }
                    }
                    
                    // 手动连接选项
                    Button(action: {
                        showManualConfig.toggle()
                    }) {
                        HStack {
                            Image(systemName: "network")
                                .font(.system(size: 16))
                            Text("手动输入IP地址")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    
                    if showManualConfig {
                        ManualConfigView(
                            manualIP: $manualIP,
                            manualPort: $manualPort,
                            isDarkMode: isDarkMode
                        ) {
                            connectManually()
                        }
                    }
                    
                    // 连接状态信息
                    if isConnecting {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: isDarkMode ? .white : .black))
                                .scaleEffect(0.8)
                            Text("正在连接...")
                                .font(.system(size: 14))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                        )
                    }
                    
                    // 说明信息
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(isDarkMode ? .blue.opacity(0.8) : .blue)
                            Text("连接说明")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• 确保手机与ESP32设备在同一WiFi网络")
                            Text("• 设备会自动被发现并显示在列表中")
                            Text("• 点击设备即可连接")
                            Text("• 如果未发现设备，可手动输入IP地址")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    )
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("设备管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
                
                if audioManager.isConnected {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("断开") {
                            audioManager.disconnectFromDevice()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    func connectToDevice(_ device: DeviceDiscoveryService.DiscoveredDevice) {
        isConnecting = true
        
        // 使用音频管理器连接设备
        audioManager.connectToDevice(device)
        
        // 模拟连接延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
            if audioManager.isConnected {
                dismiss()
            }
        }
    }
    
    func connectManually() {
        guard !manualIP.isEmpty else { return }
        
        let device = DeviceDiscoveryService.DiscoveredDevice(
            name: "手动设备",
            ipAddress: manualIP,
            port: Int(manualPort) ?? 8888,
            statusPort: 8889,
            isStreaming: false
        )
        
        connectToDevice(device)
    }
}

// MARK: - 设备行视图
struct DeviceRowView: View {
    let device: DeviceDiscoveryService.DiscoveredDevice
    let isSelected: Bool
    let isConnected: Bool
    let isDarkMode: Bool
    let action: () -> Void
    
    private var backgroundView: some View {
        let fillColor = isSelected ?
                       (isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05)) :
                       (isDarkMode ? Color.white.opacity(0.05) : Color.white)
        
        let strokeColor = isConnected ? Color.green.opacity(0.5) :
                         (isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
        
        let strokeWidth: CGFloat = isConnected ? 2 : 1
        
        return RoundedRectangle(cornerRadius: 12)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                // 设备图标
                ZStack {
                    let circleColor = isConnected ? Color.green.opacity(0.2) :
                                     (isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    
                    Circle()
                        .fill(circleColor)
                        .frame(width: 40, height: 40)
                    
                    let iconColor = isConnected ? Color.green :
                                   (isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                
                // 设备信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text(device.ipAddress)
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                }
                
                Spacer()
                
                // 状态指示
                if isConnected {
                    Text("已连接")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.green)
                } else if device.isStreaming {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("使用中")
                            .font(.system(size: 12))
                            .foregroundColor(Color.orange)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
            }
            .padding()
            .background(backgroundView)
        }
    }
}

// MARK: - 手动配置视图
struct ManualConfigView: View {
    @Binding var manualIP: String
    @Binding var manualPort: String
    let isDarkMode: Bool
    let onConnect: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 8) {
                Text("IP地址")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                TextField("192.168.1.100", text: $manualIP)
                    .textFieldStyle(ModernTextFieldStyle(isDarkMode: isDarkMode))
                    .keyboardType(.numbersAndPunctuation)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("端口")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                TextField("8888", text: $manualPort)
                    .textFieldStyle(ModernTextFieldStyle(isDarkMode: isDarkMode))
                    .keyboardType(.numberPad)
            }
            
            Button(action: onConnect) {
                Text("连接")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDarkMode ? Color.white : Color.black)
                    )
                    .foregroundColor(isDarkMode ? .black : .white)
            }
            .disabled(manualIP.isEmpty)
            .opacity(manualIP.isEmpty ? 0.5 : 1.0)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
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

// MARK: - 连接步骤视图
struct ConnectionStepsView: View {
    let currentStep: Int
    let isDarkMode: Bool
    
    let steps = ["准备", "连接BLE", "传递凭证", "完成"]
    
    var body: some View {
        HStack(spacing: 15) {
            ForEach(0..<steps.count, id: \.self) { index in
                HStack(spacing: 8) {
                    // 步骤圆圈
                    ZStack {
                        Circle()
                            .fill(getStepColor(index))
                            .frame(width: 24, height: 24)
                        
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isDarkMode ? .black : .white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(getStepTextColor(index))
                        }
                    }
                    
                    // 连接线
                    if index < steps.count - 1 {
                        Rectangle()
                            .fill(index < currentStep - 1 ? getActiveColor() : getInactiveColor())
                            .frame(width: 30, height: 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    func getStepColor(_ index: Int) -> Color {
        if index < currentStep {
            return getActiveColor()
        } else if index == currentStep {
            return getActiveColor().opacity(0.8)
        } else {
            return getInactiveColor()
        }
    }
    
    func getStepTextColor(_ index: Int) -> Color {
        if index <= currentStep {
            return isDarkMode ? .black : .white
        } else {
            return isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)
        }
    }
    
    func getActiveColor() -> Color {
        return isDarkMode ? .white : .black
    }
    
    func getInactiveColor() -> Color {
        return isDarkMode ? .white.opacity(0.2) : .black.opacity(0.1)
    }
}

// MARK: - 现代文本框样式
struct ModernTextFieldStyle: TextFieldStyle {
    let isDarkMode: Bool
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(isDarkMode ? .white : .black)
    }
}

