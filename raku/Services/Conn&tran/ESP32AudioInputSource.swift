//
//  ESP32AudioInputSource.swift
//  ESP32音频输入源实现
//

import Foundation
import Combine

class ESP32AudioInputSource: AudioInputSource {
    // MARK: - AudioInputSource Properties
    var isAvailable: Bool {
        return esp32Service.isConnected
    }
    
    var isRecording: Bool {
        return esp32Service.isRecording
    }
    
    var isPaused: Bool {
        return false // ESP32暂不支持暂停
    }
    
    let sourceType: AudioInputSourceType = .esp32
    
    weak var delegate: AudioInputSourceDelegate?
    
    // MARK: - Private Properties
    private let esp32Service: ESP32AudioService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(esp32Service: ESP32AudioService) {
        self.esp32Service = esp32Service
        setupBindings()
    }
    
    // MARK: - AudioInputSource Methods
    func startRecording() {
        esp32Service.startRecording()
    }
    
    func stopRecording() {
        esp32Service.stopRecording()
    }
    
    func pauseRecording() {
        // ESP32暂不支持暂停，可以实现为停止录音
        esp32Service.pauseRecording()
    }
    
    func resumeRecording() {
        // ESP32暂不支持恢复，可以实现为重新开始录音
        esp32Service.resumeRecording()
    }
    
    func configure() async -> Bool {
        // ESP32的配置通过外部连接管理，这里返回当前连接状态
        return esp32Service.isConnected
    }
    
    func cleanup() {
        esp32Service.disconnect()
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // 监听录音状态变化
        esp32Service.$isRecording
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                self.delegate?.audioInputSource(self, didChangeRecordingStatus: isRecording)
            }
            .store(in: &cancellables)
        
        // 监听音频级别变化
        esp32Service.$audioLevels
            .compactMap { $0.last }
            .sink { [weak self] amplitude in
                guard let self = self else { return }
                self.delegate?.audioInputSource(self, didUpdateAmplitude: amplitude)
            }
            .store(in: &cancellables)
    }
}

// MARK: - ESP32AudioServiceDelegate桥接
extension ESP32AudioInputSource: ESP32AudioServiceDelegate {
    func esp32AudioService(_ service: ESP32AudioService, didChangeConnectionStatus isConnected: Bool, status: String) {
        // 连接状态变化不需要特别处理，isAvailable会自动更新
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didChangeRecordingStatus isRecording: Bool, duration: TimeInterval) {
        if isRecording {
            delegate?.audioInputSource(self, didStartRecording: ())
        }
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didUpdateAmplitude amplitude: Float) {
        delegate?.audioInputSource(self, didUpdateAmplitude: amplitude)
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didFinishRecording audioRecording: AudioRecording) {
        if let audioData = audioRecording.audioData {
            let result = AudioInputResult(
                audioData: audioData,
                duration: audioRecording.duration,
                source: .esp32
            )
            delegate?.audioInputSource(self, didFinishRecording: result)
        }
    }
    
    func esp32AudioService(_ service: ESP32AudioService, didEncounterError error: Error) {
        delegate?.audioInputSource(self, didEncounterError: error)
    }
}