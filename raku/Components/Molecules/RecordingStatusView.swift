//
//  RecordingStatusView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 录音状态显示复合组件
struct RecordingStatusView: View {
    let recordingTime: TimeInterval
    let isPaused: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            // 时间显示
            TimeDisplay(
                time: recordingTime,
                fontSize: 18,
                fontWeight: .semibold,
                textColor: .black
            )
            
            // 状态指示行
            HStack(spacing: 6) {
                // 录音状态指示点
                StatusIndicator(
                    isActive: !isPaused,
                    activeColor: .red,
                    inactiveColor: Color.black.opacity(0.5),
                    size: 8
                )
                
                // 状态文本
                Text(isPaused ? "已暂停" : "录音中")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.black.opacity(0.7))
            }
        }
        .layoutPriority(1)
    }
}

// MARK: - 预览
struct RecordingStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            Text("录音状态显示组件")
                .font(.headline)
            
            VStack(spacing: 20) {
                // 录音中状态
                RecordingStatusView(
                    recordingTime: 125.7,
                    isPaused: false
                )
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 4)
                
                // 暂停状态
                RecordingStatusView(
                    recordingTime: 85.3,
                    isPaused: true
                )
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 4)
                
                // 初始状态
                RecordingStatusView(
                    recordingTime: 0,
                    isPaused: false
                )
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}