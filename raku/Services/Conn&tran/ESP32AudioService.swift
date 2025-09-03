//
//  ESP32AudioService.swift
//  专为 raku 项目定制的 ESP32 音频服务
//
//  这个服务整合了 WebSocket 连接和音频流处理，
//  专门为 ESP32 设备的音频录制应用而设计
//

import Foundation
import SwiftUI
import Combine

// MARK: - ESP32 音频服务协议
protocol ESP32AudioServiceDelegate: AnyObject {
    /// 连接状态改变
    func esp32AudioService(_ service: ESP32AudioService, didChangeConnectionStatus isConnected: Bool, status: String)
    
    /// 录音状态改变
    func esp32AudioService(_ service: ESP32AudioService, didChangeRecordingStatus isRecording: Bool, duration: TimeInterval)
    
    /// 音频振幅更新
    func esp32AudioService(_ service: ESP32AudioService, didUpdateAmplitude amplitude: Float)
    
    /// 录音完成
    func esp32AudioService(_ service: ESP32AudioService, didFinishRecording audioRecording: AudioRecording)
    
    /// 语音识别结果（新增）
    func esp32AudioService(_ service: ESP32AudioService, didReceiveSpeechResult result: SpeechRecognitionResult)
    
    /// 发生错误
    func esp32AudioService(_ service: ESP32AudioService, didEncounterError error: Error)
}

// MARK: - ESP32 音频服务
class ESP32AudioService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectionStatus = "未连接"
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentAmplitude: Float = 0
    @Published var audioLevels: [Float] = Array(repeating: 0, count: 50)
    @Published var recordings: [AudioRecording] = []
    
    // MARK: - Private Properties
    private var webSocketModule: WebSocketModule
    private let audioStreamModule: AudioStreamModule
    private let speechService: VolcEngineSpeechService
    private var cancellables = Set<AnyCancellable>()
    private var currentDevice: DeviceDiscoveryService.DiscoveredDevice?
    
    // MARK: - Delegate
    weak var delegate: ESP32AudioServiceDelegate?
    
    // MARK: - Initialization
    override init() {
        // 默认配置
        let wsConfig = WebSocketConfiguration(
            host: "192.168.1.100", // 默认 IP，会被实际设备 IP 覆盖
            port: 81,
            path: "/",
            timeoutInterval: 10,
            reconnectInterval: 3,
            maxReconnectAttempts: 5
        )
        
        let audioConfig = AudioStreamConfiguration(
            sampleRate: 16000,
            channels: 1,
            bitsPerSample: 16,
            enableRealTimeMonitoring: false
        )
        
        self.webSocketModule = WebSocketModule(configuration: wsConfig)
        self.audioStreamModule = AudioStreamModule(configuration: audioConfig)
        // 配置SenseVoice语音识别服务
            let senseVoiceConfig = SenseVoiceConfiguration(
                serverURL: "http://192.168.5.38:8000",  // 替换为你的服务器地址
                endpoint: "/transcribe/normal",
                timeout: 30.0
            )
            self.speechService = VolcEngineSpeechService(configuration: senseVoiceConfig)
            
        
        super.init()
        setupBindings()
        setupDelegates()
        loadMockData() // 加载一些示例数据
    }
    
    // MARK: - Public Methods
    
    /// 连接到指定设备
    func connectToDevice(_ device: DeviceDiscoveryService.DiscoveredDevice) {
        currentDevice = device
        connectToESP32(ip: device.ipAddress, port: 81)
    }
    
    /// 直接连接到ESP32设备
    func connectToESP32(ip: String, port: Int) {
        // 先断开现有连接
        disconnect()
        
        // 创建新的 WebSocket 配置
        let newConfig = WebSocketConfiguration(
            host: ip,
            port: port,
            path: "/",
            timeoutInterval: 10,
            reconnectInterval: 3,
            maxReconnectAttempts: 5
        )
        
        // 重新创建 WebSocket 模块
        webSocketModule = WebSocketModule(configuration: newConfig)
        webSocketModule.delegate = self
        
        // 重新设置绑定！这是关键
        setupBindings()
        
        // 开始连接
        webSocketModule.connect()
        
        print("正在连接到ESP32设备: \(ip):\(port)")
    }
    
    /// 连接到设备
    func connect() {
        webSocketModule.connect()
    }
    
    /// 断开连接
    func disconnect() {
        stopRecording()
        webSocketModule.disconnect()
    }
    
    /// 开始录音
    func startRecording() {
        guard isConnected else {
            delegate?.esp32AudioService(self, didEncounterError: ESP32AudioServiceError.notConnected)
            return
        }
        
        webSocketModule.sendTextMessage("START")
        audioStreamModule.startRecording()
    }
    
    /// 停止录音
    func stopRecording() {
        if isConnected {
            webSocketModule.sendTextMessage("STOP")
        }
        audioStreamModule.stopRecording()
    }
    
    /// 播放录音
    func playRecording(_ recording: AudioRecording) {
        guard let audioData = recording.audioData else { return }
        audioStreamModule.playAudioData(audioData)
    }
    
    /// 停止播放
    func stopPlaying() {
        audioStreamModule.stopPlaying()
    }
    
    /// 删除录音
    func deleteRecording(_ recording: AudioRecording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings.remove(at: index)
        }
    }
    
    /// 获取连接状态文本
    func getConnectionStatusText() -> String {
        if isConnected {
            return currentDevice?.name ?? "已连接"
        } else {
            return connectionStatus
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 清理旧的绑定
        cancellables.removeAll()
        
        // WebSocket 状态绑定
        webSocketModule.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
        
        webSocketModule.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        // 音频状态绑定
        audioStreamModule.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        audioStreamModule.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: \.recordingDuration, on: self)
            .store(in: &cancellables)
        
        audioStreamModule.$currentAmplitude
            .receive(on: DispatchQueue.main)
            .sink { [weak self] amplitude in
                self?.currentAmplitude = amplitude
                self?.updateAudioLevels(amplitude)
            }
            .store(in: &cancellables)
            
        print("ESP32AudioService: 状态绑定已重新设置")
    }
    
    private func setupDelegates() {
        webSocketModule.delegate = self
        audioStreamModule.delegate = self
        speechService.delegate = self
    }
    
    private func updateAudioLevels(_ amplitude: Float) {
        var newLevels = audioLevels
        newLevels.removeFirst()
        newLevels.append(min(amplitude * 5, 1.0)) // 放大并限制最大值
        audioLevels = newLevels
    }
    
    private func loadMockData() {
        // 创建一些示例录音数据
        let mockRecordings = [
            AudioRecording(
                timestamp: Date().addingTimeInterval(-3600),
                duration: 45.2,
                transcription: "这是第一段测试录音的转录内容，用于展示应用的基本功能。",
                summary: "测试录音 1 - 功能演示",
                tags: ["测试", "演示"],
                audioData: Data("mock audio data 1".utf8),
                keyPoints: ["展示应用基本功能", "测试录音转录效果"],
                sentiment: "neutral"
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-1800),
                duration: 62.8,
                transcription: "第二段录音内容，展示了更长的录音时间和更多的文本内容。",
                summary: "测试录音 2 - 长时间录音",
                tags: ["长录音", "测试"],
                audioData: Data("mock audio data 2".utf8),
                keyPoints: ["长时间录音功能测试", "文本内容丰富度验证"],
                sentiment: "positive"
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-300),
                duration: 28.5,
                transcription: "最新的一段录音，用于展示实时录音功能。",
                summary: "测试录音 3 - 最新录音",
                tags: ["最新", "实时"],
                audioData: Data("mock audio data 3".utf8),
                keyPoints: ["实时录音功能验证", "最新版本测试"],
                sentiment: "positive"
            )
        ]
        
        self.recordings = mockRecordings
    }
    
    /// 使用语音识别处理音频数据
    private func processAudioWithSpeechRecognition(audioData: Data, duration: TimeInterval) {
        // 将原始PCM数据转换为WAV格式
        let wavData = createWAVFile(from: audioData)
        
        // 创建临时录音记录（使用WAV格式的音频数据）
        let tempRecording = AudioRecording(
            timestamp: Date(),
            duration: duration,
            transcription: "正在识别中...",
            summary: "录音 \(recordings.count + 1) - 识别中",
            tags: ["录音", "识别中"],
            audioData: wavData,  // 使用WAV格式数据而不是原始PCM数据
            keyPoints: [],
            sentiment: nil
        )
        
        // 立即添加到录音列表中
        DispatchQueue.main.async {
            self.recordings.insert(tempRecording, at: 0)
            self.delegate?.esp32AudioService(self, didFinishRecording: tempRecording)
        }
        
        // 使用VolcEngine HTTP API进行语音识别
        print("开始使用VolcEngine API进行语音识别")
        speechService.clearResults()
        speechService.startRecognition()
        
        // 发送WAV数据进行识别
        speechService.sendAudioData(wavData)
        
        // 10秒后超时处理
        DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
            if !self.speechService.hasResults {
                print("语音识别超时，使用fallback")
                self.createFallbackRecording(audioData: wavData, duration: duration)  // 传递WAV数据
            }
            self.speechService.stopRecognition()
        }
    }
    
    /// 创建不依赖语音识别的录音记录
    private func createFallbackRecording(audioData: Data, duration: TimeInterval) {
        let fallbackRecording = AudioRecording(
            timestamp: Date(),
            duration: duration,
            transcription: "录音已保存，语音识别服务暂时不可用",
            summary: "录音 \(recordings.count) - \(formatDuration(duration))",
            tags: ["录音"],
            audioData: audioData,  // 这里的audioData已经是WAV格式
            keyPoints: [],
            sentiment: nil
        )
        
        DispatchQueue.main.async {
            if let index = self.recordings.firstIndex(where: { $0.tags.contains("识别中") }) {
                self.recordings[index] = fallbackRecording
            }
        }
    }
}

// MARK: - WebSocketModuleDelegate
extension ESP32AudioService: WebSocketModuleDelegate {
    func webSocketDidChangeConnectionStatus(_ module: WebSocketModule, isConnected: Bool, status: String) {
        delegate?.esp32AudioService(self, didChangeConnectionStatus: isConnected, status: status)
    }
    
    func webSocketDidReceiveTextMessage(_ module: WebSocketModule, message: String) {
        // 处理文本消息（如果需要）
        print("收到文本消息: \(message)")
    }
    
    func webSocketDidReceiveData(_ module: WebSocketModule, data: Data) {
        // 将接收到的音频数据传递给音频模块处理
        audioStreamModule.processReceivedAudioData(data)
    }
    
    func webSocketDidEncounterError(_ module: WebSocketModule, error: Error) {
        delegate?.esp32AudioService(self, didEncounterError: error)
    }
}

// MARK: - AudioStreamModuleDelegate
extension ESP32AudioService: AudioStreamModuleDelegate {
    func audioStreamDidStartRecording(_ module: AudioStreamModule) {
        delegate?.esp32AudioService(self, didChangeRecordingStatus: true, duration: 0)
    }
    
    func audioStreamDidStopRecording(_ module: AudioStreamModule, audioData: Data, duration: TimeInterval) {
        // 使用VolcEngine进行语音识别
        processAudioWithSpeechRecognition(audioData: audioData, duration: duration)
    }
    
    func audioStreamDidUpdateAmplitude(_ module: AudioStreamModule, amplitude: Float) {
        delegate?.esp32AudioService(self, didUpdateAmplitude: amplitude)
    }
    
    func audioStreamDidStartPlaying(_ module: AudioStreamModule) {
        // 播放状态处理（如果需要）
    }
    
    func audioStreamDidStopPlaying(_ module: AudioStreamModule) {
        // 播放结束处理（如果需要）
    }
    
    func audioStreamDidEncounterError(_ module: AudioStreamModule, error: Error) {
        delegate?.esp32AudioService(self, didEncounterError: error)
    }
}

// MARK: - VolcEngineSpeechServiceDelegate
extension ESP32AudioService: VolcEngineSpeechServiceDelegate {
    func speechService(_ service: VolcEngineSpeechService, didReceiveResult result: SpeechRecognitionResult) {
        print("ESP32AudioService 收到语音识别结果: \(result.text)")
        
        // 将语音识别结果转发给delegate（AudioManagerAdapter）
        delegate?.esp32AudioService(self, didReceiveSpeechResult: result)
        
        // 更新最新录音的转录内容
        if let latestRecording = recordings.first,
           latestRecording.tags.contains("识别中") {
            
            let updatedRecording = AudioRecording(
                timestamp: latestRecording.timestamp,
                duration: latestRecording.duration,
                transcription: result.text,
                summary: result.isFinal ? generateSummary(from: result.text) : "识别中...",
                tags: result.isFinal ? generateTags(from: result.text) : ["录音", "识别中"],
                audioData: latestRecording.audioData,  // 保持使用WAV格式的音频数据
                keyPoints: result.isFinal ? generateKeyPoints(from: result.text) : [],
                sentiment: result.isFinal ? "neutral" : nil
            )
            
            DispatchQueue.main.async {
                self.recordings[0] = updatedRecording
            }
        }
    }
    
    // 移除了 didReceiveLLMAnalysis 方法，因为LLM分析现在由外部处理
    
    func speechService(_ service: VolcEngineSpeechService, didCompleteWithError error: Error?) {
        if let error = error {
            print("语音识别出错: \(error.localizedDescription)")
            
            // 更新录音状态为识别失败
            if let latestRecording = recordings.first,
               latestRecording.tags.contains("识别中") {
                
                let failedRecording = AudioRecording(
                    timestamp: latestRecording.timestamp,
                    duration: latestRecording.duration,
                    transcription: "识别失败：\(error.localizedDescription)",
                    summary: "录音 \(recordings.count) - 识别失败",
                    tags: ["录音", "识别失败"],
                    audioData: latestRecording.audioData,  // 保持使用WAV格式的音频数据
                    keyPoints: [],
                    sentiment: nil
                )
                
                DispatchQueue.main.async {
                    self.recordings[0] = failedRecording
                }
            }
        } else {
            print("语音识别完成")
        }
    }
    
    func speechServiceDidStartRecognition(_ service: VolcEngineSpeechService) {
        print("语音识别开始")
    }
    
    func speechServiceDidStopRecognition(_ service: VolcEngineSpeechService) {
        print("语音识别停止")
    }
    
    // MARK: - 辅助方法
    
    private func generateSummary(from text: String) -> String {
        // 简单的摘要生成逻辑
        let words = text.split(separator: " ")
        if words.count <= 10 {
            return String(text.prefix(50))
        } else {
            return String(words.prefix(10).joined(separator: " ")) + "..."
        }
    }
    
    private func generateTags(from text: String) -> [String] {
        var tags = ["录音"]
        
        // 基于内容添加标签
        if text.contains("会议") || text.contains("讨论") {
            tags.append("会议")
        }
        if text.contains("电话") || text.contains("通话") {
            tags.append("电话")
        }
        if text.contains("笔记") || text.contains("记录") {
            tags.append("笔记")
        }
        if text.contains("重要") || text.contains("紧急") {
            tags.append("重要")
        }
        
        return tags
    }
    
    private func generateKeyPoints(from text: String) -> [String] {
        // 简单的关键点提取逻辑
        var keyPoints: [String] = []
        
        // 按句子分割文本
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？.!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // 提取前几个句子作为关键点
        for sentence in sentences.prefix(3) {
            if sentence.count > 5 { // 过滤太短的句子
                keyPoints.append(sentence)
            }
        }
        
        // 如果没有找到足够的关键点，使用默认值
        if keyPoints.isEmpty {
            keyPoints = ["录音内容已保存"]
        }
        
        return keyPoints
    }
}

// MARK: - 错误类型
public enum ESP32AudioServiceError: Error, LocalizedError {
    case notConnected
    case deviceNotFound
    case recordingInProgress
    case playbackInProgress
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "未连接到 ESP32 设备"
        case .deviceNotFound:
            return "未找到 ESP32 设备"
        case .recordingInProgress:
            return "录音正在进行中"
        case .playbackInProgress:
            return "音频正在播放中"
        }
    }
}

// MARK: - 便利扩展
extension ESP32AudioService {
    /// 创建 WAV 文件
    public func createWAVFile(from audioData: Data) -> Data {
        return audioStreamModule.createWAVFile(from: audioData)
    }
    
    /// 格式化录音时长
    public func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
