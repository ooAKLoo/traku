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
                    .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
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
struct ConnectionConfigView: View {
    @ObservedObject var audioManager: AudioManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var ssid = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var connectionStep = 0
    
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
                
                VStack(spacing: 30) {
                    // 标题区域
                    VStack(spacing: 15) {
                        // 设备图标
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
                            
                            Image("product")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        
                        Text("设备连接配置")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : .black)
                        
                        Text("配置设备连接Wi-Fi网络")
                            .font(.system(size: 16))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // 连接步骤指示器
                    ConnectionStepsView(currentStep: connectionStep, isDarkMode: isDarkMode)
                    
                    // 配置表单
                    VStack(spacing: 20) {
                        // Wi-Fi SSID输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wi-Fi网络名称")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            
                            TextField("输入Wi-Fi名称", text: $ssid)
                                .textFieldStyle(ModernTextFieldStyle(isDarkMode: isDarkMode))
                        }
                        
                        // Wi-Fi 密码输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wi-Fi密码")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            
                            SecureField("输入Wi-Fi密码", text: $password)
                                .textFieldStyle(ModernTextFieldStyle(isDarkMode: isDarkMode))
                        }
                        
                        // 连接按钮
                        Button(action: startConnection) {
                            HStack {
                                if isConnecting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: isDarkMode ? .black : .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isConnecting ? "正在连接..." : "开始配置")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDarkMode ? Color.white : Color.black)
                            )
                            .foregroundColor(isDarkMode ? .black : .white)
                        }
                        .disabled(ssid.isEmpty || password.isEmpty || isConnecting)
                        .opacity(ssid.isEmpty || password.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, 20)
                    
                    // 说明信息
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(isDarkMode ? .blue.opacity(0.8) : .blue)
                            Text("配置步骤")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. 确保设备处于配置模式")
                            Text("2. 手机连接到设备热点")
                            Text("3. 输入目标Wi-Fi信息并配置")
                            Text("4. 等待设备重启并连接")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("设备连接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
            .alert("连接状态", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
    
    func startConnection() {
        isConnecting = true
        connectionStep = 1
        
        // 第一步：准备BLE连接
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            self.connectionStep = 2
//            // 开始搜索BLE设备
//            self.audioManager.startScanning()
        }
        
        // 轮询检查连接状态
        checkConnectionStatus()
        
        // 设置超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            if self.isConnecting {
                self.isConnecting = false
                self.connectionStep = 0
                self.alertMessage = "连接超时，请重试"
                self.showAlert = true
            }
        }
    }
    
    func checkConnectionStatus() {
       
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
        return isDarkMode ? .white.opacity(0.2) : .black.opacity(0.2)
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

