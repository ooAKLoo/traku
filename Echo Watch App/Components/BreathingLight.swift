//
//  BreathingLight.swift
//  Echo Watch App
//
//  呼吸灯组件 - 极低亮度的视觉反馈
//

import SwiftUI

struct BreathingLight: View {
    let color: Color
    let intensity: Double       // 0.0 - 1.0
    let minOpacity: Double
    let maxOpacity: Double
    let duration: Double        // 呼吸周期

    @State private var isAnimating = false

    init(
        color: Color = .red,
        intensity: Double = 0.15,
        minOpacity: Double = 0.05,
        maxOpacity: Double = 0.2,
        duration: Double = 2.0
    ) {
        self.color = color
        self.intensity = intensity
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
        self.duration = duration
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        color.opacity(isAnimating ? maxOpacity * intensity : minOpacity * intensity),
                        color.opacity(0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 100
                )
            )
            .frame(width: 200, height: 200)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - 预设样式

extension BreathingLight {
    /// 录音中 - 红色呼吸灯 (提高可见度)
    static var recording: BreathingLight {
        BreathingLight(
            color: .red,
            intensity: 0.5,
            minOpacity: 0.15,
            maxOpacity: 0.4,
            duration: 1.2
        )
    }

    /// 待机中 - 极暗绿色呼吸灯
    static var idle: BreathingLight {
        BreathingLight(
            color: .green,
            intensity: 0.08,
            minOpacity: 0.02,
            maxOpacity: 0.1,
            duration: 3.0
        )
    }

    /// 就绪状态 - 柔和绿色呼吸灯 (明显可见)
    static var ready: BreathingLight {
        BreathingLight(
            color: .green,
            intensity: 0.35,
            minOpacity: 0.08,
            maxOpacity: 0.25,
            duration: 2.5
        )
    }

    /// 同步中 - 蓝色呼吸灯
    static var syncing: BreathingLight {
        BreathingLight(
            color: .blue,
            intensity: 0.35,
            minOpacity: 0.1,
            maxOpacity: 0.3,
            duration: 1.0
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BreathingLight.recording
    }
}
