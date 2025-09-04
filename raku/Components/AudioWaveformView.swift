//
//  AudioWaveformView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//  从 AudioRecording.swift 中移出
//

import SwiftUI

// MARK: - 音频波形视图
struct AudioWaveformView: View {
    let levels: [Float]
    let isDarkMode: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<50, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                colorForLevel(getLevel(at: index)),
                                colorForLevel(getLevel(at: index)).opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: CGFloat(20 + getLevel(at: index) * 80))
                    .animation(.easeInOut(duration: 0.1), value: levels)
            }
        }
    }
    
    func getLevel(at index: Int) -> Float {
        guard index < levels.count else { return 0.1 }
        return levels[index]
    }
    
    func colorForLevel(_ level: Float) -> Color {
        if level > 0.7 {
            return Color.red
        } else if level > 0.4 {
            return Color.orange
        } else {
            return Color.green
        }
    }
}