//
//  PhoneAudioInputSource.swift
//  手机音频输入源实现
//

import Foundation
import Combine

class PhoneAudioInputSource: AudioInputSource {
    // MARK: - AudioInputSource Properties
    var isAvailable: Bool = true // 手机录音总是可用的
    
    var isRecording: Bool {
        return phoneRecordingManager.isRecording
    }
    
    var isPaused: Bool {
        return phoneRecordingManager.isPaused
    }
    
    let sourceType: AudioInputSourceType = .phone
    
    weak var delegate: AudioInputSourceDelegate?
    
    // MARK: - Private Properties
    private let phoneRecordingManager: PhoneRecordingManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(phoneRecordingManager: PhoneRecordingManager) {
        self.phoneRecordingManager = phoneRecordingManager
        setupBindings()
    }
    
    // MARK: - AudioInputSource Methods
    func startRecording() {
        phoneRecordingManager.startRecording()
    }
    
    func stopRecording() {
        phoneRecordingManager.stopRecording()
    }
    
    func pauseRecording() {
        phoneRecordingManager.pauseRecording()
    }
    
    func resumeRecording() {
        phoneRecordingManager.resumeRecording()
    }
    
    func configure() async -> Bool {
        // 手机录音配置通常涉及权限检查
        // 这里简化处理，返回true
        return true
    }
    
    func cleanup() {
        phoneRecordingManager.stopRecording()
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // 监听录音状态变化
        phoneRecordingManager.$isRecording
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                self.delegate?.audioInputSource(self, didChangeRecordingStatus: isRecording)
            }
            .store(in: &cancellables)
        
        // 监听暂停状态变化
        phoneRecordingManager.$isPaused
            .sink { [weak self] isPaused in
                guard let self = self else { return }
                self.delegate?.audioInputSource(self, didChangePausedStatus: isPaused)
            }
            .store(in: &cancellables)
        
        // 监听音频级别变化（如果PhoneRecordingManager支持）
        if let amplitudePublisher = phoneRecordingManager.amplitudePublisher {
            amplitudePublisher
                .sink { [weak self] amplitude in
                    guard let self = self else { return }
                    self.delegate?.audioInputSource(self, didUpdateAmplitude: amplitude)
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - PhoneRecordingManagerDelegate桥接
extension PhoneAudioInputSource: PhoneRecordingManagerDelegate {
    func phoneRecordingDidStart(_ manager: PhoneRecordingManager) {
        delegate?.audioInputSource(self, didStartRecording: ())
    }
    
    func phoneRecording(_ manager: PhoneRecordingManager, didFinishWithAudioData audioData: Data, duration: TimeInterval) {
        let result = AudioInputResult(
            audioData: audioData,
            duration: duration,
            source: .phone
        )
        delegate?.audioInputSource(self, didFinishRecording: result)
    }
    
    func phoneRecording(_ manager: PhoneRecordingManager, didFailWithError error: Error) {
        delegate?.audioInputSource(self, didEncounterError: error)
    }
}

// MARK: - PhoneRecordingManager扩展
extension PhoneRecordingManager {
    // 添加音频级别发布器（如果原本没有的话）
    var amplitudePublisher: AnyPublisher<Float, Never>? {
        // 这里需要根据实际的PhoneRecordingManager实现来调整
        // 如果PhoneRecordingManager有音频级别监测，返回对应的Publisher
        // 如果没有，返回nil
        return nil
    }
}