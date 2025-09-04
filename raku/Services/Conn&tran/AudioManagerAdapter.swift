//
//  AudioManagerAdapter.swift
//  音频管理适配器 - 使用流水线架构
//

import Foundation
import SwiftUI
import Combine

// MARK: - 音频管理器适配器
class AudioManagerAdapter: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var recordings: [AudioRecording] = []
    @Published var audioLevels: [Float] = []
    @Published var connectionStatus = "未连接"
    @Published var connectedDevice: DeviceDiscoveryService.DiscoveredDevice?
    
    // MARK: - Private Properties
    private let esp32Service: ESP32AudioService
    private let processingPipeline: AudioProcessingPipeline  // 使用新的流水线架构
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.esp32Service = ESP32AudioService()
        self.processingPipeline = AudioProcessingPipeline()
        
        setupBindings()
        esp32Service.delegate = self
        processingPipeline.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// 连接到设备
    func connectToDevice(_ device: DeviceDiscoveryService.DiscoveredDevice) {
        connectedDevice = device
        esp32Service.connectToDevice(device)
    }
    
    /// 直接连接到ESP32设备
    func connectToESP32(ip: String, port: Int) {
        // 创建一个临时设备对象用于显示
        let device = DeviceDiscoveryService.DiscoveredDevice(
            name: "ESP32设备",
            ipAddress: ip,
            port: port,
            statusPort: 8889,
            isStreaming: false
        )
        connectedDevice = device
        esp32Service.connectToESP32(ip: ip, port: port)
    }
    
    /// 断开设备连接
    func disconnectFromDevice() {
        connectedDevice = nil
        esp32Service.disconnect()
    }
    
    /// 开始录音
    func startRecording() {
        processingPipeline.startRecording()
        esp32Service.startRecording()
    }
    
    /// 停止录音
    func stopRecording() {
        esp32Service.stopRecording()
    }
    
    /// 播放录音
    func playRecording(_ recording: AudioRecording) {
        esp32Service.playRecording(recording)
    }
    
    /// 停止播放
    func stopPlaying() {
        esp32Service.stopPlaying()
    }
    
    /// 删除录音
    func deleteRecording(_ recording: AudioRecording) {
        esp32Service.deleteRecording(recording)
    }
    
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 绑定连接状态
        esp32Service.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
        
        esp32Service.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        // 绑定录音状态
        esp32Service.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        // 绑定录音列表
        esp32Service.$recordings
            .receive(on: DispatchQueue.main)
            .assign(to: \.recordings, on: self)
            .store(in: &cancellables)
        
        // 绑定音频级别
        esp32Service.$audioLevels
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioLevels, on: self)
            .store(in: &cancellables)
    }
}

// MARK: - ESP32AudioServiceDelegate
extension AudioManagerAdapter: ESP32AudioServiceDelegate {
    func esp32AudioService(_ service: ESP32AudioService, didChangeConnectionStatus isConnected: Bool, status: String) {
        // 状态已通过 @Published 属性自动同步
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didChangeRecordingStatus isRecording: Bool, duration: TimeInterval) {
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didUpdateAmplitude amplitude: Float) {
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didFinishRecording audioRecording: AudioRecording) {
        
        if let audioData = audioRecording.audioData {
            processingPipeline.processRecording(audioData: audioData, duration: audioRecording.duration)
        }
    }
    
    
    func esp32AudioService(_ service: ESP32AudioService, didEncounterError error: Error) {
        print("ESP32 音频服务错误: \(error.localizedDescription)")
    }
}

// MARK: - AudioProcessingPipelineDelegate
extension AudioManagerAdapter: AudioProcessingPipelineDelegate {
    func pipelineDidStartRecording(_ pipeline: AudioProcessingPipeline) {
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didFinishRecording audioData: Data, duration: TimeInterval) {
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didReceiveSpeechResult result: SpeechRecognitionResult) {
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didCompleteFirstStep result: FirstStepAnalysis) {
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didCompleteFinalAnalysis recording: AudioRecording) {
        
        DispatchQueue.main.async {
            self.recordings.insert(recording, at: 0)
        }
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didFailWithError error: AudioProcessingError) {
        
        // 创建失败录音记录
        let fallbackRecording = AudioRecording(
            timestamp: Date(),
            duration: 0,
            transcription: "录音处理失败: \(error.localizedDescription)",
            summary: "录音 \(recordings.count + 1) - 处理失败",
            tags: ["录音", "错误"],
            audioData: generateMockAudioData(),
            enrichedContent: nil
        )
        
        DispatchQueue.main.async {
            self.recordings.insert(fallbackRecording, at: 0)
        }
    }
    
    private func generateMockAudioData() -> Data {
        return "mock audio data for \(UUID().uuidString)".data(using: .utf8) ?? Data()
    }
}

// MARK: - 便利方法扩展
extension AudioManagerAdapter {
    /// 获取当前连接的设备名称
    var connectedDeviceName: String {
        return connectedDevice?.name ?? "未连接"
    }
    
    /// 获取录音总数
    var recordingCount: Int {
        return recordings.count
    }
    
    /// 格式化录音时长
    func formatDuration(_ duration: TimeInterval) -> String {
        return esp32Service.formatDuration(duration)
    }
    
    /// 创建 WAV 文件
    func createWAVFile(from audioData: Data) -> Data {
        return esp32Service.createWAVFile(from: audioData)
    }
}

// MARK: - 迁移说明
/*
 使用 AudioManagerAdapter 替换原有的 AudioManager：
 
 1. 在需要使用 AudioManager 的地方，将类型改为 AudioManagerAdapter：
    @StateObject private var audioManager = AudioManagerAdapter()
 
 2. 所有原有的方法调用保持不变：
    audioManager.connectToDevice(device)
    audioManager.startRecording()
    audioManager.stopRecording()
    etc.
 
 3. 所有 @Published 属性保持不变，UI 绑定无需修改：
    audioManager.isConnected
    audioManager.recordings
    audioManager.connectionStatus
    etc.
 
 这样就可以在不修改现有 UI 代码的情况下，使用新的模块化音频服务。
 */
