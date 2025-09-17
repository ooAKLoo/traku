//
//  AudioRecordingService.swift
//  raku - 统一音频录制服务
//
//  重构说明：
//  - 替代原有的AudioManagerAdapter
//  - 简化架构，职责清晰
//  - 提供统一的音频录制管理接口
//

import Foundation
import Combine
import SwiftUI
import AVFoundation

// MARK: - 音频录制服务
@MainActor
class AudioRecordingService: NSObject, ObservableObject {
    
    // MARK: - 发布属性
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var isPlaying: Bool = false
    @Published var isConnected: Bool = false
    @Published var currentRecordingTime: TimeInterval = 0
    @Published var currentAmplitude: Float = 0
    @Published var activeSourceType: AudioSourceType = .phone
    @Published var connectionStatus: String = "未连接"
    @Published var connectedDevice: ESP32Recorder.ESP32Device?
    @Published var recordings: [AudioRecording] = []
    @Published var audioLevels: [Float] = []
    
    // MARK: - 录音器实例
    private let phoneRecorder: PhoneRecorder
    private let esp32Recorder: ESP32Recorder
    private let processingPipeline: AudioProcessingPipeline
    
    // 当前活跃的录音器
    private var currentRecorder: AudioRecorder? {
        switch activeSourceType {
        case .phone: return phoneRecorder
        case .esp32: return esp32Recorder
        }
    }
    
    // MARK: - 事件回调
    var onRecordingFinished: ((AudioRecordingResult) -> Void)?
    var onRecordingCancelled: (() -> Void)?
    var onRecordingError: ((Error) -> Void)?
    
    // MARK: - 私有属性
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - 初始化
    init(skipDatabaseLoad: Bool = false) {
        self.phoneRecorder = PhoneRecorder()
        self.esp32Recorder = ESP32Recorder()
        self.processingPipeline = AudioProcessingPipeline()
        
        super.init()
        
        setupRecorderCallbacks()
        observeRecorderStates()
        setupProcessingPipeline()
        
        // 从数据库加载录音数据（可跳过，用于预览/单元测试）
        if !skipDatabaseLoad {
            loadRecordingsFromDatabase()
            
            // 加载mock数据（仅在DEBUG模式下，且数据库为空时）
            #if DEBUG
            if recordings.isEmpty {
                loadMockData()
            }
            #endif
        }
    }
    
    // MARK: - 公共接口
    
    /// 切换音频源
    func switchToSource(_ sourceType: AudioSourceType) async throws {
        // 如果正在录音，先停止
        if isRecording {
            _ = await stopRecording()
        }
        
        activeSourceType = sourceType
        
        // 验证新音频源是否可用
        guard currentRecorder?.isAvailable == true else {
            throw AudioRecordingError.sourceNotAvailable
        }
    }
    
    /// 连接ESP32设备
    func connectToESP32(device: ESP32Recorder.ESP32Device) async throws {
        try await esp32Recorder.connect(to: device)
        activeSourceType = .esp32
    }
    
    /// 断开ESP32连接
    func disconnectESP32() async {
        await esp32Recorder.disconnect()
        if activeSourceType == .esp32 {
            activeSourceType = .phone
        }
    }
    
    /// 开始录音
    func startRecording() async throws {
        guard let recorder = currentRecorder else {
            throw AudioRecordingError.sourceNotAvailable
        }
        
        guard !isRecording else {
            throw AudioRecordingError.alreadyRecording
        }
        
        try await recorder.startRecording()
        
        // 启动计时器
        recordingStartTime = Date()
        startRecordingTimer()
    }
    
    /// 停止录音
    func stopRecording() async -> AudioRecordingResult? {
        guard let recorder = currentRecorder else { return nil }
        
        stopRecordingTimer()
        let result = await recorder.stopRecording()
        
        // 触发音频处理流水线
        if let result = result {
            await MainActor.run {
                // 开始处理完成的录音
                print("🔄 开始处理录音结果，数据大小: \(result.audioData.count / 1024) KB")
                processingPipeline.startPhoneRecording()  // 使用手机录音处理流程
                processingPipeline.processRecording(audioData: result.audioData, duration: result.duration)
            }
        }
        
        return result
    }
    
    /// 取消录音
    func cancelRecording() async {
        guard let recorder = currentRecorder else { return }
        
        stopRecordingTimer()
        await recorder.cancelRecording()
        
        // 取消音频处理流水线
        await MainActor.run {
            processingPipeline.cancelRecording()
        }
    }
    
    /// 暂停录音
    func pauseRecording() async throws {
        guard let recorder = currentRecorder else {
            throw AudioRecordingError.sourceNotAvailable
        }
        
        try await recorder.pauseRecording()
    }
    
    /// 恢复录音
    func resumeRecording() async throws {
        guard let recorder = currentRecorder else {
            throw AudioRecordingError.sourceNotAvailable
        }
        
        try await recorder.resumeRecording()
    }
    
    // MARK: - 兼容性接口（与AudioManagerAdapter保持一致）
    
    /// 开始手机录音（向后兼容）
    func startPhoneRecording() async throws {
        try await switchToSource(.phone)
        try await startRecording()
    }
    
    /// 开始ESP32录音（向后兼容）
    func startESP32Recording() async throws {
        try await switchToSource(.esp32)
        try await startRecording()
    }
    
    /// 连接到设备（兼容旧接口）
    func connectToDevice(_ device: ESP32Recorder.ESP32Device) async throws {
        try await connectToESP32(device: device)
    }
    
    /// 断开设备连接
    func disconnectFromDevice() async {
        await disconnectESP32()
    }
    
    // MARK: - 录音管理
    
    /// 播放录音
    func playRecording(_ recording: AudioRecording) {
        // 如果audioData为空，先从数据库加载
        var audioData = recording.audioData
        if audioData == nil {
            audioData = DatabaseManager.shared.getAudioData(for: recording.audioDataId)
        }
        
        guard let audioData = audioData else {
            print("⚠️ 无法获取音频数据，录音ID: \(recording.audioDataId)")
            return
        }
        
        do {
            // 停止当前播放
            audioPlayer?.stop()
            
            // 创建新的播放器
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // 设置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 开始播放
            if audioPlayer?.play() == true {
                isPlaying = true
                print("🔊 开始播放录音，时长: \(audioPlayer?.duration ?? 0)秒")
            } else {
                print("❌ 播放失败")
            }
        } catch {
            print("❌ 播放录音失败: \(error)")
        }
    }
    
    /// 停止播放
    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
        
        // 恢复音频会话到录音模式
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
        } catch {
            print("❌ 恢复音频会话失败: \(error)")
        }
    }
    
    /// 删除录音
    func deleteRecording(_ recording: AudioRecording) {
        if (DatabaseManager.shared as! DatabaseManager).deleteRecording(id: recording.id) {
            if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
                recordings.remove(at: index)
            }
        }
    }
    
    /// 从数据库刷新单个录音记录
    func refreshRecording(_ recording: AudioRecording) {
        Task {
            let allRecordings = await loadRecordingsAsync()
            if let updatedRecording = allRecordings.first(where: { $0.id == recording.id }) {
                await MainActor.run {
                    if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
                        recordings[index] = updatedRecording
                    }
                }
            }
        }
    }
    
    /// 更新录音记录
    func updateRecording(_ updatedRecording: AudioRecording) {
        if (DatabaseManager.shared as! DatabaseManager).updateRecording(updatedRecording) {
            if let index = recordings.firstIndex(where: { $0.id == updatedRecording.id }) {
                recordings[index] = updatedRecording
                objectWillChange.send()
            }
        }
    }
    
    // MARK: - 状态查询
    
    var isPhoneRecorderAvailable: Bool {
        phoneRecorder.isAvailable
    }
    
    var isESP32RecorderAvailable: Bool {
        esp32Recorder.isAvailable
    }
    
    var esp32ConnectionStatus: ESP32Recorder.ESP32ConnectionStatus {
        esp32Recorder.connectionStatus
    }
    
    // MARK: - 私有方法
    
    private func setupRecorderCallbacks() {
        // 手机录音器回调
        phoneRecorder.onRecordingStarted = { [weak self] in
            Task { @MainActor in
                self?.isRecording = true
                self?.isPaused = false
            }
        }
        
        phoneRecorder.onRecordingFinished = { [weak self] result in
            Task { @MainActor in
                self?.isRecording = false
                self?.isPaused = false
                self?.currentRecordingTime = 0
                self?.onRecordingFinished?(result)
            }
        }
        
        phoneRecorder.onRecordingCancelled = { [weak self] in
            Task { @MainActor in
                self?.isRecording = false
                self?.isPaused = false
                self?.currentRecordingTime = 0
                self?.onRecordingCancelled?()
            }
        }
        
        phoneRecorder.onAmplitudeUpdate = { [weak self] amplitude in
            Task { @MainActor in
                self?.currentAmplitude = amplitude
            }
        }
        
        phoneRecorder.onError = { [weak self] error in
            Task { @MainActor in
                self?.onRecordingError?(error)
            }
        }
        
        // ESP32录音器回调（类似设置）
        esp32Recorder.onRecordingStarted = { [weak self] in
            Task { @MainActor in
                self?.isRecording = true
                self?.isPaused = false
            }
        }
        
        esp32Recorder.onRecordingFinished = { [weak self] result in
            Task { @MainActor in
                self?.isRecording = false
                self?.isPaused = false
                self?.currentRecordingTime = 0
                self?.onRecordingFinished?(result)
            }
        }
        
        esp32Recorder.onRecordingCancelled = { [weak self] in
            Task { @MainActor in
                self?.isRecording = false
                self?.isPaused = false
                self?.currentRecordingTime = 0
                self?.onRecordingCancelled?()
            }
        }
        
        esp32Recorder.onAmplitudeUpdate = { [weak self] amplitude in
            Task { @MainActor in
                self?.currentAmplitude = amplitude
            }
        }
        
        esp32Recorder.onError = { [weak self] error in
            Task { @MainActor in
                self?.onRecordingError?(error)
            }
        }
    }
    
    private func observeRecorderStates() {
        // 观察录音器状态变化
        phoneRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if self?.activeSourceType == .phone {
                    self?.isRecording = isRecording
                }
            }
            .store(in: &cancellables)
        
        phoneRecorder.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPaused in
                if self?.activeSourceType == .phone {
                    self?.isPaused = isPaused
                }
            }
            .store(in: &cancellables)
        
        esp32Recorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if self?.activeSourceType == .esp32 {
                    self?.isRecording = isRecording
                }
            }
            .store(in: &cancellables)
        
        esp32Recorder.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPaused in
                if self?.activeSourceType == .esp32 {
                    self?.isPaused = isPaused
                }
            }
            .store(in: &cancellables)
        
        // 观察ESP32连接状态
        esp32Recorder.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isConnected = (status == .connected)
                switch status {
                case .disconnected:
                    self?.connectionStatus = "未连接"
                case .connecting:
                    self?.connectionStatus = "连接中..."
                case .connected:
                    self?.connectionStatus = "已连接"
                case .error(let message):
                    self?.connectionStatus = "连接错误: \(message)"
                }
            }
            .store(in: &cancellables)
        
        esp32Recorder.$connectedDevice
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectedDevice, on: self)
            .store(in: &cancellables)
        
        // 绑定音频级别
        $currentAmplitude
            .map { [$0] }
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioLevels, on: self)
            .store(in: &cancellables)
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            
            Task { @MainActor in
                if !self.isPaused {
                    self.currentRecordingTime = Date().timeIntervalSince(startTime)
                }
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartTime = nil
        currentRecordingTime = 0
    }
    
    // MARK: - 数据库操作
    
    private func loadRecordingsFromDatabase() {
        Task {
            let loadedRecordings = await loadRecordingsAsync()
            await MainActor.run {
                self.recordings = loadedRecordings
            }
        }
    }
    
    private func loadRecordingsAsync() async -> [AudioRecording] {
        return await Task.detached {
            return (DatabaseManager.shared as! DatabaseManager).loadRecordings()
        }.value
    }
    
    private func loadMockData() {
        #if DEBUG
        recordings = MockDataService.shared.getMockRecordings()
        #endif
    }
    
    private func setupProcessingPipeline() {
        processingPipeline.delegate = self
    }
}

// MARK: - 便捷扩展
extension AudioRecordingService {
    
    /// 获取当前录音器的可用状态
    var isCurrentRecorderAvailable: Bool {
        currentRecorder?.isAvailable ?? false
    }
    
    /// 获取格式化的录音时间
    var formattedRecordingTime: String {
        let minutes = Int(currentRecordingTime) / 60
        let seconds = Int(currentRecordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
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
        return activeSourceType.displayName
    }
    
    /// 格式化录音时长
    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecordingService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        print("🔊 播放完成")
        
        // 恢复音频会话到录音模式
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
        } catch {
            print("❌ 恢复音频会话失败: \(error)")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        if let error = error {
            print("❌ 播放解码错误: \(error)")
        }
    }
}

// MARK: - AudioProcessingPipelineDelegate
extension AudioRecordingService: AudioProcessingPipelineDelegate {
    func pipelineDidStartRecording(_ pipeline: AudioProcessingPipeline) {
        // 音频处理流水线开始录音，这里可以处理UI更新等
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didFinishRecording audioData: Data, duration: TimeInterval) {
        // 录音完成，开始处理
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didCreateInitialRecording recording: AudioRecording) {
        // 创建初始录音记录（录音完成后立即创建）
        if !recordings.contains(where: { $0.id == recording.id }) {
            recordings.insert(recording, at: 0)
        }
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didReceiveSpeechResult result: SpeechRecognitionResult) {
        // 语音识别完成，可以在这里更新UI显示识别进度
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didCompleteFirstStep result: FirstStepAnalysis) {
        // LLM分析第一步完成
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didCompleteFinalAnalysis recording: AudioRecording) {
        // 完整处理完成，生成最终录音记录
        if let existingIndex = recordings.firstIndex(where: { $0.id == recording.id }) {
            // 更新现有记录
            recordings[existingIndex] = recording
            objectWillChange.send()
        } else {
            // 添加新记录
            recordings.insert(recording, at: 0)
        }
    }
    
    func pipeline(_ pipeline: AudioProcessingPipeline, didFailWithError error: AudioProcessingError) {
        // 处理失败
        print("音频处理失败: \(error.localizedDescription)")
    }
}