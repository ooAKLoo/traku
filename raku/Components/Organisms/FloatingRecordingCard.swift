//
//  FloatingRecordingCard.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI
import Combine

// MARK: - 悬浮录音控制卡片（模块组件）
struct FloatingRecordingCard: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    @StateObject private var viewModel: RecordingControlViewModel
    @Namespace private var heroNamespace
    
    init(audioManager: AudioManagerAdapter) {
        self.audioManager = audioManager
        self._viewModel = StateObject(wrappedValue: RecordingControlViewModel(audioManager: audioManager))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 胶囊形状的录音控制区域
            capsuleControlView
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }
    
    // MARK: - 胶囊控制视图
    private var capsuleControlView: some View {
        ZStack {
            // 背景胶囊
            Capsule()
                .fill(Color.white)
                .frame(
                    width: viewModel.isRecording ? 220 : 70,
                    height: 70
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8)
            
            // 前景内容
            Group {
                if viewModel.isRecording {
                    // 录音状态的内容布局
                    RecordingControlPanel(
                        recordingTime: viewModel.recordingTime,
                        isPaused: viewModel.isPaused,
                        onTogglePause: {
                            withAnimation(.interpolatingSpring(
                                mass: 0.6,
                                stiffness: 200.0,
                                damping: 12.0
                            )) {
                                viewModel.togglePause()
                            }
                        },
                        onStop: {
                            withAnimation(.interpolatingSpring(
                                mass: 1.0,
                                stiffness: 120.0,
                                damping: 18.0
                            )) {
                                viewModel.stopRecording()
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity.combined(with: .scale(scale: 1.2))
                    ))
                } else {
                    // 待机状态的内容
                    standbyStateContent
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .scale(scale: 2.0).combined(with: .opacity)
                        ))
                }
            }
        }
        .onTapGesture {
            // 点击胶囊任意位置都可以切换状态（仅在待机时）
            if !viewModel.isRecording {
                withAnimation(.interpolatingSpring(
                    mass: 0.8,
                    stiffness: 150.0,
                    damping: 15.0,
                    initialVelocity: 5.0
                )) {
                    viewModel.startRecording()
                }
            }
        }
        .animation(.interpolatingSpring(
            mass: 1.0,
            stiffness: 120.0,
            damping: 18.0
        ), value: viewModel.isRecording)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isPaused)
    }
    
    // MARK: - 待机状态内容
    private var standbyStateContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "mic")
                .font(.system(size: 24, weight: .regular))
                .foregroundColor(.black)
        }
        .frame(width: 70, height: 70)
    }
}

// MARK: - 预览
struct FloatingRecordingCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            VStack {
                Spacer()
                
                // 主要的录音控制卡片
                FloatingRecordingCard(audioManager: AudioManagerAdapter(skipDatabaseLoad: true))
            }
        }
        .previewDisplayName("悬浮录音控制卡片")
    }
}