import SwiftUI
import AVFoundation
import Combine

// MARK: - WebSocket管理器
class WebSocketManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionStatus = "未连接"
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private let baseURL: String
    
    init(baseURL: String) {
        self.baseURL = baseURL
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }
    
    func connect() {
        guard let url = URL(string: "ws://\(baseURL):81/") else {
            connectionStatus = "URL无效"
            return
        }
        
        disconnect()
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        connectionStatus = "连接中..."
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionStatus = "未连接"
    }
    
    func sendMessage(_ message: String) {
        guard isConnected else { return }
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("发送消息错误: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    // 处理接收到的音频数据
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .audioDataReceived,
                            object: nil,
                            userInfo: ["data": data]
                        )
                    }
                case .string(_):
                    break
                @unknown default:
                    break
                }
                self?.receiveMessage()
                
            case .failure(let error):
                print("接收消息错误: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionStatus = "连接断开"
                }
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "已连接"
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = "连接关闭"
        }
    }
}

// MARK: - 音频管理器
class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingTime: TimeInterval = 0
    @Published var recordings: [AudioRecording] = []
    @Published var currentAmplitude: Float = 0
    @Published var playingRecordingId: UUID?
    @Published var isMonitoring = false  // 默认关闭实时监听
    
    private var audioPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioData = Data()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private let audioSession = AVAudioSession.sharedInstance()
    
    override init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    private func setupAudioSession() {
        do {
            // 设置音频会话类别，支持扬声器播放
            try audioSession.setCategory(.playAndRecord,
                                        mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // 设置音频路由到扬声器
            try audioSession.overrideOutputAudioPort(.speaker)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        // 只在需要时初始化音频引擎
        guard audioEngine == nil else { return }
        
        do {
            audioEngine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            
            guard let engine = audioEngine,
                  let node = playerNode else { return }
            
            engine.attach(node)
            
            // 使用标准格式，让系统自动转换
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            
            try engine.start()
            node.play()
            
            print("音频引擎已启动，格式: \(format)")
        } catch {
            print("音频引擎启动失败: \(error)")
            audioEngine = nil
            playerNode = nil
        }
    }
    
    private func stopAudioEngine() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioData),
            name: .audioDataReceived,
            object: nil
        )
    }
    
    @objc private func handleAudioData(_ notification: Notification) {
        guard let data = notification.userInfo?["data"] as? Data else { return }
        
        if isRecording {
            // 保存数据用于录音文件
            audioData.append(data)
            
            // 将数据转换为Int16数组
            let int16Array = data.withUnsafeBytes { ptr in
                ptr.bindMemory(to: Int16.self)
            }
            
            // 计算音频振幅用于可视化
            var sum: Float = 0
            for sample in int16Array {
                let floatSample = Float(sample) / 32768.0
                sum += floatSample * floatSample
            }
            
            DispatchQueue.main.async {
                self.currentAmplitude = sqrt(sum / Float(int16Array.count))
            }
            
            // 实时播放（监听功能）- 简化版本，不使用AVAudioEngine
            // 如果需要实时监听，可以考虑使用其他方法
        }
    }
    
    func toggleMonitoring() {
        isMonitoring.toggle()
        
        if isMonitoring && isRecording {
            setupAudioEngine()
        } else if !isMonitoring {
            stopAudioEngine()
        }
    }
    
    func startRecording(webSocket: WebSocketManager) {
        audioData = Data()
        isRecording = true
        recordingStartTime = Date()
        
        webSocket.sendMessage("START")
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let startTime = self.recordingStartTime {
                self.recordingTime = Date().timeIntervalSince(startTime)
            }
        }
        
        // 如果开启了监听，启动音频引擎
        if isMonitoring {
            setupAudioEngine()
        }
    }
    
    func stopRecording(webSocket: WebSocketManager) {
        guard isRecording else { return }
        
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        webSocket.sendMessage("STOP")
        
        // 停止音频引擎
        stopAudioEngine()
        
        // 保存录音
        if !audioData.isEmpty {
            let recording = saveRecording()
            recordings.insert(recording, at: 0)
        }
        
        recordingTime = 0
        currentAmplitude = 0
    }
    
    private func saveRecording() -> AudioRecording {
        let wavData = createWAVFile(from: audioData)
        let fileName = "recording_\(Date().timeIntervalSince1970).wav"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try wavData.write(to: fileURL)
            print("录音已保存: \(fileURL.path)")
            print("文件大小: \(wavData.count) bytes")
            
            // 验证文件
            if let testPlayer = try? AVAudioPlayer(contentsOf: fileURL) {
                print("文件验证成功，时长: \(testPlayer.duration)秒")
            }
        } catch {
            print("保存录音失败: \(error)")
        }
        
        return AudioRecording(
            id: UUID(),
            name: "录音 \(recordings.count + 1)",
            date: Date(),
            duration: recordingTime,
            fileURL: fileURL,
            fileSize: wavData.count
        )
    }
    
    private func createWAVFile(from audioData: Data) -> Data {
        var wavData = Data()
        
        // WAV文件参数
        let sampleRate: UInt32 = 16000
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let dataSize = UInt32(audioData.count)
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        
        // RIFF chunk
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(UInt32(36 + dataSize).littleEndianData)
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(UInt32(16).littleEndianData) // fmt chunk size
        wavData.append(UInt16(1).littleEndianData) // PCM format
        wavData.append(channels.littleEndianData) // 声道数
        wavData.append(sampleRate.littleEndianData) // 采样率
        wavData.append(byteRate.littleEndianData) // 字节率
        wavData.append(blockAlign.littleEndianData) // 块对齐
        wavData.append(bitsPerSample.littleEndianData) // 位深度
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(dataSize.littleEndianData)
        wavData.append(audioData)
        
        print("创建WAV文件 - 采样率: \(sampleRate), 数据大小: \(dataSize), 总大小: \(wavData.count)")
        
        return wavData
    }
    
    func playRecording(_ recording: AudioRecording) {
        // 如果正在播放同一个录音，则停止
        if isPlaying && playingRecordingId == recording.id {
            stopPlaying()
            return
        }
        
        // 停止当前播放
        stopPlaying()
        
        do {
            // 确保音频会话激活
            try audioSession.setActive(true)
            
            // 创建音频播放器
            audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            
            // 开始播放
            if audioPlayer?.play() == true {
                isPlaying = true
                playingRecordingId = recording.id
                print("开始播放: \(recording.name), 时长: \(audioPlayer?.duration ?? 0)秒")
            } else {
                print("播放失败")
            }
        } catch {
            print("播放错误: \(error.localizedDescription)")
            print("文件路径: \(recording.fileURL)")
            
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                print("文件存在，大小: \(recording.fileSize) bytes")
            } else {
                print("文件不存在！")
            }
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playingRecordingId = nil
    }
    
    func deleteRecording(_ recording: AudioRecording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            try? FileManager.default.removeItem(at: recording.fileURL)
            recordings.remove(at: index)
        }
    }
    
    func setMonitorVolume(_ volume: Float) {
        audioEngine?.mainMixerNode.outputVolume = volume
    }
    
    func shareRecording(_ recording: AudioRecording) -> URL {
        return recording.fileURL
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playingRecordingId = nil
            print("播放完成: \(flag ? "成功" : "失败")")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("音频解码错误: \(error?.localizedDescription ?? "未知错误")")
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playingRecordingId = nil
        }
    }
}

// MARK: - 数据模型
struct AudioRecording: Identifiable {
    let id: UUID
    let name: String
    let date: Date
    let duration: TimeInterval
    let fileURL: URL
    let fileSize: Int
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedSize: String {
        let kb = Double(fileSize) / 1024
        return String(format: "%.1f KB", kb)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var webSocket: WebSocketManager
    @StateObject private var audioManager = AudioManager()
    @State private var ipAddress = "192.168.5.43"
    @State private var showingSettings = false
    @State private var showingShareSheet = false
    @State private var sharingURL: URL?
    
    init() {
        _webSocket = StateObject(wrappedValue: WebSocketManager(baseURL: UserDefaults.standard.string(forKey: "esp32_ip") ?? "192.168.5.43"))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 连接状态栏
                ConnectionStatusBar(webSocket: webSocket)
                
                // 录音控制面板
                RecordingControlPanel(
                    webSocket: webSocket,
                    audioManager: audioManager
                )
                
                // 音频可视化
                AudioVisualizerView(amplitude: audioManager.currentAmplitude)
                    .frame(height: 100)
                    .padding()
                
                // 录音列表
                RecordingsList(
                    audioManager: audioManager,
                    onShare: { recording in
                        sharingURL = audioManager.shareRecording(recording)
                        showingShareSheet = true
                    }
                )
                
                Spacer()
            }
            .navigationTitle("ESP32 音频录制")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(ipAddress: $ipAddress, webSocket: webSocket)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = sharingURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
}

// MARK: - 连接状态栏
struct ConnectionStatusBar: View {
    @ObservedObject var webSocket: WebSocketManager
    
    var body: some View {
        HStack {
            Circle()
                .fill(webSocket.isConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            Text(webSocket.connectionStatus)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                if webSocket.isConnected {
                    webSocket.disconnect()
                } else {
                    webSocket.connect()
                }
            }) {
                Text(webSocket.isConnected ? "断开" : "连接")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(webSocket.isConnected ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - 录音控制面板
struct RecordingControlPanel: View {
    @ObservedObject var webSocket: WebSocketManager
    @ObservedObject var audioManager: AudioManager
    @State private var monitorVolume: Float = 0.5
    
    var body: some View {
        VStack(spacing: 20) {
            // 计时器
            Text(formatTime(audioManager.recordingTime))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(audioManager.isRecording ? .red : .primary)
            
            // 录音按钮
            Button(action: {
                if audioManager.isRecording {
                    audioManager.stopRecording(webSocket: webSocket)
                } else {
                    audioManager.startRecording(webSocket: webSocket)
                }
            }) {
                ZStack {
                    Circle()
                        .fill(audioManager.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 35))
                        .foregroundColor(.white)
                }
            }
            .disabled(!webSocket.isConnected)
            .scaleEffect(audioManager.isRecording ? 1.1 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: audioManager.isRecording)
        }
        .padding()
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 音频可视化视图
struct AudioVisualizerView: View {
    let amplitude: Float
    @State private var bars: [CGFloat] = Array(repeating: 0.2, count: 30)
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<bars.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(height: geometry.size.height * bars[index])
                        .animation(.easeInOut(duration: 0.1), value: bars[index])
                }
            }
        }
        .onChange(of: amplitude) { newValue in
            updateBars(amplitude: newValue)
        }
    }
    
    private func updateBars(amplitude: Float) {
        var newBars = bars
        newBars.removeFirst()
        newBars.append(CGFloat(amplitude) * 5)
        bars = newBars
    }
}

// MARK: - 录音列表
struct RecordingsList: View {
    @ObservedObject var audioManager: AudioManager
    let onShare: (AudioRecording) -> Void
    
    var body: some View {
        List {
            ForEach(audioManager.recordings) { recording in
                RecordingRow(
                    recording: recording,
                    audioManager: audioManager,
                    onShare: onShare
                )
            }
            .onDelete { indexSet in
                for index in indexSet {
                    audioManager.deleteRecording(audioManager.recordings[index])
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - 录音行
struct RecordingRow: View {
    let recording: AudioRecording
    @ObservedObject var audioManager: AudioManager
    let onShare: (AudioRecording) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name)
                    .font(.headline)
                HStack {
                    Text(recording.formattedDuration)
                    Text("•")
                    Text(recording.formattedSize)
                    Text("•")
                    Text(recording.formattedDate)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    audioManager.playRecording(recording)
                }) {
                    Image(systemName: audioManager.isPlaying && audioManager.playingRecordingId == recording.id ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    onShare(recording)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @Binding var ipAddress: String
    @ObservedObject var webSocket: WebSocketManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ESP32 设置")) {
                    HStack {
                        Text("IP 地址")
                        Spacer()
                        TextField("192.168.5.43", text: $ipAddress)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 150)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("说明")) {
                    Text("1. 确保iPhone和ESP32在同一WiFi网络")
                    Text("2. 输入ESP32的IP地址")
                    Text("3. 返回主界面点击连接")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        UserDefaults.standard.set(ipAddress, forKey: "esp32_ip")
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 分享表单
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 扩展
// 注意：扩展已移动到 DataExtensions.swift 文件中

// MARK: - App入口
struct ESP32AudioApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// 在Info.plist中添加以下权限：
// Privacy - Microphone Usage Description: 需要麦克风权限来录制音频
// App Transport Security Settings > Allow Arbitrary Loads: YES (用于WebSocket连接)
