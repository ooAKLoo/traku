//
//  ESP32AudioService.swift
//  专为 raku 项目定制的 ESP32 音频服务
//
//  修复版：解决语音识别超时和网络请求被取消的问题
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
        
        
        super.init()
        setupBindings()
        setupDelegates()
        loadMockData()
    }
    
    deinit {
        // Cleanup resources
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
        
        // 重新设置绑定
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
    }
    
    private func updateAudioLevels(_ amplitude: Float) {
        var newLevels = audioLevels
        newLevels.removeFirst()
        newLevels.append(min(amplitude * 5, 1.0))
        audioLevels = newLevels
    }
    
    private func loadMockData() {
        // 保持原有的mock数据代码不变
        let mockRecordings = [
            AudioRecording(
                timestamp: Date().addingTimeInterval(-3600),
                duration: 45.2,
                transcription: "这是第一段测试录音的转录内容，用于展示应用的基本功能。",
                summary: "测试录音 1 - 功能演示",
                tags: ["测试", "演示"],
                audioData: Data("mock audio data 1".utf8),
                enrichedContent: "这是第一段录音的增强内容"
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-1800),
                duration: 62.8,
                transcription: "第二段录音内容，展示了更长的录音时间和更多的文本内容。",
                summary: "测试录音 2 - 长时间录音",
                tags: ["长录音", "测试"],
                audioData: Data("mock audio data 2".utf8),
                enrichedContent: "这是第二段录音的增强内容"
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-300),
                duration: 28.5,
                transcription: "嗯，结合大道质简，如何理解真经一句话，假经万卷书。",
                summary: "理解真经与假经",
                tags: ["真经", "假经"],
                audioData: Data("mock audio data 3".utf8),
                enrichedContent: """
## 🤔 核心问题
> 如何理解"大道质简"下"真经一句话，假经万卷书"的本质差异？

## 🔍 逻辑梳理

### 前提
> 大道本质是简洁、直指核心的

### 推理过程
1. **第一步推理**  
> 真经因契合大道本质，故以简洁形式承载核心

2. **第二步推理**  
> 假经因偏离本质，需用大量内容堆砌以"显得完整"

3. **第三步推理**  
> 本质差异：真经重核心，假经重形式冗余

### 综合
> 真经以简显真，假经以繁失真，核心在是否契合大道本质

## 👁️ 多维视角
- **视角A**：从内容与形式关系看，内容价值取决于是否触及本质  
- **视角B**：从认知规律看，认知深化常伴随冗余信息的剥离  
- **视角C**：从真实与虚假标准看，虚假知识需依赖冗余掩盖核心缺失  

## 💎 关键洞察
1. **洞察一**："简"是本质的外在体现，"繁"是偏离的内在表现  
2. **洞察二**：真正核心知识往往简洁，冗余多为非本质信息的堆砌  

## 📝 思考总结
> 理解此句需区分"形式简洁"与"本质真实"，警惕冗余信息对核心的遮蔽
"""
            )
        ]
        
        self.recordings = mockRecordings
    }
    
    /// 处理录音数据（移除直接语音识别）
    private func processRecordedAudioData(audioData: Data, duration: TimeInterval) {
        // 将原始PCM数据转换为WAV格式
        let wavData = createWAVFile(from: audioData)
        
        // 直接创建录音记录，不进行语音识别
        let recording = AudioRecording(
            timestamp: Date(),
            duration: duration,
            transcription: "录音已保存",
            summary: "录音 \(recordings.count + 1) - \(formatDuration(duration))",
            tags: ["录音"],
            audioData: wavData,
            enrichedContent: nil
        )
        
        DispatchQueue.main.async {
            self.recordings.insert(recording, at: 0)
            self.delegate?.esp32AudioService(self, didFinishRecording: recording)
        }
    }
    
}

// MARK: - WebSocketModuleDelegate
extension ESP32AudioService: WebSocketModuleDelegate {
    func webSocketDidChangeConnectionStatus(_ module: WebSocketModule, isConnected: Bool, status: String) {
        delegate?.esp32AudioService(self, didChangeConnectionStatus: isConnected, status: status)
    }
    
    func webSocketDidReceiveTextMessage(_ module: WebSocketModule, message: String) {
        print("收到文本消息: \(message)")
    }
    
    func webSocketDidReceiveData(_ module: WebSocketModule, data: Data) {
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
        processRecordedAudioData(audioData: audioData, duration: duration)
    }
    
    func audioStreamDidUpdateAmplitude(_ module: AudioStreamModule, amplitude: Float) {
        delegate?.esp32AudioService(self, didUpdateAmplitude: amplitude)
    }
    
    func audioStreamDidStartPlaying(_ module: AudioStreamModule) {
        // 播放状态处理
    }
    
    func audioStreamDidStopPlaying(_ module: AudioStreamModule) {
        // 播放结束处理
    }
    
    func audioStreamDidEncounterError(_ module: AudioStreamModule, error: Error) {
        delegate?.esp32AudioService(self, didEncounterError: error)
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
