//
//  AudioManagerAdapter.swift
//  音频管理适配器 - 使用统一音频输入抽象
//

import Foundation
import SwiftUI
import Combine

// MARK: - 音频管理器适配器
class AudioManagerAdapter: ObservableObject {
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordings: [AudioRecording] = []
    @Published var audioLevels: [Float] = []
    @Published var connectionStatus = "未连接"
    @Published var connectedDevice: DeviceDiscoveryService.DiscoveredDevice?
    @Published var currentInputSource: AudioInputSourceType = .phone
    
    // MARK: - Private Properties
    private let esp32Service: ESP32AudioService
    private let processingPipeline: AudioProcessingPipeline
    private let phoneRecordingManager: PhoneRecordingManager
    private let audioInputManager: AudioInputManager
    private var esp32InputSource: ESP32AudioInputSource!
    private var phoneInputSource: PhoneAudioInputSource!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.esp32Service = ESP32AudioService()
        self.processingPipeline = AudioProcessingPipeline()
        self.phoneRecordingManager = PhoneRecordingManager()
        self.audioInputManager = AudioInputManager()
        
        // 创建具体的输入源实现
        self.esp32InputSource = ESP32AudioInputSource(esp32Service: esp32Service)
        self.phoneInputSource = PhoneAudioInputSource(phoneRecordingManager: phoneRecordingManager)
        
        setupBindings()
        setupAudioInputSources()
        processingPipeline.delegate = self
        
        // 从数据库加载录音数据
        print("🚀 AudioManagerAdapter初始化: 开始加载数据库中的录音记录")
        loadRecordingsFromDatabase()
        
        // 加载mock数据（仅在DEBUG模式下）
        #if DEBUG
        if recordings.isEmpty {
            loadMockData()
        }
        #endif
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
    
    /// 切换音频输入源
    func switchToInputSource(_ sourceType: AudioInputSourceType) {
        currentInputSource = sourceType
        
        switch sourceType {
        case .esp32:
            audioInputManager.setActiveSource(esp32InputSource)
        case .phone:
            audioInputManager.setActiveSource(phoneInputSource)
        case .file:
            // 文件输入源暂未实现
            break
        }
    }
    
    /// 开始录音（统一接口）
    func startRecording() {
        // 根据当前输入源类型启动相应的流水线
        switch currentInputSource {
        case .esp32:
            processingPipeline.startRecording()
        case .phone:
            processingPipeline.startPhoneRecording()
        case .file:
            break
        }
        
        audioInputManager.startRecording()
    }
    
    /// 开始ESP32录音（向后兼容）
    func startESP32Recording() {
        switchToInputSource(.esp32)
        startRecording()
    }
    
    /// 开始手机录音（向后兼容）
    func startPhoneRecording() {
        print("📱🎬 AudioManagerAdapter: 开始手机录音流程")
        switchToInputSource(.phone)
        startRecording()
        print("📱🎬 AudioManagerAdapter: 手机录音流程启动完成")
    }
    
    /// 停止录音
    func stopRecording() {
        processingPipeline.stopRecording()
        audioInputManager.stopRecording()
    }
    
    /// 暂停录音
    func pauseRecording() {
        processingPipeline.pauseRecording()
        audioInputManager.pauseRecording()
    }
    
    /// 恢复录音
    func resumeRecording() {
        processingPipeline.resumeRecording()
        audioInputManager.resumeRecording()
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
        if DatabaseManager.shared.deleteRecording(id: recording.id) {
            DispatchQueue.main.async {
                if let index = self.recordings.firstIndex(where: { $0.id == recording.id }) {
                    self.recordings.remove(at: index)
                }
            }
        }
        // 通知ESP32Service做清理工作（如果需要）
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
        
        // 绑定音频输入管理器的录音状态
        audioInputManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        // 绑定音频输入管理器的暂停状态
        audioInputManager.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPaused, on: self)
            .store(in: &cancellables)
        
        // 绑定音频输入管理器的音频级别
        audioInputManager.$currentAmplitude
            .map { [$0] }
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioLevels, on: self)
            .store(in: &cancellables)
    }
    
    private func setupAudioInputSources() {
        // 设置ESP32输入源的代理
        esp32Service.delegate = esp32InputSource
        
        // 设置手机输入源的代理
        phoneRecordingManager.delegate = phoneInputSource
        
        // 将输入源添加到管理器
        audioInputManager.availableSources = [esp32InputSource, phoneInputSource]
        
        // 设置音频输入管理器的代理
        audioInputManager.delegate = self
        
        // 默认使用手机录音
        audioInputManager.setActiveSource(phoneInputSource)
    }
}

// MARK: - AudioInputManagerDelegate
extension AudioManagerAdapter: AudioInputManagerDelegate {
    func audioInputManager(_ manager: AudioInputManager, didStartRecording sourceType: AudioInputSourceType) {
        print("🎬 开始录音，来源: \(sourceType.displayName)")
    }
    
    func audioInputManager(_ manager: AudioInputManager, didFinishRecording result: AudioInputResult) {
        print("🎯 录音完成，来源: \(result.source.displayName), 时长: \(result.duration)秒")
        
        // 将音频数据传递给处理流水线
        processingPipeline.processRecording(audioData: result.audioData, duration: result.duration)
    }
    
    func audioInputManager(_ manager: AudioInputManager, didUpdateAmplitude amplitude: Float) {
        // 音频级别更新已通过 @Published 属性自动同步
    }
    
    func audioInputManager(_ manager: AudioInputManager, didEncounterError error: Error) {
        print("❌ 音频输入错误: \(error.localizedDescription)")
    }
}

// MARK: - AudioProcessingPipelineDelegate
extension AudioManagerAdapter: AudioProcessingPipelineDelegate {
    func pipelineDidStartRecording(_ pipeline: AudioProcessingPipeline) {
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didFinishRecording audioData: Data, duration: TimeInterval) {
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didCreateInitialRecording recording: AudioRecording) {
        print("💾 AudioManagerAdapter: 尝试保存初始录音记录，ID: \(recording.id)")
        
        
        if DatabaseManager.shared.saveOrUpdateRecording(recording) {
            print("✅ 数据库保存成功，更新UI")
            DispatchQueue.main.async {
                // 检查是否已存在相同ID的记录，避免重复
                if !self.recordings.contains(where: { $0.id == recording.id }) {
                    self.recordings.insert(recording, at: 0)
                    print("📱 UI已更新，当前录音总数: \(self.recordings.count)")
                } else {
                    print("📱 UI中已存在该录音，跳过插入")
                }
            }
        } else {
            print("❌ 初始录音数据库保存失败，但继续处理流程")
            // 即使数据库保存失败，也要添加到UI中，以便后续更新能找到记录
            DispatchQueue.main.async {
                if !self.recordings.contains(where: { $0.id == recording.id }) {
                    self.recordings.insert(recording, at: 0)
                    print("📱 UI已添加初始记录（数据库保存失败），当前录音总数: \(self.recordings.count)")
                } else {
                    print("📱 UI中已存在该录音，跳过插入")
                }
            }
        }
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didReceiveSpeechResult result: SpeechRecognitionResult) {
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didCompleteFirstStep result: FirstStepAnalysis) {
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didCompleteFinalAnalysis recording: AudioRecording) {
        print("🎯 AudioManagerAdapter: 接收到最终分析结果，ID: \(recording.id)")
        
        // 保存完整的录音记录到数据库 (DatabaseManager.saveRecording 内部会检查是否存在并自动调用 updateRecording)
        if DatabaseManager.shared.saveOrUpdateRecording(recording) {
            print("✅ 最终录音保存/更新到数据库成功")
        } else {
            print("❌ 最终录音数据库保存/更新失败")
        }
        
        // 更新UI
        DispatchQueue.main.async {
            // 查找并更新相同ID的记录
            if let existingIndex = self.recordings.firstIndex(where: { $0.id == recording.id }) {
                print("🔄 找到现有记录，位置: \(existingIndex)，更新内容")
                print("🔍 更新前转录内容: \(self.recordings[existingIndex].transcription)")
                print("🔍 更新后转录内容: \(recording.transcription)")
                
                // 强制触发SwiftUI更新：先移除再插入
                let oldRecording = self.recordings.remove(at: existingIndex)
                self.recordings.insert(recording, at: existingIndex)
                
                // 额外的强制更新方法：触发整个数组的变化通知
                self.objectWillChange.send()
                
                print("📱 UI强制更新完成，当前总数: \(self.recordings.count)")
                print("🔍 验证更新结果: \(self.recordings[existingIndex].transcription)")
                
                // 额外验证：等待一个RunLoop后再次检查
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let verifyIndex = self.recordings.firstIndex(where: { $0.id == recording.id }) {
                        print("🔍 延迟验证UI状态 - 位置: \(verifyIndex), 转录: \(self.recordings[verifyIndex].transcription)")
                    }
                }
            } else {
                print("⚠️ 未找到对应ID的记录，添加新记录")
                print("🔍 当前recordings中的ID列表: \(self.recordings.map { $0.id })")
                print("🔍 要查找的ID: \(recording.id)")
                self.recordings.insert(recording, at: 0)
                print("📱 已插入新记录，当前总数: \(self.recordings.count)")
            }
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
        
        if DatabaseManager.shared.saveRecording(fallbackRecording) {
            DispatchQueue.main.async {
                self.recordings.insert(fallbackRecording, at: 0)
            }
        }
    }
    
    private func generateMockAudioData() -> Data {
        return MockDataService.shared.generateMockAudioData()
    }
    
    /// 从数据库加载录音数据
    private func loadRecordingsFromDatabase() {
        print("🔍 AudioManagerAdapter: 开始从数据库加载录音数据...")
        DispatchQueue.global(qos: .background).async {
            let loadedRecordings = DatabaseManager.shared.loadRecordings()
            print("🔍 从数据库加载了 \(loadedRecordings.count) 条录音记录:")
            for (index, recording) in loadedRecordings.enumerated() {
                print("  \(index + 1). ID: \(recording.id.uuidString.prefix(8))..., 时间: \(recording.timestamp), 转录: \(recording.transcription.prefix(30))...")
            }
            DispatchQueue.main.async {
                print("🔍 更新UI，设置 \(loadedRecordings.count) 条录音到recordings数组")
                self.recordings = loadedRecordings
                print("🔍 UI更新完成，当前recordings数组包含 \(self.recordings.count) 条记录")
            }
        }
    }
    
    /// 加载mock数据
    private func loadMockData() {
        #if DEBUG
        DispatchQueue.main.async {
            self.recordings = MockDataService.shared.getMockRecordings()
        }
        #endif
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
    
    /// 获取当前输入源名称
    var currentInputSourceName: String {
        return currentInputSource.displayName
    }
    
    /// 获取可用输入源列表
    var availableInputSources: [AudioInputSourceType] {
        return audioInputManager.availableSources.map { $0.sourceType }
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
 AudioManagerAdapter 现在使用统一音频输入抽象：
 
 1. 新增功能：
    - switchToInputSource(_ sourceType: AudioInputSourceType) // 切换输入源
    - currentInputSourceName // 获取当前输入源名称
    - availableInputSources // 获取可用输入源列表
 
 2. 向后兼容的方法：
    - startPhoneRecording() // 自动切换到手机录音并开始
    - startESP32Recording() // 自动切换到ESP32录音并开始
    - startRecording() // 使用当前输入源开始录音
 
 3. 统一接口：
    - 上层代码不再需要关心具体的录音来源
    - ASR和数据库存储只需要处理统一的音频文件格式
    - 所有输入源的音频数据都通过相同的处理流水线
 
 4. 使用示例：
    // 切换到ESP32录音
    audioManager.switchToInputSource(.esp32)
    audioManager.startRecording()
    
    // 切换到手机录音
    audioManager.switchToInputSource(.phone)
    audioManager.startRecording()
    
    // 或者直接使用便利方法
    audioManager.startPhoneRecording()
    audioManager.startESP32Recording()
 */
