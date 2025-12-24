//
//  EchoApp.swift
//  Echo Watch App
//
//  Created by 杨东举 on 2025/12/23.
//

import SwiftUI
import WatchKit

@main
struct EchoApp: App {

    @WKApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // 持有 RecordingManager 实例，确保 App Intent 可以访问
    @StateObject private var recordingManager = RecordingManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordingManager)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, WKApplicationDelegate {

    func applicationDidFinishLaunching() {
        // 激活 WatchConnectivity
        WatchConnectivityManager.shared.activate()

        // 初始化 RecordingManager (确保单例被创建)
        _ = RecordingManager.shared

        print("[EchoApp] App 启动完成，Action Button Intent 已就绪")
    }

    func applicationDidBecomeActive() {
        // App 进入前台
    }

    func applicationWillResignActive() {
        // App 即将进入后台
    }

    // MARK: - Action Button Support (Apple Watch Ultra)

    /// 处理 Action Button 按下事件 (备用方式)
    func handleUserActivity(_ userActivity: NSUserActivity) {
        // 当 Action Button 触发时，发送通知启动录音
        if userActivity.activityType == "com.apple.watchos.actionButtonActivity" {
            NotificationCenter.default.post(name: .actionButtonPressed, object: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let actionButtonPressed = Notification.Name("actionButtonPressed")
}
