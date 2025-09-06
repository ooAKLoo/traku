//
//  AudioInputSource.swift
//  音频输入源抽象层
//

import Foundation
import Combine

// MARK: - 音频输入结果
struct AudioInputResult {
    let audioData: Data
    let duration: TimeInterval
    let timestamp: Date
    let source: AudioInputSourceType
    
    init(audioData: Data, duration: TimeInterval, source: AudioInputSourceType) {
        self.audioData = audioData
        self.duration = duration
        self.timestamp = Date()
        self.source = source
    }
}

// MARK: - 音频输入源类型
enum AudioInputSourceType: String, CaseIterable {
    case esp32 = "ESP32硬件"
    case phone = "手机录音"
    case file = "文件导入"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - 音频输入源协议
protocol AudioInputSource: AnyObject {
    // MARK: - Properties
    var isAvailable: Bool { get }
    var isRecording: Bool { get }
    var isPaused: Bool { get }
    var sourceType: AudioInputSourceType { get }
    var delegate: AudioInputSourceDelegate? { get set }
    
    // MARK: - Recording Control
    func startRecording()
    func stopRecording()
    func pauseRecording()
    func resumeRecording()
    
    // MARK: - Configuration
    func configure() async -> Bool
    func cleanup()
}

// MARK: - 音频输入源代理协议
protocol AudioInputSourceDelegate: AnyObject {
    func audioInputSource(_ source: AudioInputSource, didStartRecording: Void)
    func audioInputSource(_ source: AudioInputSource, didFinishRecording result: AudioInputResult)
    func audioInputSource(_ source: AudioInputSource, didUpdateAmplitude amplitude: Float)
    func audioInputSource(_ source: AudioInputSource, didEncounterError error: Error)
    func audioInputSource(_ source: AudioInputSource, didChangeRecordingStatus isRecording: Bool)
    func audioInputSource(_ source: AudioInputSource, didChangePausedStatus isPaused: Bool)
}

// MARK: - 音频输入管理器
class AudioInputManager: ObservableObject {
    // MARK: - Published Properties
    @Published var availableSources: [AudioInputSource] = []
    @Published var activeSource: AudioInputSource?
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentAmplitude: Float = 0.0
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Delegate
    weak var delegate: AudioInputManagerDelegate?
    
    // MARK: - Initialization
    init() {
        setupAvailableSources()
    }
    
    // MARK: - Public Methods
    
    /// 设置活跃的音频输入源
    func setActiveSource(_ source: AudioInputSource) {
        // 停止当前录音
        if isRecording {
            stopRecording()
        }
        
        // 清理之前的源
        activeSource?.delegate = nil
        
        // 设置新的源
        activeSource = source
        source.delegate = self
        
        // 更新状态
        updateRecordingStatus()
    }
    
    /// 开始录音
    func startRecording() {
        guard let source = activeSource, source.isAvailable else {
            delegate?.audioInputManager(self, didEncounterError: AudioInputError.noActiveSource)
            return
        }
        
        source.startRecording()
    }
    
    /// 停止录音
    func stopRecording() {
        activeSource?.stopRecording()
    }
    
    /// 暂停录音
    func pauseRecording() {
        activeSource?.pauseRecording()
    }
    
    /// 恢复录音
    func resumeRecording() {
        activeSource?.resumeRecording()
    }
    
    /// 配置所有可用源
    func configureAllSources() async {
        for source in availableSources {
            await source.configure()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAvailableSources() {
        // 这里会在具体实现中注册各种输入源
        // 目前为空，将在AudioManagerAdapter中填充
    }
    
    private func updateRecordingStatus() {
        DispatchQueue.main.async {
            self.isRecording = self.activeSource?.isRecording ?? false
            self.isPaused = self.activeSource?.isPaused ?? false
        }
    }
}

// MARK: - AudioInputSourceDelegate实现
extension AudioInputManager: AudioInputSourceDelegate {
    func audioInputSource(_ source: AudioInputSource, didStartRecording: Void) {
        updateRecordingStatus()
        delegate?.audioInputManager(self, didStartRecording: source.sourceType)
    }
    
    func audioInputSource(_ source: AudioInputSource, didFinishRecording result: AudioInputResult) {
        updateRecordingStatus()
        delegate?.audioInputManager(self, didFinishRecording: result)
    }
    
    func audioInputSource(_ source: AudioInputSource, didUpdateAmplitude amplitude: Float) {
        DispatchQueue.main.async {
            self.currentAmplitude = amplitude
        }
        delegate?.audioInputManager(self, didUpdateAmplitude: amplitude)
    }
    
    func audioInputSource(_ source: AudioInputSource, didEncounterError error: Error) {
        delegate?.audioInputManager(self, didEncounterError: error)
    }
    
    func audioInputSource(_ source: AudioInputSource, didChangeRecordingStatus isRecording: Bool) {
        updateRecordingStatus()
    }
    
    func audioInputSource(_ source: AudioInputSource, didChangePausedStatus isPaused: Bool) {
        updateRecordingStatus()
    }
}

// MARK: - 音频输入管理器代理协议
protocol AudioInputManagerDelegate: AnyObject {
    func audioInputManager(_ manager: AudioInputManager, didStartRecording sourceType: AudioInputSourceType)
    func audioInputManager(_ manager: AudioInputManager, didFinishRecording result: AudioInputResult)
    func audioInputManager(_ manager: AudioInputManager, didUpdateAmplitude amplitude: Float)
    func audioInputManager(_ manager: AudioInputManager, didEncounterError error: Error)
}

// MARK: - 音频输入错误
enum AudioInputError: Error, LocalizedError {
    case noActiveSource
    case sourceNotAvailable
    case configurationFailed
    case recordingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noActiveSource:
            return "没有活跃的音频输入源"
        case .sourceNotAvailable:
            return "音频输入源不可用"
        case .configurationFailed:
            return "音频输入源配置失败"
        case .recordingFailed(let reason):
            return "录音失败: \(reason)"
        }
    }
}