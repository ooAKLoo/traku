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
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.esp32Service = ESP32AudioService()
        setupBindings()
        esp32Service.delegate = self
    }
    
    // MARK: - Public Methods (兼容原 AudioManager 接口)
    
    /// 连接到设备
    func connectToDevice(_ device: DeviceDiscoveryService.DiscoveredDevice) {
        connectedDevice = device
        esp32Service.connectToDevice(device)
    }
    
    /// 断开设备连接
    func disconnectFromDevice() {
        connectedDevice = nil
        esp32Service.disconnect()
    }
    
    /// 开始录音
    func startRecording() {
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
        print("录音完成: \(audioRecording.summary)")
        // 录音列表已通过绑定自动更新
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didEncounterError error: Error) {
        print("ESP32 音频服务错误: \(error.localizedDescription)")
        // 可以在这里添加错误处理逻辑
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