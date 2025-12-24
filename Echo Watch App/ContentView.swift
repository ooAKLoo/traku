//
//  ContentView.swift
//  Echo Watch App
//
//  主导航视图 - 支持快速录音和录音列表
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showRecordingView = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 快速录音 (黑屏模式)
            RecordingView()
                .tag(0)

            // Tab 2: 录音列表
            RecordingListView()
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        // 监听 Action Button (Apple Watch Ultra)
        .onReceive(NotificationCenter.default.publisher(for: .actionButtonPressed)) { _ in
            handleActionButton()
        }
        // 监听来自 iPhone 的录音命令
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromPhone)) { _ in
            selectedTab = 0  // 切换到录音页面
        }
    }

    private func handleActionButton() {
        // Action Button 按下时，切换到录音页面并触发录音
        selectedTab = 0
        // 发送通知让 RecordingView 开始录音
        NotificationCenter.default.post(name: .toggleRecording, object: nil)
        HapticManager.shared.playClick()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let toggleRecording = Notification.Name("toggleRecording")
}

#Preview {
    ContentView()
}
