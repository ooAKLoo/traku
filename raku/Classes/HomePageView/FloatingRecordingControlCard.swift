import SwiftUI
import Combine

// MARK: - 悬浮录音控制卡片（胶囊动画版本）
struct FloatingRecordingControlCard: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @Namespace private var heroNamespace
    
    // 计算属性：从AudioManager获取暂停状态
    private var isPaused: Bool {
        audioManager.isPaused
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
            Group {
                if isRecording {
                    recordingStateContent
                } else {
                    standbyStateContent
                }
            }
            Capsule()
                .fill(
                    LinearGradient(
                        colors: isRecording ?
                            ([Color.red.opacity(0.2), Color.red.opacity(0.4)]) :
                            [Color.blue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: isRecording ? 220 : 70,
                    height: 70
                )
            
            // 前景内容
            if isRecording {
                // 录音状态的内容布局
                recordingStateContent
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
        .onTapGesture {
            // 点击胶囊任意位置都可以切换状态（仅在待机时）
            if !isRecording {
                startRecording()
            }
        }
        .animation(.interpolatingSpring(
            mass: 1.0,
            stiffness: 120.0,
            damping: 18.0
        ), value: isRecording)
        .animation(.easeInOut(duration: 0.3), value: isPaused)
    }
    
    // MARK: - 录音状态内容
    private var recordingStateContent: some View {
        HStack(spacing: 16) {
            // 暂停/继续按钮
            Button(action: togglePause) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isPaused ? .green : .orange)
                }
            }
            .scaleEffect(isPaused ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isPaused)
            
            // 录音时间和状态显示
            VStack(spacing: 4) {
                Text(FormatHelper.formatDurationWithDecimal(recordingTime))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    // 录音状态指示点
                    Circle()
                        .fill(isPaused ? Color.white.opacity(0.8) : Color.white)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPaused ? 1.0 : 1.3)
                        .opacity(isPaused ? 0.7 : 1.0)
                        .animation(
                            isPaused ?
                                .easeInOut(duration: 0.3) :
                                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: !isPaused
                        )
                    
                    Text(isPaused ? "已暂停" : "录音中")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .layoutPriority(1)
            
            // 停止按钮
            Button(action: stopRecording) {
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
            .animation(.spring(response: 0.3), value: isRecording)
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 待机状态内容
    private var standbyStateContent: some View {
        VStack(spacing: 4) {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 2)
        }
        .frame(width: 70,height: 70)
    }
    
    // MARK: - 私有方法
    
    /// 开始录音
    private func startRecording() {
        // 使用平滑的弹性动画
        withAnimation(.interpolatingSpring(
            mass: 0.8,
            stiffness: 150.0,
            damping: 15.0,
            initialVelocity: 5.0
        )) {
            isRecording = true
        }
        
        startTimer()
        
        // 根据连接状态调用对应的录音方法
        if audioManager.isConnected {
            audioManager.startRecording()
        } else {
            audioManager.startPhoneRecording()
        }
    }
    
    /// 暂停/恢复录音
    private func togglePause() {
        withAnimation(.interpolatingSpring(
            mass: 0.6,
            stiffness: 200.0,
            damping: 12.0
        )) {
            if isPaused {
                // 当前是暂停状态，恢复录音
                audioManager.resumeRecording()
                startTimer()
            } else {
                // 当前是录音状态，暂停录音
                audioManager.pauseRecording()
                timer?.invalidate()
            }
        }
    }
    
    /// 停止录音
    private func stopRecording() {
        // 使用弹性动画回到初始状态
        withAnimation(.interpolatingSpring(
            mass: 1.0,
            stiffness: 120.0,
            damping: 18.0
        )) {
            isRecording = false
        }
        
        stopTimer()
        audioManager.stopRecording()
    }
    
    /// 启动计时器
    private func startTimer() {
        // 只在第一次开始录音时重置时间，恢复录音时不重置
        if !isPaused && recordingTime == 0 {
            recordingTime = 0
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // 只有在未暂停状态下才增加时间
            if !self.audioManager.isPaused {
                self.recordingTime += 0.1
            }
        }
    }
    
    /// 停止计时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingTime = 0
    }
}

// MARK: - 增强版预览
struct FloatingRecordingControlCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            
            VStack {
                Spacer()
                
                // 主要的录音控制卡片
                FloatingRecordingControlCard(audioManager: AudioManagerAdapter(skipDatabaseLoad: true))
                
            }
        }
        .previewDisplayName("胶囊动画录音控制")
    }
}
