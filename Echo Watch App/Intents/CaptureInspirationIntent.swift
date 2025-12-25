//
//  CaptureInspirationIntent.swift
//  Echo Watch App
//
//  App Intent - 让 Action Button 可以触发录音
//  静默执行，无需唤醒屏幕，完美支持"闭眼场景"
//

import AppIntents
import Foundation
#if os(watchOS)
import WatchKit
#endif

// MARK: - 捕捉灵感 Intent

@available(watchOS 10.0, *)
struct CaptureInspirationIntent: AppIntent {

    static var title: LocalizedStringResource = "捕捉灵感"
    static var description = IntentDescription("快速开始或停止语音录音")

    // 无需认证，支持锁屏时触发
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    // 在后台静默执行，不打开 App UI
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        // 发送通知触发录音切换
//        NotificationCenter.default.post(name: .actionButtonPressed, object: nil)

        // 触发触觉反馈
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif

        return .result()
    }
}

// MARK: - App Shortcuts Provider

@available(watchOS 10.0, *)
struct EchoShortcutsProvider: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureInspirationIntent(),
            phrases: [
                "用 \(.applicationName) 录音",
                "用 \(.applicationName) 捕捉灵感",
                "在 \(.applicationName) 开始录音",
                "\(.applicationName) 录音"
            ],
            shortTitle: "捕捉灵感",
            systemImageName: "waveform.circle.fill"
        )
    }
}
