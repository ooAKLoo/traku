////
////  ContentView.swift
////  raku
////
////  Created by 杨东举 on 2025/8/26.
////
//
//
//// ContentView.swift - 主视图
//import SwiftUI
//import AVFoundation
//import Network
//
//struct ContentView: View {
//    @StateObject private var audioManager = AudioManager()
//    @State private var showingSettings = false
//    @State private var showingWiFiConfig = false
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                // 背景渐变
//                LinearGradient(
//                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
//                    startPoint: .top,
//                    endPoint: .bottom
//                )
//                .ignoresSafeArea()
//                
//                VStack(spacing: 30) {
//                    // 连接状态卡片
//                    ConnectionStatusCard(audioManager: audioManager)
//                        .onTapGesture {
//                            if !audioManager.isConnected {
//                                showingWiFiConfig = true
//                            }
//                        }
//                    
//                    // 录音控制面板
//                    RecordingControlPanel(audioManager: audioManager)
//                    
//                    // 音频可视化
//                    AudioVisualizerView(audioLevels: audioManager.audioLevels)
//                    
//                    // 录音列表
//                    RecordingsListView(recordings: audioManager.recordings)
//                    
//                    Spacer()
//                }
//                .padding()
//            }
//            .navigationTitle("ESP32 音频录制")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button(action: { showingSettings = true }) {
//                        Image(systemName: "gearshape.fill")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showingSettings) {
//            SettingsView(audioManager: audioManager)
//        }
//        .sheet(isPresented: $showingWiFiConfig) {
//            WiFiConfigView(audioManager: audioManager)
//        }
//    }
//}
//
//// 连接状态卡片
//struct ConnectionStatusCard: View {
//    @ObservedObject var audioManager: AudioManager
//    
//    var body: some View {
//        VStack(spacing: 15) {
//            HStack {
//                Circle()
//                    .fill(audioManager.isConnected ? Color.green : Color.red)
//                    .frame(width: 12, height: 12)
//                
//                Text(audioManager.isConnected ? "已连接到ESP32" : "未连接")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                
//                Spacer()
//                
//                if audioManager.isConnected {
//                    Text(audioManager.deviceIP)
//                        .font(.caption)
//                        .foregroundColor(.white.opacity(0.8))
//                }
//            }
//            
//            if !audioManager.isConnected {
//                Text("点击配置WiFi连接")
//                    .font(.caption)
//                    .foregroundColor(.white.opacity(0.7))
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 15)
//                .fill(Color.white.opacity(0.2))
//                .overlay(
//                    RoundedRectangle(cornerRadius: 15)
//                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
//                )
//        )
//    }
//}
//
//// 录音控制面板
//struct RecordingControlPanel: View {
//    @ObservedObject var audioManager: AudioManager
//    @State private var recordingTime: TimeInterval = 0
//    @State private var timer: Timer?
//    
//    var body: some View {
//        VStack(spacing: 20) {
//            // 时间显示
//            Text(formatTime(recordingTime))
//                .font(.system(size: 48, weight: .light, design: .monospaced))
//                .foregroundColor(.white)
//            
//            // 录音按钮
//            Button(action: toggleRecording) {
//                ZStack {
//                    Circle()
//                        .fill(audioManager.isRecording ? Color.red : Color.white)
//                        .frame(width: 80, height: 80)
//                    
//                    Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
//                        .font(.system(size: 30))
//                        .foregroundColor(audioManager.isRecording ? .white : .red)
//                }
//            }
//            .disabled(!audioManager.isConnected)
//            .scaleEffect(audioManager.isRecording ? 1.1 : 1.0)
//            .animation(.easeInOut(duration: 0.2), value: audioManager.isRecording)
//            
//            // 音量控制
//            HStack {
//                Image(systemName: "speaker.wave.1")
//                    .foregroundColor(.white)
//                
//                Slider(value: $audioManager.playbackVolume, in: 0...1)
//                    .accentColor(.white)
//                
//                Image(systemName: "speaker.wave.3")
//                    .foregroundColor(.white)
//            }
//            .padding(.horizontal)
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 20)
//                .fill(Color.white.opacity(0.1))
//        )
//    }
//    
//    func toggleRecording() {
//        if audioManager.isRecording {
//            audioManager.stopRecording()
//            timer?.invalidate()
//            recordingTime = 0
//        } else {
//            audioManager.startRecording()
//            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
//                recordingTime += 0.1
//            }
//        }
//    }
//    
//    func formatTime(_ time: TimeInterval) -> String {
//        let minutes = Int(time) / 60
//        let seconds = Int(time) % 60
//        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
//        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
//    }
//}
//
//// 音频可视化视图
//struct AudioVisualizerView: View {
//    let audioLevels: [Float]
//    
//    var body: some View {
//        GeometryReader { geometry in
//            HStack(alignment: .center, spacing: 2) {
//                ForEach(0..<40) { index in
//                    RoundedRectangle(cornerRadius: 2)
//                        .fill(
//                            LinearGradient(
//                                colors: [Color.white, Color.white.opacity(0.3)],
//                                startPoint: .top,
//                                endPoint: .bottom
//                            )
//                        )
//                        .frame(
//                            width: (geometry.size.width - 80) / 40,
//                            height: CGFloat(getBarHeight(index)) * geometry.size.height
//                        )
//                }
//            }
//            .frame(maxHeight: .infinity)
//        }
//        .frame(height: 60)
//        .padding(.horizontal)
//    }
//    
//    func getBarHeight(_ index: Int) -> Float {
//        if index < audioLevels.count {
//            return audioLevels[index] * 0.8 + 0.2
//        }
//        return 0.2
//    }
//}
//
//// 录音列表视图
//struct RecordingsListView: View {
//    let recordings: [AudioRecording]
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            Text("最近录音")
//                .font(.headline)
//                .foregroundColor(.white)
//                .padding(.horizontal)
//            
//            ScrollView {
//                VStack(spacing: 10) {
//                    ForEach(recordings) { recording in
//                        RecordingRowView(recording: recording)
//                    }
//                }
//                .padding(.horizontal)
//            }
//        }
//    }
//}
//
//// 录音行视图
//struct RecordingRowView: View {
//    let recording: AudioRecording
//    @State private var isPlaying = false
//    
//    var body: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 5) {
//                Text(formatDate(recording.timestamp))
//                    .font(.caption)
//                    .foregroundColor(.white.opacity(0.7))
//                
//                Text("时长: \(formatDuration(recording.duration))")
//                    .font(.subheadline)
//                    .foregroundColor(.white)
//            }
//            
//            Spacer()
//            
//            Button(action: togglePlayback) {
//                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
//                    .font(.title2)
//                    .foregroundColor(.white)
//            }
//        }
//        .padding()
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color.white.opacity(0.15))
//        )
//    }
//    
//    func togglePlayback() {
//        isPlaying.toggle()
//        // 实现播放逻辑
//    }
//    
//    func formatDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "MM-dd HH:mm"
//        return formatter.string(from: date)
//    }
//    
//    func formatDuration(_ duration: TimeInterval) -> String {
//        let minutes = Int(duration) / 60
//        let seconds = Int(duration) % 60
//        return String(format: "%02d:%02d", minutes, seconds)
//    }
//}
//
//// WiFi配置视图
//struct WiFiConfigView: View {
//    @ObservedObject var audioManager: AudioManager
//    @Environment(\.dismiss) var dismiss
//    @State private var ssid = ""
//    @State private var password = ""
//    @State private var isConfiguring = false
//    @State private var showError = false
//    @State private var errorMessage = ""
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                LinearGradient(
//                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
//                    startPoint: .top,
//                    endPoint: .bottom
//                )
//                .ignoresSafeArea()
//                
//                VStack(spacing: 25) {
//                    // 图标
//                    Image(systemName: "wifi.circle.fill")
//                        .font(.system(size: 80))
//                        .foregroundColor(.white)
//                        .padding(.top, 40)
//                    
//                    Text("配置ESP32 WiFi")
//                        .font(.title2)
//                        .fontWeight(.bold)
//                        .foregroundColor(.white)
//                    
//                    // 输入框
//                    VStack(spacing: 15) {
//                        TextField("WiFi名称 (SSID)", text: $ssid)
//                            .textFieldStyle(CustomTextFieldStyle())
//                        
//                        SecureField("WiFi密码", text: $password)
//                            .textFieldStyle(CustomTextFieldStyle())
//                    }
//                    .padding(.horizontal)
//                    
//                    // ESP32 IP输入
//                    TextField("ESP32 IP地址", text: $audioManager.deviceIP)
//                        .textFieldStyle(CustomTextFieldStyle())
//                        .padding(.horizontal)
//                        .keyboardType(.decimalPad)
//                    
//                    // 配置按钮
//                    Button(action: configureWiFi) {
//                        HStack {
//                            if isConfiguring {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                    .scaleEffect(0.8)
//                            }
//                            Text(isConfiguring ? "配置中..." : "开始配置")
//                                .fontWeight(.semibold)
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.white)
//                        .foregroundColor(Color(hex: "667eea"))
//                        .cornerRadius(12)
//                    }
//                    .disabled(ssid.isEmpty || password.isEmpty || isConfiguring)
//                    .padding(.horizontal)
//                    
//                    // 说明文字
//                    VStack(spacing: 10) {
//                        Text("请确保手机和ESP32在同一网络")
//                            .font(.caption)
//                            .foregroundColor(.white.opacity(0.8))
//                        
//                        Text("默认AP: ESP32-Audio (密码: 12345678)")
//                            .font(.caption)
//                            .foregroundColor(.white.opacity(0.8))
//                    }
//                    
//                    Spacer()
//                }
//            }
//            .navigationTitle("WiFi配置")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("取消") {
//                        dismiss()
//                    }
//                    .foregroundColor(.white)
//                }
//            }
//            .alert("配置失败", isPresented: $showError) {
//                Button("确定", role: .cancel) { }
//            } message: {
//                Text(errorMessage)
//            }
//        }
//    }
//    
//    func configureWiFi() {
//        isConfiguring = true
//        
//        // 先尝试连接到ESP32 AP
//        Task {
//            do {
//                // 发送配置到ESP32
//                try await audioManager.configureESP32WiFi(ssid: ssid, password: password)
//                
//                // 等待ESP32重启
//                try await Task.sleep(nanoseconds: 3_000_000_000)
//                
//                // 连接WebSocket
//                audioManager.connectWebSocket()
//                
//                DispatchQueue.main.async {
//                    isConfiguring = false
//                    dismiss()
//                }
//            } catch {
//                DispatchQueue.main.async {
//                    isConfiguring = false
//                    errorMessage = error.localizedDescription
//                    showError = true
//                }
//            }
//        }
//    }
//}
//
//// 设置视图
//struct SettingsView: View {
//    @ObservedObject var audioManager: AudioManager
//    @Environment(\.dismiss) var dismiss
//    @AppStorage("autoConnect") private var autoConnect = true
//    @AppStorage("keepScreenOn") private var keepScreenOn = false
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section(header: Text("连接设置")) {
//                    HStack {
//                        Text("设备IP")
//                        Spacer()
//                        Text(audioManager.deviceIP)
//                            .foregroundColor(.gray)
//                    }
//                    
//                    Toggle("自动连接", isOn: $autoConnect)
//                    
//                    Button("重新连接") {
//                        audioManager.reconnect()
//                    }
//                    
//                    Button("清除WiFi配置") {
//                        audioManager.clearConfiguration()
//                    }
//                    .foregroundColor(.red)
//                }
//                
//                Section(header: Text("录音设置")) {
//                    Toggle("录音时保持屏幕常亮", isOn: $keepScreenOn)
//                    
//                    HStack {
//                        Text("音频质量")
//                        Spacer()
//                        Text("16kHz / 16bit")
//                            .foregroundColor(.gray)
//                    }
//                }
//                
//                Section(header: Text("关于")) {
//                    HStack {
//                        Text("版本")
//                        Spacer()
//                        Text("1.0.0")
//                            .foregroundColor(.gray)
//                    }
//                }
//            }
//            .navigationTitle("设置")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("完成") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
//
//// 自定义文本框样式
//struct CustomTextFieldStyle: TextFieldStyle {
//    func _body(configuration: TextField<Self._Label>) -> some View {
//        configuration
//            .padding()
//            .background(Color.white.opacity(0.9))
//            .cornerRadius(10)
//            .foregroundColor(.black)
//    }
//}
//
//// 音频录音数据模型
//struct AudioRecording: Identifiable {
//    let id = UUID()
//    let timestamp: Date
//    let duration: TimeInterval
//    let audioData: Data?
//    var fileURL: URL?
//}
//
//// 音频管理器
//class AudioManager: ObservableObject {
//    @Published var isConnected = false
//    @Published var isRecording = false
//    @Published var recordings: [AudioRecording] = []
//    @Published var audioLevels: [Float] = []
//    @Published var playbackVolume: Double = 0.5
//    @Published var deviceIP = "192.168.4.1"  // 默认AP模式IP
//    
//    private var webSocketTask: URLSessionWebSocketTask?
//    private var audioData = Data()
//    private var recordingStartTime: Date?
//    private var audioPlayer: AVAudioPlayer?
//    
//    init() {
//        setupAudioSession()
//    }
//    
//    func setupAudioSession() {
//        do {
//            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
//            try AVAudioSession.sharedInstance().setActive(true)
//        } catch {
//            print("Audio session setup failed: \(error)")
//        }
//    }
//    
//    func connectWebSocket() {
//        guard let url = URL(string: "ws://\(deviceIP):81/") else { return }
//        
//        let session = URLSession(configuration: .default)
//        webSocketTask = session.webSocketTask(with: url)
//        webSocketTask?.resume()
//        
//        isConnected = true
//        receiveMessage()
//    }
//    
//    func receiveMessage() {
//        webSocketTask?.receive { [weak self] result in
//            switch result {
//            case .success(let message):
//                switch message {
//                case .data(let data):
//                    self?.processAudioData(data)
//                case .string(let text):
//                    print("Received text: \(text)")
//                @unknown default:
//                    break
//                }
//                self?.receiveMessage()
//            case .failure(let error):
//                print("WebSocket error: \(error)")
//                DispatchQueue.main.async {
//                    self?.isConnected = false
//                }
//            }
//        }
//    }
//    
//    func startRecording() {
//        isRecording = true
//        audioData = Data()
//        recordingStartTime = Date()
//        
//        let message = URLSessionWebSocketTask.Message.string("START")
//        webSocketTask?.send(message) { error in
//            if let error = error {
//                print("Send error: \(error)")
//            }
//        }
//        
//        // 模拟音频级别
//        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
//            if !self.isRecording {
//                timer.invalidate()
//                return
//            }
//            
//            var levels: [Float] = []
//            for _ in 0..<40 {
//                levels.append(Float.random(in: 0.1...1.0))
//            }
//            
//            DispatchQueue.main.async {
//                self.audioLevels = levels
//            }
//        }
//    }
//    
//    func stopRecording() {
//        isRecording = false
//        
//        let message = URLSessionWebSocketTask.Message.string("STOP")
//        webSocketTask?.send(message) { error in
//            if let error = error {
//                print("Send error: \(error)")
//            }
//        }
//        
//        // 保存录音
//        if let startTime = recordingStartTime {
//            let duration = Date().timeIntervalSince(startTime)
//            let recording = AudioRecording(
//                timestamp: startTime,
//                duration: duration,
//                audioData: audioData
//            )
//            
//            DispatchQueue.main.async {
//                self.recordings.insert(recording, at: 0)
//                self.audioLevels = []
//            }
//            
//            saveAudioToFile(recording: recording)
//        }
//    }
//    
//    func processAudioData(_ data: Data) {
//        audioData.append(data)
//        
//        // 实时播放
//        playAudioBuffer(data)
//    }
//    
//    func playAudioBuffer(_ data: Data) {
//        // 这里实现实时音频播放
//        // 需要使用 Audio Queue Services 或 AVAudioEngine
//    }
//    
//    func saveAudioToFile(recording: AudioRecording) {
//        // 保存WAV文件
//        guard let audioData = recording.audioData else { return }
//        
//        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let fileName = "recording_\(recording.id.uuidString).wav"
//        let fileURL = documentsPath.appendingPathComponent(fileName)
//        
//        do {
//            try audioData.write(to: fileURL)
//            print("Audio saved to: \(fileURL)")
//        } catch {
//            print("Failed to save audio: \(error)")
//        }
//    }
//    
//    func configureESP32WiFi(ssid: String, password: String) async throws {
//        guard let url = URL(string: "http://\(deviceIP)/config") else {
//            throw ConfigError.invalidURL
//        }
//        
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
//        
//        let body = "ssid=\(ssid)&pass=\(password)"
//        request.httpBody = body.data(using: .utf8)
//        
//        let (_, response) = try await URLSession.shared.data(for: request)
//        
//        guard let httpResponse = response as? HTTPURLResponse,
//              httpResponse.statusCode == 200 else {
//            throw ConfigError.configurationFailed
//        }
//    }
//    
//    func reconnect() {
//        webSocketTask?.cancel()
//        connectWebSocket()
//    }
//    
//    func clearConfiguration() {
//        UserDefaults.standard.removeObject(forKey: "deviceIP")
//        deviceIP = "192.168.4.1"
//    }
//}
//
//enum ConfigError: Error {
//    case invalidURL
//    case configurationFailed
//}
//
//// 颜色扩展
//extension Color {
//    init(hex: String) {
//        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//        var int: UInt64 = 0
//        Scanner(string: hex).scanHexInt64(&int)
//        let a, r, g, b: UInt64
//        switch hex.count {
//        case 3:
//            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//        case 6:
//            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//        case 8:
//            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//        default:
//            (a, r, g, b) = (255, 0, 0, 0)
//        }
//        self.init(
//            .sRGB,
//            red: Double(r) / 255,
//            green: Double(g) / 255,
//            blue: Double(b) / 255,
//            opacity: Double(a) / 255
//        )
//    }
//}
//
//// App入口
//@main
//struct ESP32AudioApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}
