//
//  PhoneRecorder.swift
//  raku - 手机录音实现
//
//  重构说明：
//  - 整合原有的PhoneRecordingManager功能
//  - 实现AudioRecorder统一接口
//  - 专注于手机录音的具体实现
//

import Foundation
import AVFoundation
import Combine

// MARK: - 手机录音器实现
class PhoneRecorder: NSObject, AudioRecorder {
    
    // MARK: - AudioRecorder 协议实现
    var isAvailable: Bool {
        AVAudioSession.sharedInstance().isInputAvailable
    }
    
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    
    let sourceType: AudioSourceType = .phone
    
    // MARK: - 事件回调
    var onRecordingStarted: (() -> Void)?
    var onRecordingFinished: ((AudioRecordingResult) -> Void)?
    var onRecordingCancelled: (() -> Void)?
    var onAmplitudeUpdate: ((Float) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - 私有属性
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingStartTime: Date?
    private var amplitudeTimer: Timer?
    
    // MARK: - 录制控制实现
    
    func startRecording() async throws {
        guard !isRecording else {
            throw AudioRecordingError.alreadyRecording
        }
        
        guard isAvailable else {
            throw AudioRecordingError.sourceNotAvailable
        }
        
        try await configureAudioSession()
        try await setupRecorder()
        
        audioRecorder?.record()
        recordingStartTime = Date()
        
        await MainActor.run {
            isRecording = true
            isPaused = false
        }
        
        startAmplitudeMonitoring()
        onRecordingStarted?()
    }
    
    func stopRecording() async -> AudioRecordingResult? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        stopAmplitudeMonitoring()
        
        await MainActor.run {
            isRecording = false
            isPaused = false
        }
        
        // 读取录音数据
        if let url = audioRecorder?.url,
           let data = try? Data(contentsOf: url),
           let startTime = recordingStartTime {
            
            let result = AudioRecordingResult(
                audioData: data,
                duration: Date().timeIntervalSince(startTime),
                timestamp: startTime,
                sourceType: .phone
            )
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: url)
            
            onRecordingFinished?(result)
            return result
        }
        
        return nil
    }
    
    func cancelRecording() async {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        stopAmplitudeMonitoring()
        
        await MainActor.run {
            isRecording = false
            isPaused = false
        }
        
        // 清理临时文件
        if let url = audioRecorder?.url {
            try? FileManager.default.removeItem(at: url)
        }
        
        onRecordingCancelled?()
    }
    
    func pauseRecording() async throws {
        guard isRecording && !isPaused else {
            throw AudioRecordingError.notRecording
        }
        
        audioRecorder?.pause()
        await MainActor.run {
            isPaused = true
        }
    }
    
    func resumeRecording() async throws {
        guard isRecording && isPaused else {
            throw AudioRecordingError.notRecording
        }
        
        audioRecorder?.record()
        await MainActor.run {
            isPaused = false
        }
    }
    
    // MARK: - 私有方法
    
    private func configureAudioSession() async throws {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            throw AudioRecordingError.configurationFailed("音频会话配置失败: \(error.localizedDescription)")
        }
    }
    
    private func setupRecorder() async throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("temp_recording_\(UUID().uuidString).wav")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,  // 与ASR服务期望的采样率一致
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
        } catch {
            throw AudioRecordingError.configurationFailed("录音器初始化失败: \(error.localizedDescription)")
        }
    }
    
    private func startAmplitudeMonitoring() {
        amplitudeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            let amplitude = pow(10, recorder.averagePower(forChannel: 0) / 20)
            
            DispatchQueue.main.async {
                self.onAmplitudeUpdate?(amplitude)
            }
        }
    }
    
    private func stopAmplitudeMonitoring() {
        amplitudeTimer?.invalidate()
        amplitudeTimer = nil
    }
}

// MARK: - AVAudioRecorderDelegate
extension PhoneRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            onError?(AudioRecordingError.recordingFailed("录音未成功完成"))
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            onError?(AudioRecordingError.recordingFailed(error.localizedDescription))
        }
    }
}