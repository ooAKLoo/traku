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
        loadMockData() // 加载一些示例数据
    }
    
    // MARK: - Public Methods
    
    /// 连接到指定设备
    func connectToDevice(_ device: DeviceDiscoveryService.DiscoveredDevice) {
        currentDevice = device
        
        // 先断开现有连接
        disconnect()
        
        // 创建新的 WebSocket 配置
        let newConfig = WebSocketConfiguration(
            host: device.ipAddress,
            port: 81, // ESP32 的 WebSocket 端口
            path: "/",
            timeoutInterval: 10,
            reconnectInterval: 3,
            maxReconnectAttempts: 5
        )
        
        // 重新创建 WebSocket 模块
        webSocketModule = WebSocketModule(configuration: newConfig)
        webSocketModule.delegate = self
        
        // 开始连接
        webSocketModule.connect()
        
        print("正在连接到设备: \(device.name) (\(device.ipAddress):81)")
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
    }
    
    private func setupDelegates() {
        webSocketModule.delegate = self
        audioStreamModule.delegate = self
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
                audioData: Data("mock audio data 1".utf8)
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-1800),
                duration: 62.8,
                transcription: "第二段录音内容，展示了更长的录音时间和更多的文本内容。",
                summary: "测试录音 2 - 长时间录音",
                tags: ["长录音", "测试"],
                audioData: Data("mock audio data 2".utf8)
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-300),
                duration: 28.5,
                transcription: "最新的一段录音，用于展示实时录音功能。",
                summary: "测试录音 3 - 最新录音",
                tags: ["最新", "实时"],
                audioData: Data("mock audio data 3".utf8)
            )
        ]
        
        self.recordings = mockRecordings
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
        // 创建新的录音记录
        let newRecording = AudioRecording(
            timestamp: Date(),
            duration: duration,
            transcription: "录音转录内容...", // 实际应用中可以集成语音识别 API
            summary: "录音 \(recordings.count + 1)",
            tags: ["录音"],
            audioData: audioData
        )
        
        DispatchQueue.main.async {
            self.recordings.insert(newRecording, at: 0)
            self.delegate?.esp32AudioService(self, didFinishRecording: newRecording)
        }
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