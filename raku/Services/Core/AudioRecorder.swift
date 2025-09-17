//
//  AudioRecorder.swift
//  raku - 统一音频录制接口
//
//  重构说明：
//  - 替代复杂的AudioInputSource体系
//  - 提供简单统一的录音接口
//  - 屏蔽底层硬件差异
//

import Foundation
import Combine

// MARK: - 音频录制结果
struct AudioRecordingResult {
    let audioData: Data
    let duration: TimeInterval
    let timestamp: Date
    let sourceType: AudioSourceType
}

// MARK: - 音频源类型
enum AudioSourceType: String, CaseIterable {
    case phone = "手机录音"
    case esp32 = "ESP32硬件"
    
    var displayName: String { rawValue }
}

// MARK: - 音频录制接口协议
protocol AudioRecorder: AnyObject {
    // MARK: - 状态属性
    var isAvailable: Bool { get }
    var isRecording: Bool { get }
    var isPaused: Bool { get }
    var sourceType: AudioSourceType { get }
    
    // MARK: - 录制控制
    func startRecording() async throws
    func stopRecording() async -> AudioRecordingResult?
    func cancelRecording() async
    func pauseRecording() async throws
    func resumeRecording() async throws
    
    // MARK: - 事件回调
    var onRecordingStarted: (() -> Void)? { get set }
    var onRecordingFinished: ((AudioRecordingResult) -> Void)? { get set }
    var onRecordingCancelled: (() -> Void)? { get set }
    var onAmplitudeUpdate: ((Float) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }
}

// MARK: - 录音错误类型
enum AudioRecordingError: Error, LocalizedError {
    case sourceNotAvailable
    case alreadyRecording
    case notRecording
    case configurationFailed(String)
    case recordingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sourceNotAvailable:
            return "音频源不可用"
        case .alreadyRecording:
            return "正在录音中"
        case .notRecording:
            return "当前未在录音"
        case .configurationFailed(let reason):
            return "配置失败: \(reason)"
        case .recordingFailed(let reason):
            return "录音失败: \(reason)"
        }
    }
}