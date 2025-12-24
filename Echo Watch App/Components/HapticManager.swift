//
//  HapticManager.swift
//  Echo Watch App
//
//  触觉反馈管理器 - 提供"闭眼可操作"的反馈体验
//

import Foundation
import WatchKit

final class HapticManager {

    static let shared = HapticManager()

    private init() {}

    // MARK: - Recording Haptics

    /// 开始录音: 单次重击 "哒"
    func playStartRecording() {
        WKInterfaceDevice.current().play(.start)
    }

    /// 结束录音: 双次轻击 "哒哒"
    func playStopRecording() {
        WKInterfaceDevice.current().play(.stop)

        // 延迟 200ms 播放第二次
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            WKInterfaceDevice.current().play(.stop)
        }
    }

    /// 同步完成: 轻微确认震动
    func playSyncSuccess() {
        WKInterfaceDevice.current().play(.success)
    }

    /// 录音失败: 错误提示震动
    func playError() {
        WKInterfaceDevice.current().play(.failure)
    }

    /// 解锁成功: 轻击提示
    func playUnlock() {
        WKInterfaceDevice.current().play(.click)
    }

    /// 点击反馈
    func playClick() {
        WKInterfaceDevice.current().play(.click)
    }

    /// 方向提示 (向上)
    func playDirectionUp() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    /// 方向提示 (向下)
    func playDirectionDown() {
        WKInterfaceDevice.current().play(.directionDown)
    }

    /// 重试提示
    func playRetry() {
        WKInterfaceDevice.current().play(.retry)
    }

    // MARK: - Custom Sequences

    /// 长录音提醒 (即将达到时长限制)
    func playLongRecordingWarning() {
        WKInterfaceDevice.current().play(.notification)
    }

    /// 准备就绪 (App 启动完成)
    func playReady() {
        WKInterfaceDevice.current().play(.start)
    }
}
