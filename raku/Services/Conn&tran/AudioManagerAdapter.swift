//
//  AudioManagerAdapter.swift
//  适配器模式，用于整合新的 ESP32AudioService 和现有的 AudioManager 接口
//
//  这个适配器让现有的代码可以无缝使用新的模块化服务
//

import Foundation
import SwiftUI
import Combine

// MARK: - 音频管理器适配器
class AudioManagerAdapter: ObservableObject {
    // MARK: - Published Properties (保持与原 AudioManager 兼容)
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var recordings: [AudioRecording] = []
    @Published var audioLevels: [Float] = []
    @Published var connectionStatus = "未连接"
    @Published var connectedDevice: DeviceDiscoveryService.DiscoveredDevice?
    
    // MARK: - Private Properties
    private let esp32Service: ESP32AudioService
    private let speechService = VolcEngineSpeechService()  // 保留语音识别服务
    private let twoStepLLMService = TwoStepLLMService()   // 新增两步式LLM服务
    private var cancellables = Set<AnyCancellable>()
    private var currentRecordingData = Data()
    private var recordingStartTime: Date?
    
    // MARK: - Initialization
    init() {
        self.esp32Service = ESP32AudioService()
        setupBindings()
        esp32Service.delegate = self
        speechService.delegate = self
        twoStepLLMService.delegate = self  // 设置两步式LLM服务代理
    }
    
    // MARK: - Public Methods (兼容原 AudioManager 接口)
    
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
        currentRecordingData = Data()
        recordingStartTime = Date()
        speechService.startRecognition()
        esp32Service.startRecording()
    }
    
    /// 停止录音
    func stopRecording() {
        speechService.stopRecognition()
        
        // 发送音频数据进行语音识别
        if !currentRecordingData.isEmpty {
            speechService.sendAudioData(currentRecordingData)
        }
        
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
    
    /// 加载模拟数据
    func loadMockData() {
        // ESP32AudioService 已经在初始化时加载了模拟数据
        // 这里我们直接同步数据
        recordings = esp32Service.recordings
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
        print("连接状态改变: \(isConnected ? "已连接" : "未连接") - \(status)")
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didChangeRecordingStatus isRecording: Bool, duration: TimeInterval) {
        print("录音状态改变: \(isRecording ? "录音中" : "已停止") - 时长: \(duration)秒")
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didUpdateAmplitude amplitude: Float) {
        // 音频振幅更新已通过绑定处理
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didFinishRecording audioRecording: AudioRecording) {
        print("ESP32录音完成: \(audioRecording.summary)")
        // 收集音频数据用于语音识别
        if let audioData = audioRecording.audioData {
            currentRecordingData.append(audioData)
        }
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didReceiveSpeechResult result: SpeechRecognitionResult) {
        print("AudioManagerAdapter 收到语音识别结果: \(result.text)")
        
        // 语音识别完成后，使用两步式LLM服务进行分析
        print("开始调用两步式LLM分析...")
        twoStepLLMService.analyzeText(result.text)
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didEncounterError error: Error) {
        print("ESP32 音频服务错误: \(error.localizedDescription)")
        // 可以在这里添加错误处理逻辑
    }
}

// MARK: - VolcEngineSpeechServiceDelegate
extension AudioManagerAdapter: VolcEngineSpeechServiceDelegate {
    func speechService(_ service: VolcEngineSpeechService, didReceiveResult result: SpeechRecognitionResult) {
        print("语音识别结果: \(result.text)")
        
        // 保存识别文本用于后续LLM分析
        let recognitionText = result.text
        
        // 语音识别完成后，使用两步式LLM服务进行分析
        twoStepLLMService.analyzeText(recognitionText)
    }
    
    // 移除了 didReceiveLLMAnalysis 方法，因为协议中已经没有这个方法了
    
    func speechService(_ service: VolcEngineSpeechService, didCompleteWithError error: Error?) {
        if let error = error {
            print("语音识别错误: \(error.localizedDescription)")
        }
    }
    
    func speechServiceDidStartRecognition(_ service: VolcEngineSpeechService) {
        print("语音识别已开始")
    }
    
    func speechServiceDidStopRecognition(_ service: VolcEngineSpeechService) {
        print("语音识别已停止")
    }
    
    private func generateMockAudioData() -> Data {
        return "mock audio data for \(UUID().uuidString)".data(using: .utf8) ?? Data()
    }
}

// MARK: - TwoStepLLMServiceDelegate
extension AudioManagerAdapter: TwoStepLLMServiceDelegate {
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFirstStep result: FirstStepAnalysis) {
        print("第一步完成 - 类型: \(result.thoughtType.rawValue), 标题: \(result.title)")
        if let summary = result.oneSentenceSummary {
            print("一句话总结: \(summary)")
        }
    }
    
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFinalAnalysis result: TwoStepAnalysisResult) {
        print("两步式LLM分析完成")
        print("标题: \(result.title)")
        print("类型: \(result.thoughtType.rawValue)")
        print("标签: \(result.tags.joined(separator: ", "))")
        print("辅助点: \(result.keyPoints.joined(separator: "; "))")
        
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        
        // 使用最终结果创建录音记录
        let enhancedRecording = AudioRecording(
            timestamp: result.timestamp,
            duration: duration,
            transcription: result.originalText,
            summary: result.title,  // 使用标题作为summary
            tags: result.tags,
            audioData: currentRecordingData.isEmpty ? generateMockAudioData() : currentRecordingData,
            keyPoints: result.keyPoints,
            sentiment: result.sentiment
        )
        
        // 如果文本超过150字，在keyPoints的第一项添加一句话总结
        if result.originalText.count > 150, result.summary != result.originalText {
            var enhancedKeyPoints = result.keyPoints
            enhancedKeyPoints.insert("总结: \(result.summary)", at: 0)
            
            let enhancedRecordingWithSummary = AudioRecording(
                timestamp: result.timestamp,
                duration: duration,
                transcription: result.originalText,
                summary: result.title,
                tags: result.tags,
                audioData: currentRecordingData.isEmpty ? generateMockAudioData() : currentRecordingData,
                keyPoints: enhancedKeyPoints,
                sentiment: result.sentiment
            )
            
            DispatchQueue.main.async {
                self.recordings.insert(enhancedRecordingWithSummary, at: 0)
            }
        } else {
            DispatchQueue.main.async {
                self.recordings.insert(enhancedRecording, at: 0)
            }
        }
    }
    
    func twoStepLLMService(_ service: TwoStepLLMService, didFailWithError error: Error) {
        print("两步式LLM分析失败: \(error.localizedDescription)")
        
        // 失败时创建基础录音记录
        guard let startTime = recordingStartTime else { return }
        let duration = Date().timeIntervalSince(startTime)
        
        let fallbackRecording = AudioRecording(
            timestamp: startTime,
            duration: duration,
            transcription: "录音已保存（分析失败）",
            summary: "录音 \(recordings.count + 1)",
            tags: ["录音"],
            audioData: currentRecordingData.isEmpty ? generateMockAudioData() : currentRecordingData,
            keyPoints: ["LLM分析服务暂时不可用"],
            sentiment: nil
        )
        
        DispatchQueue.main.async {
            self.recordings.insert(fallbackRecording, at: 0)
        }
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
