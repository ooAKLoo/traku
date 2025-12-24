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
    @ObservedObject var audioManager: AudioRecordingService
    @StateObject private var viewModel: HomeControlsViewModel
    @Namespace private var heroNamespace

    let isDarkMode: Bool

    init(audioManager: AudioRecordingService, isDarkMode: Bool = false) {
        self.audioManager = audioManager
        self.isDarkMode = isDarkMode
        self._viewModel = StateObject(wrappedValue: HomeControlsViewModel(audioManager: audioManager))
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
        HStack(spacing: 12) {
            // 主录音胶囊
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
                        // 录音状态的内容布局（移除了取消按钮）
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
            .contentShape(Capsule())
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
            
            // 取消按钮（只在录音时显示）
            if viewModel.isRecording {
                Button(action: {
                    withAnimation(.interpolatingSpring(
                        mass: 1.0,
                        stiffness: 120.0,
                        damping: 18.0
                    )) {
                        viewModel.cancelRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 68, height: 68)
                            .shadow(color: Color.black.opacity(0.1), radius: 8)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .scale(scale: 1.2).combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - 待机状态内容
    private var standbyStateContent: some View {
        VStack(spacing: 4) {
            // 显示麦克风图标
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
        Group {
            // 普通模式预览
            ZStack {
                VStack {
                    Spacer()

                    FloatingRecordingCard(
                        audioManager: AudioRecordingService(skipDatabaseLoad: true),
                        isDarkMode: false
                    )
                }
            }
            .previewDisplayName("Light Mode")

            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()

                    FloatingRecordingCard(
                        audioManager: AudioRecordingService(skipDatabaseLoad: true),
                        isDarkMode: true
                    )
                }
            }
            .previewDisplayName("Dark Mode")
        }
    }
}
