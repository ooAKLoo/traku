//
//  RecordingManager.swift
//  Echo Watch App
//
//  录音管理器单例 - 供 App Intent 静默调用
//  支持后台录音，无需打开 App UI
//

import Foundation
import WatchKit
import Combine

@MainActor
final class RecordingManager: ObservableObject {

    static let shared = RecordingManager()

    // MARK: - Published Properties

    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0

    // MARK: - Private Properties

    private let audioRecorder = WatchAudioRecorder()
    private var durationTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 180  // 3分钟限制

    private init() {
        // 监听 Action Button 通知
        NotificationCenter.default.addObserver(
            forName: .actionButtonPressed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.toggle()
            }
        }

        // 监听来自 iPhone 的命令
        NotificationCenter.default.addObserver(
            forName: .startRecordingFromPhone,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.startRecording()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .stopRecordingFromPhone,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.stopRecording()
            }
        }
    }

    // MARK: - Public Methods

    /// 切换录音状态 (用于 Action Button)
    func toggle() {
        Task {
            if isRecording {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }

    /// 开始录音
    func startRecording() async {
        guard !isRecording else { return }

        do {
            _ = try await audioRecorder.startRecording()
            isRecording = true
            recordingDuration = 0

            // 触觉反馈: 单次重击 "哒"
            HapticManager.shared.playStartRecording()

            // 启动计时器
            startDurationTimer()

            print("[RecordingManager] 录音已开始")

        } catch {
            HapticManager.shared.playError()
            print("[RecordingManager] 录音启动失败: \(error)")
        }
    }

    /// 停止录音
    func stopRecording() async {
        guard isRecording else { return }

        do {
            let recordingInfo = try await audioRecorder.stopRecording()
            isRecording = false
            stopDurationTimer()

            // 触觉反馈: 双次轻击 "哒哒"
            HapticManager.shared.playStopRecording()

            // 同步到 iPhone
            await WatchConnectivityManager.shared.sendRecording(recordingInfo)

            print("[RecordingManager] 录音完成: \(recordingInfo.duration)秒")

        } catch {
            HapticManager.shared.playError()
            print("[RecordingManager] 录音停止失败: \(error)")
        }
    }

    // MARK: - Private Methods

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingDuration += 1

                // 还剩10秒时提醒
                if self.recordingDuration >= self.maxRecordingDuration - 10 &&
                   self.recordingDuration < self.maxRecordingDuration {
                    HapticManager.shared.playLongRecordingWarning()
                }

                // 达到限制，自动停止
                if self.recordingDuration >= self.maxRecordingDuration {
                    await self.stopRecording()
                }
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}
