//
//  RecordingControlViewModel.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import Foundation
import Combine

// MARK: - 录音控制业务逻辑ViewModel
class RecordingControlViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var timer: Timer?
    private let audioManager: AudioManagerAdapter
    
    // 计算属性：从AudioManager获取暂停状态
    var isPaused: Bool {
        audioManager.isPaused
    }
    
    init(audioManager: AudioManagerAdapter) {
        self.audioManager = audioManager
    }
    
    // MARK: - 公共方法
    
    /// 开始录音
    func startRecording() {
        isRecording = true
        startTimer()
        
        // 根据连接状态调用对应的录音方法
        if audioManager.isConnected {
            audioManager.startRecording()
        } else {
            audioManager.startPhoneRecording()
        }
    }
    
    /// 暂停/恢复录音
    func togglePause() {
        if isPaused {
            // 当前是暂停状态，恢复录音
            audioManager.resumeRecording()
            startTimer()
        } else {
            // 当前是录音状态，暂停录音
            audioManager.pauseRecording()
            timer?.invalidate()
        }
    }
    
    /// 停止录音
    func stopRecording() {
        isRecording = false
        stopTimer()
        audioManager.stopRecording()
    }
    
    // MARK: - 私有方法
    
    /// 启动计时器
    private func startTimer() {
        // 只在第一次开始录音时重置时间，恢复录音时不重置
        if !isPaused && recordingTime == 0 {
            recordingTime = 0
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
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