//
//  RecordingControlPanel.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 录音控制面板复合组件
struct RecordingControlPanel: View {
    let recordingTime: TimeInterval
    let isPaused: Bool
    let onTogglePause: () -> Void
    let onStop: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 暂停/继续按钮
            CircularButton(
                iconName: isPaused ? "play.fill" : "pause.fill",
                iconColor: isPaused ? .green : .orange,
                action: onTogglePause
            )
            .scaleEffect(isPaused ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isPaused)
            
            // 录音状态显示
            RecordingStatusView(
                recordingTime: recordingTime,
                isPaused: isPaused
            )
            
            // 停止按钮（自定义样式）
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(width: 16, height: 16)
                }
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3), value: isPaused)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - 预览
struct RecordingControlPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            Text("录音控制面板组件")
                .font(.headline)
            
            VStack(spacing: 20) {
                // 录音中状态
                RecordingControlPanel(
                    recordingTime: 125.7,
                    isPaused: false,
                    onTogglePause: { print("Toggle Pause") },
                    onStop: { print("Stop Recording") }
                )
                .padding()
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 8)
                )
                
                // 暂停状态
                RecordingControlPanel(
                    recordingTime: 85.3,
                    isPaused: true,
                    onTogglePause: { print("Toggle Pause") },
                    onStop: { print("Stop Recording") }
                )
                .padding()
                .background(
                    Capsule()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 8)
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}