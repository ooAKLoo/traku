//
//  RecordingView.swift
//  Echo Watch App
//
//  录音主界面 - 黑屏模式，全屏盲触
//

import SwiftUI
import Combine

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 深色渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.12),
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 呼吸灯效果
                if viewModel.isRecording {
                    BreathingLight.recording
                } else if !viewModel.isLocked {
                    BreathingLight.ready
                }

                // 主内容区域
                VStack(spacing: 16) {
                    Spacer()

                    // 中心交互区域
                    if viewModel.isRecording {
                        // 录音中状态
                        recordingStateView
                    } else if viewModel.isLocked {
                        // 锁定状态
                        lockedStateView
                    } else {
                        // 就绪状态
                        readyStateView
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // Digital Crown 解锁
        .focusable()
        .digitalCrownRotation(
            $viewModel.crownValue,
            from: 0,
            through: 1,
            by: 0.1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: viewModel.crownValue) { _, newValue in
            viewModel.handleCrownRotation(newValue)
        }
        // 全屏触控手势
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    viewModel.handleLongPress()
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    viewModel.handleDoubleTap()
                }
        )
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded {
                    viewModel.handleSingleTap()
                }
        )
        .onAppear {
            viewModel.onAppear()
        }
        // 监听 Action Button 触发录音
        .onReceive(NotificationCenter.default.publisher(for: .toggleRecording)) { _ in
            viewModel.toggleRecording()
        }
        // 监听来自 iPhone 的停止命令
        .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromPhone)) { _ in
            if viewModel.isRecording {
                viewModel.forceStopRecording()
            }
        }
    }

    // MARK: - 锁定状态视图

    private var lockedStateView: some View {
        VStack(spacing: 12) {
            // 锁定图标
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 70, height: 70)

                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            // 解锁提示
            VStack(spacing: 4) {
                Text("转动表冠")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                HStack(spacing: 4) {
                    Image(systemName: "digitalcrown.arrow.clockwise")
                        .font(.system(size: 12))
                    Text("解锁")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.4))
            }

            // 解锁进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: geo.size.width * viewModel.crownValue, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    // MARK: - 就绪状态视图

    private var readyStateView: some View {
        VStack(spacing: 16) {
            // 录音按钮
            ZStack {
                // 外圈
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 80, height: 80)

                // 内圈呼吸效果
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 70, height: 70)

                // 麦克风图标
                Image(systemName: "mic.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.green)
            }

            // 提示文字
            Text("点击录音")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    // MARK: - 录音中状态视图

    private var recordingStateView: some View {
        VStack(spacing: 12) {
            // 录音波形动画
            ZStack {
                // 脉冲圆环
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 2)
                    .frame(width: 90, height: 90)
                    .scaleEffect(viewModel.pulseScale)
                    .opacity(2 - viewModel.pulseScale)

                // 内圈
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 70, height: 70)

                // 录音图标
                Image(systemName: "waveform")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.red)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }

            // 时长显示
            Text(viewModel.formattedDuration)
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            // 停止提示
            Text("点击停止")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
        .onAppear {
            viewModel.startPulseAnimation()
        }
    }

}

// MARK: - ViewModel

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isLocked = false
    @Published var crownValue: Double = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var pulseScale: Double = 1.0

    private let audioRecorder = WatchAudioRecorder()
    private var durationTimer: Timer?
    private var pulseTimer: Timer?

    // 录音时长限制 (3分钟)
    private let maxRecordingDuration: TimeInterval = 180

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func onAppear() {
        HapticManager.shared.playReady()
    }

    // MARK: - Crown Handling

    func handleCrownRotation(_ value: Double) {
        if isLocked && value >= 0.8 {
            // 解锁
            isLocked = false
            crownValue = 0
            HapticManager.shared.playUnlock()
        }
    }

    // MARK: - Gesture Handling

    func handleSingleTap() {
        guard !isLocked else { return }

        if isRecording {
            // 单击结束录音
            stopRecording()
        } else {
            // 单击开始录音
            startRecording()
        }
    }

    func handleDoubleTap() {
        guard !isLocked else { return }

        if isRecording {
            // 双击也可以结束录音
            stopRecording()
        }
    }

    func handleLongPress() {
        guard !isLocked else { return }

        if !isRecording {
            // 长按开始录音 (备用方式)
            startRecording()
        }
    }

    // MARK: - Action Button Support

    /// 切换录音状态 (用于 Action Button)
    func toggleRecording() {
        // Action Button 按下时自动解锁
        isLocked = false

        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    /// 强制停止录音 (用于外部命令)
    func forceStopRecording() {
        if isRecording {
            stopRecording()
        }
    }

    // MARK: - Recording Control

    private func startRecording() {
        Task {
            do {
                _ = try await audioRecorder.startRecording()
                isRecording = true
                recordingDuration = 0
                HapticManager.shared.playStartRecording()

                // 启动时长计时器
                startDurationTimer()
            } catch {
                HapticManager.shared.playError()
                print("录音启动失败: \(error)")
            }
        }
    }

    private func stopRecording() {
        Task {
            do {
                let recordingInfo = try await audioRecorder.stopRecording()
                isRecording = false
                stopDurationTimer()
                HapticManager.shared.playStopRecording()

                // 触发同步
                await WatchConnectivityManager.shared.sendRecording(recordingInfo)

                print("录音完成: \(recordingInfo.duration)秒")
            } catch {
                HapticManager.shared.playError()
                print("录音停止失败: \(error)")
            }
        }
    }

    // MARK: - Timer

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.recordingDuration += 1

                // 检查是否达到时长限制
                if self.recordingDuration >= self.maxRecordingDuration - 10 {
                    // 还剩10秒时提醒
                    HapticManager.shared.playLongRecordingWarning()
                }

                if self.recordingDuration >= self.maxRecordingDuration {
                    // 达到限制，自动停止
                    self.stopRecording()
                }
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Pulse Animation

    func startPulseAnimation() {
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                withAnimation(.easeOut(duration: 1.5)) {
                    self.pulseScale = 1.5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.pulseScale = 1.0
                }
            }
        }
    }

    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulseScale = 1.0
    }
}

#Preview {
    RecordingView()
}
