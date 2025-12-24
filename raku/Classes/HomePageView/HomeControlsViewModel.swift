//
//  HomeControlsViewModel.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import Foundation
import Combine

// MARK: - 录音控制业务逻辑ViewModel
@MainActor
class HomeControlsViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var timer: Timer?
    private let audioManager: AudioRecordingService
    
    // 计算属性：从AudioManager获取暂停状态
    var isPaused: Bool {
        audioManager.isPaused
    }
    
    init(audioManager: AudioRecordingService) {
        self.audioManager = audioManager
    }
    
    // MARK: - 公共方法
    
    /// 开始录音
    func startRecording() {
        isRecording = true
        startTimer()

        Task {
            do {
                try await audioManager.startRecording()
            } catch {
                isRecording = false
                stopTimer()
                print("录音启动失败: \(error)")
            }
        }
    }
    
    /// 暂停/恢复录音
    func togglePause() {
        Task {
            do {
                if audioManager.isPaused {
                    // 当前是暂停状态，恢复录音
                    try await audioManager.resumeRecording()
                    startTimer()
                } else {
                    // 当前是录音状态，暂停录音
                    try await audioManager.pauseRecording()
                    timer?.invalidate()
                }
            } catch {
                print("暂停/恢复录音失败: \(error)")
            }
        }
    }
    
    /// 停止录音
    func stopRecording() {
        isRecording = false
        stopTimer()
        Task {
            _ = await audioManager.stopRecording()
        }
    }
    
    /// 取消录音（不保存）
    func cancelRecording() {
        isRecording = false
        stopTimer()
        Task {
            await audioManager.cancelRecording()
        }
    }
    
    // MARK: - 私有方法
    
    /// 启动计时器
    private func startTimer() {
        // 只在第一次开始录音时重置时间，恢复录音时不重置
        if !isPaused && recordingTime == 0 {
            recordingTime = 0
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 只有在未暂停状态下才增加时间
            if !self.audioManager.isPaused {
                self.recordingTime += 0.1
            }
        }
    }
    
    /// 停止计时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingTime = 0
    }
    
    deinit {
        timer?.invalidate()
    }
}