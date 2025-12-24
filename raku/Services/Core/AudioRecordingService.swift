//
//  AudioRecordingService.swift
//  raku - 统一音频录制服务
//
//  职责：
//  - 管理录音设备（手机/ESP32）
//  - 控制录音流程（开始/暂停/停止）
//  - 播放录音
//  - 触发Pipeline处理
//
//  注意：录音数据管理已移至 RecordingStore
//

import Foundation
import Combine
import SwiftUI
import AVFoundation

// MARK: - 音频录制服务
@MainActor
class AudioRecordingService: NSObject, ObservableObject {

    // MARK: - 单例
    static let shared = AudioRecordingService()

    // MARK: - 发布属性（录音状态）
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var isPlaying: Bool = false
    @Published var currentRecordingTime: TimeInterval = 0
    @Published var currentAmplitude: Float = 0
    @Published var audioLevels: [Float] = []

    // MARK: - 发布属性（设备状态）
    @Published var activeSourceType: AudioSourceType = .phone
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "未连接"
    @Published var connectedDevice: ESP32Recorder.ESP32Device?

    // MARK: - 录音器实例
    private let phoneRecorder: PhoneRecorder
    private let esp32Recorder: ESP32Recorder
    private let processingPipeline: RecordingPipeline

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
        self.processingPipeline = RecordingPipeline()

        super.init()

        setupRecorderCallbacks()
        observeRecorderStates()
    }

    // MARK: - 录音控制

    func startRecording() async throws {
        guard let recorder = currentRecorder else {
            throw AudioRecordingError.sourceNotAvailable
        }

        guard !isRecording else {
            throw AudioRecordingError.alreadyRecording
        }

        try await recorder.startRecording()
        recordingStartTime = Date()
        startRecordingTimer()
    }

    func stopRecording() async -> AudioRecordingResult? {
        guard let recorder = currentRecorder else { return nil }

        stopRecordingTimer()
        let result = await recorder.stopRecording()

        if let result = result {
            print("🔄 开始处理录音结果，数据大小: \(result.audioData.count / 1024) KB")
            processingPipeline.processRecording(
                audioData: result.audioData,
                duration: result.duration,
                source: activeSourceType == .phone ? .phone : .esp32
            )
        }

        return result
    }

    func cancelRecording() async {
        guard let recorder = currentRecorder else { return }

        stopRecordingTimer()
        await recorder.cancelRecording()
        processingPipeline.cancelProcessing()
    }

    func pauseRecording() async throws {
        guard let recorder = currentRecorder else {
            throw AudioRecordingError.sourceNotAvailable
        }
        try await recorder.pauseRecording()
    }

    func resumeRecording() async throws {
        guard let recorder = currentRecorder else {
            throw AudioRecordingError.sourceNotAvailable
        }
        try await recorder.resumeRecording()
    }

    // MARK: - 设备切换

    func switchToSource(_ sourceType: AudioSourceType) async throws {
        if isRecording {
            _ = await stopRecording()
        }

        activeSourceType = sourceType

        guard currentRecorder?.isAvailable == true else {
            throw AudioRecordingError.sourceNotAvailable
        }
    }

    func connectToESP32(device: ESP32Recorder.ESP32Device) async throws {
        try await esp32Recorder.connect(to: device)
        activeSourceType = .esp32
    }

    func disconnectESP32() async {
        await esp32Recorder.disconnect()
        if activeSourceType == .esp32 {
            activeSourceType = .phone
        }
    }

    // MARK: - Watch 录音处理

    func processWatchRecording(audioData: Data, duration: TimeInterval, recordingId: String, createdAt: Date) {
        print("⌚ [AudioRecordingService] 处理 Watch 录音: ID=\(recordingId)")
        processingPipeline.processWatchRecording(
            audioData: audioData,
            duration: duration,
            recordingId: recordingId,
            createdAt: createdAt
        )
    }

    // MARK: - 播放控制

    func playRecording(_ recording: AudioRecording) {
        var audioData = recording.audioData
        if audioData == nil {
            audioData = DatabaseManager.shared.getAudioData(for: recording.audioDataId)
        }

        guard let audioData = audioData else {
            print("⚠️ 无法获取音频数据，录音ID: \(recording.audioDataId)")
            return
        }

        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            if audioPlayer?.play() == true {
                isPlaying = true
                print("🔊 开始播放录音，时长: \(audioPlayer?.duration ?? 0)秒")
            }
        } catch {
            print("❌ 播放录音失败: \(error)")
        }
    }

    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
        } catch {
            print("❌ 恢复音频会话失败: \(error)")
        }
    }

    // MARK: - 状态查询

    var isPhoneRecorderAvailable: Bool { phoneRecorder.isAvailable }
    var isESP32RecorderAvailable: Bool { esp32Recorder.isAvailable }
    var esp32ConnectionStatus: ESP32Recorder.ESP32ConnectionStatus { esp32Recorder.connectionStatus }
    var isCurrentRecorderAvailable: Bool { currentRecorder?.isAvailable ?? false }

    var formattedRecordingTime: String {
        let minutes = Int(currentRecordingTime) / 60
        let seconds = Int(currentRecordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var connectedDeviceName: String { connectedDevice?.name ?? "未连接" }
    var currentInputSourceName: String { activeSourceType.displayName }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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

        // ESP32录音器回调
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

        esp32Recorder.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isConnected = (status == .connected)
                switch status {
                case .disconnected: self?.connectionStatus = "未连接"
                case .connecting: self?.connectionStatus = "连接中..."
                case .connected: self?.connectionStatus = "已连接"
                case .error(let message): self?.connectionStatus = "连接错误: \(message)"
                }
            }
            .store(in: &cancellables)

        esp32Recorder.$connectedDevice
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectedDevice, on: self)
            .store(in: &cancellables)

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
}

// MARK: - AVAudioPlayerDelegate
extension AudioRecordingService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
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
