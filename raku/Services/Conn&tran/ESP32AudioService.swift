//
//  ESP32AudioService.swift
//  ESP32 音频服务 - 专注音频录制和播放
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
    @Published var isPlaying = false
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
        // mock数据加载由AudioManagerAdapter处理
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
    
    /// 暂停录音
    func pauseRecording() {
        guard isConnected else {
            delegate?.esp32AudioService(self, didEncounterError: ESP32AudioServiceError.notConnected)
            return
        }
        
        // ESP32可能不支持暂停，发送PAUSE命令，如果不支持则继续录音
        webSocketModule.sendTextMessage("PAUSE")
        print("⏸ 发送暂停命令到ESP32设备")
    }
    
    /// 恢复录音
    func resumeRecording() {
        guard isConnected else {
            delegate?.esp32AudioService(self, didEncounterError: ESP32AudioServiceError.notConnected)
            return
        }
        
        // ESP32恢复录音，发送RESUME命令，如果不支持则重新开始录音
        webSocketModule.sendTextMessage("RESUME")
        print("▶️ 发送恢复命令到ESP32设备")
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
    
    /// 删除录音（ESP32Service不再管理录音列表）
    func deleteRecording(_ recording: AudioRecording) {
        // 录音列表管理由AudioManagerAdapter负责
        // 这里只做清理工作（如果需要）
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
        // 不再加载mock数据，由AudioManagerAdapter统一管理
    }
    
    /// 处理录音数据
    private func processRecordedAudioData(audioData: Data, duration: TimeInterval) {
        let wavData = createWAVFile(from: audioData)
        
        let recording = AudioRecording(
            timestamp: Date(),
            duration: duration,
            transcription: "录音已保存",
            title: "录音 \(recordings.count + 1)",
            summary: "时长 \(formatDuration(duration)) 的录音记录",
            tags: ["录音"],
            audioData: wavData,
            enrichedContent: nil
        )
        
        DispatchQueue.main.async {
            // 不再向ESP32Service的recordings数组添加录音，录音管理由AudioManagerAdapter处理
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
        DispatchQueue.main.async {
            self.isPlaying = true
        }
    }
    
    func audioStreamDidStopPlaying(_ module: AudioStreamModule) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
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
        return FormatHelper.formatDuration(duration)
    }
}
