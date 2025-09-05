//
//  AudioProcessingPipeline.swift
//  音频处理流水线 - 简化语音识别结果处理流程
//  优化 ESP32 → Adapter → LLM 的绕弯架构
//

import Foundation
import Combine
import AVFoundation

// MARK: - 音频处理流水线协议
protocol AudioProcessingPipelineDelegate: AnyObject {
    /// 录音开始
    func pipelineDidStartRecording(_ pipeline: AudioProcessingPipeline)
    
    /// 录音完成，开始处理
    func pipeline(_ pipeline: AudioProcessingPipeline, didFinishRecording audioData: Data, duration: TimeInterval)
    
    /// 创建初始录音记录（录音完成后立即创建）
    func pipeline(_ pipeline: AudioProcessingPipeline, didCreateInitialRecording recording: AudioRecording)
    
    /// 语音识别完成
    func pipeline(_ pipeline: AudioProcessingPipeline, didReceiveSpeechResult result: SpeechRecognitionResult)
    
    /// LLM分析第一步完成
    func pipeline(_ pipeline: AudioProcessingPipeline, didCompleteFirstStep result: FirstStepAnalysis)
    
    /// 完整处理完成，生成最终录音记录
    func pipeline(_ pipeline: AudioProcessingPipeline, didCompleteFinalAnalysis recording: AudioRecording)
    
    /// 处理失败
    func pipeline(_ pipeline: AudioProcessingPipeline, didFailWithError error: AudioProcessingError)
}

// MARK: - 音频处理错误类型
enum AudioProcessingError: Error, LocalizedError {
    case recordingFailed(Error)
    case speechRecognitionFailed(Error)
    case llmAnalysisFailed(Error)
    case pipelineCancelled
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed(let error):
            return "录音失败: \(error.localizedDescription)"
        case .speechRecognitionFailed(let error):
            return "语音识别失败: \(error.localizedDescription)"
        case .llmAnalysisFailed(let error):
            return "LLM分析失败: \(error.localizedDescription)"
        case .pipelineCancelled:
            return "处理流程已取消"
        }
    }
}

// MARK: - 音频处理流水线
class AudioProcessingPipeline: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var isPaused = false
    @Published var currentStage = ProcessingStage.idle
    @Published var progress: Float = 0.0
    @Published var isLLMEnabled = false  // LLM开关，默认开启
    
    // MARK: - Private Properties
    private let speechService: VolcEngineSpeechService
    private let llmService: TwoStepLLMService
    private var currentRecordingData: Data?
    private var currentDuration: TimeInterval = 0
    private var recordingStartTime: Date?
    private var currentRecordingId: UUID?
    
    // 手机录音相关
    private var audioRecorder: AVAudioRecorder?
    private var phoneRecordingTimer: Timer?
    private var pausedRecordingURL: URL?
    private var recordingSegments: [Data] = []
    
    // MARK: - Delegate
    weak var delegate: AudioProcessingPipelineDelegate?
    
    // MARK: - Processing Stages
    enum ProcessingStage {
        case idle
        case recording
        case speechRecognition
        case llmAnalysisFirstStep
        case llmAnalysisSecondStep
        case completed
        case failed
        
        var description: String {
            switch self {
            case .idle: return "空闲"
            case .recording: return "录音中"
            case .speechRecognition: return "语音识别中"
            case .llmAnalysisFirstStep: return "LLM分析(第一步)"
            case .llmAnalysisSecondStep: return "LLM分析(第二步)"
            case .completed: return "处理完成"
            case .failed: return "处理失败"
            }
        }
    }
    
    // MARK: - Initialization
    init(speechService: VolcEngineSpeechService? = nil, llmService: TwoStepLLMService? = nil) {
        self.speechService = speechService ?? VolcEngineSpeechService()
        self.llmService = llmService ?? TwoStepLLMService()
        
        super.init()
        setupServices()
    }
    
    // MARK: - Public Methods
    
    /// 开始录音处理流程（ESP32设备）
    func startRecording() {
        resetPipeline()
        isProcessing = true
        currentStage = .recording
        recordingStartTime = Date()
        progress = 0.1
        
        delegate?.pipelineDidStartRecording(self)
    }
    
    /// 开始手机录音处理流程
    func startPhoneRecording() {
        resetPipeline()
        isProcessing = true
        currentStage = .recording
        recordingStartTime = Date()
        progress = 0.1
        
        delegate?.pipelineDidStartRecording(self)
        
        // 开始手机录音
        setupAndStartPhoneRecording()
    }
    
    /// 接收录音数据（由ESP32AudioService调用）
    func processRecording(audioData: Data, duration: TimeInterval) {
        guard isProcessing, currentStage == .recording else { return }
        
        currentRecordingData = audioData
        currentDuration = duration
        
        delegate?.pipeline(self, didFinishRecording: audioData, duration: duration)
        
        // 立即创建初始录音记录
        let initialRecording = createInitialRecording(audioData: audioData, duration: duration)
        delegate?.pipeline(self, didCreateInitialRecording: initialRecording)
        
        // 直接开始语音识别
        startSpeechRecognition(audioData: audioData)
    }
    
    /// 停止录音（支持手机和ESP32）
    func stopRecording() {
        if let recorder = audioRecorder, recorder.isRecording {
            // 停止手机录音
            stopPhoneAudioRecording()
        } else if isPaused && currentStage == .recording {
            // 如果是暂停状态，直接处理录音片段
            processRecordingSegments()
            // 注意：不在这里重置状态，让processRecordingSegments()完成后再重置
            return
        } else {
            // 重置状态（只在非暂停状态下直接重置）
            isProcessing = false
            isPaused = false
            currentStage = .idle
            progress = 0.0
        }
        
        // ESP32录音由AudioManagerAdapter中的esp32Service处理
    }
    
    /// 暂停录音
    func pauseRecording() {
        guard isProcessing, currentStage == .recording, !isPaused else { return }
        
        isPaused = true
        
        if let recorder = audioRecorder, recorder.isRecording {
            // 暂停手机录音
            pausePhoneRecording()
        }
        
        // 暂停计时器
        phoneRecordingTimer?.invalidate()
        phoneRecordingTimer = nil
    }
    
    /// 恢复录音
    func resumeRecording() {
        guard isProcessing, currentStage == .recording, isPaused else { return }
        
        isPaused = false
        
        if audioRecorder != nil {
            // 恢复手机录音
            resumePhoneRecording()
        }
        
        // 恢复计时器
        startPhoneRecordingTimer()
    }
    
    /// 取消当前处理
    func cancelProcessing() {
        speechService.stopRecognition()
        llmService.stopAnalysis()
        
        // 停止手机录音
        if let recorder = audioRecorder, recorder.isRecording {
            stopPhoneAudioRecording()
        }
        
        isProcessing = false
        isPaused = false
        currentStage = .failed
        progress = 0.0
        
        delegate?.pipeline(self, didFailWithError: .pipelineCancelled)
    }
    
    // MARK: - Private Methods
    
    private func setupServices() {
        speechService.delegate = self
        llmService.delegate = self
    }
    
    private func resetPipeline() {
        currentRecordingData = nil
        currentDuration = 0
        recordingStartTime = nil
        currentRecordingId = nil
        progress = 0.0
        isPaused = false
        
        // 清理手机录音相关状态
        phoneRecordingTimer?.invalidate()
        phoneRecordingTimer = nil
        pausedRecordingURL = nil
        recordingSegments.removeAll()
    }
    
    private func startSpeechRecognition(audioData: Data) {
        currentStage = .speechRecognition
        progress = 0.3
        
        speechService.processRecordingAudio(audioData, duration: currentDuration)
    }
    
    private func startLLMAnalysis(recognitionText: String) {
        currentStage = .llmAnalysisFirstStep
        progress = 0.6
        
        if isLLMEnabled {
            // 使用真实LLM服务
            llmService.analyzeText(recognitionText)
        } else {
            // 返回模拟数据
            generateMockAnalysis(for: recognitionText)
        }
    }
    
    private func createInitialRecording(audioData: Data, duration: TimeInterval) -> AudioRecording {
        let recordingId = UUID()
        currentRecordingId = recordingId
        
        guard let startTime = recordingStartTime else {
            return AudioRecording(
                id: recordingId,
                timestamp: Date(),
                duration: duration,
                transcription: "处理中...",
                summary: "录音正在处理中",
                tags: [],
                audioData: audioData,
                enrichedContent: nil
            )
        }
        
        return AudioRecording(
            id: recordingId,
            timestamp: startTime,
            duration: duration,
            transcription: "处理中...",
            summary: "录音正在处理中",
            tags: [],
            audioData: audioData,
            enrichedContent: nil
        )
    }
    
    private func createFinalRecording(analysisResult: TwoStepAnalysisResult) -> AudioRecording {
        guard let audioData = currentRecordingData,
              let startTime = recordingStartTime else {
            // 创建fallback录音
            return AudioRecording(
                id: currentRecordingId,
                timestamp: Date(),
                duration: currentDuration,
                transcription: "录音处理失败",
                summary: "录音处理失败",
                tags: ["错误"],
                audioData: Data(),
                enrichedContent: nil
            )
        }
        
        return AudioRecording(
            id: currentRecordingId,
            timestamp: startTime,
            duration: currentDuration,
            transcription: analysisResult.originalText,
            summary: analysisResult.title,
            tags: analysisResult.tags,
            audioData: audioData,
            enrichedContent: analysisResult.enrichedContent
        )
    }
    
    private func completePipeline(with recording: AudioRecording) {
        currentStage = .completed
        progress = 1.0
        isProcessing = false
        
        delegate?.pipeline(self, didCompleteFinalAnalysis: recording)
    }
    
    private func failPipeline(with error: AudioProcessingError) {
        currentStage = .failed
        progress = 0.0
        isProcessing = false
        
        delegate?.pipeline(self, didFailWithError: error)
    }
    
    /// 生成模拟的LLM分析结果
    private func generateMockAnalysis(for text: String) {
        // 模拟第一步分析结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let firstStepResult = FirstStepAnalysis(
                title: "录音摘要",
                oneSentenceSummary: "这是一段模拟的录音内容摘要",
                thoughtType: .unknown,
                tags: ["模拟", "测试"],
                originalText: text,
                timestamp: Date()
            )
            
            self.currentStage = .llmAnalysisSecondStep
            self.progress = 0.8
            self.delegate?.pipeline(self, didCompleteFirstStep: firstStepResult)
            
            // 模拟第二步分析结果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                let finalResult = TwoStepAnalysisResult(
                    title: "录音摘要",
                    summary: "这是一段模拟的录音内容摘要",
                    thoughtType: .unknown,
                    tags: ["模拟", "测试"],
                    enrichedContent: "这是模拟的丰富内容，包含了对录音的详细分析和理解。",
                    originalText: text,
                    timestamp: Date()
                )
                
                let finalRecording = self.createFinalRecording(analysisResult: finalResult)
                self.completePipeline(with: finalRecording)
            }
        }
    }
}

// MARK: - VolcEngineSpeechServiceDelegate
extension AudioProcessingPipeline: VolcEngineSpeechServiceDelegate {
    func speechService(_ service: VolcEngineSpeechService, didReceiveResult result: SpeechRecognitionResult) {
        guard isProcessing, currentStage == .speechRecognition else { return }
        
        delegate?.pipeline(self, didReceiveSpeechResult: result)
        
        // 语音识别完成，开始LLM分析
        startLLMAnalysis(recognitionText: result.text)
    }
    
    func speechService(_ service: VolcEngineSpeechService, didCompleteWithError error: Error?) {
        if let error = error {
            failPipeline(with: .speechRecognitionFailed(error))
        }
        // 成功的情况已在didReceiveResult中处理
    }
    
    func speechServiceDidStartRecognition(_ service: VolcEngineSpeechService) {
        // 语音识别开始，无需额外处理
    }
    
    func speechServiceDidStopRecognition(_ service: VolcEngineSpeechService) {
        // 语音识别停止，无需额外处理
    }
}

// MARK: - TwoStepLLMServiceDelegate
extension AudioProcessingPipeline: TwoStepLLMServiceDelegate {
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFirstStep result: FirstStepAnalysis) {
        guard isProcessing, currentStage == .llmAnalysisFirstStep else { return }
        
        currentStage = .llmAnalysisSecondStep
        progress = 0.8
        
        delegate?.pipeline(self, didCompleteFirstStep: result)
    }
    
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFinalAnalysis result: TwoStepAnalysisResult) {
        guard isProcessing else { return }
        
        let finalRecording = createFinalRecording(analysisResult: result)
        completePipeline(with: finalRecording)
    }
    
    func twoStepLLMService(_ service: TwoStepLLMService, didFailWithError error: Error) {
        failPipeline(with: .llmAnalysisFailed(error))
    }
}

// MARK: - 便利方法
extension AudioProcessingPipeline {
    /// 获取当前处理阶段描述
    var currentStageDescription: String {
        return currentStage.description
    }
    
    /// 获取处理进度百分比
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    /// 检查是否正在处理特定阶段
    func isInStage(_ stage: ProcessingStage) -> Bool {
        return currentStage == stage
    }
    
    /// 切换LLM开关
    func toggleLLM() {
        isLLMEnabled.toggle()
    }
    
    /// 设置LLM开关状态
    func setLLMEnabled(_ enabled: Bool) {
        isLLMEnabled = enabled
    }
}

// 修复 AudioProcessingPipeline.swift 中的手机录音功能

extension AudioProcessingPipeline {
    
    /// 设置并开始手机录音（修复版）
    private func setupAndStartPhoneRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 1. 正确配置音频会话
            try audioSession.setCategory(.playAndRecord,
                                        mode: .measurement,  // 使用 measurement 模式获得更好的录音质量
                                        options: [.defaultToSpeaker, .allowBluetooth])
            
            // 2. 设置首选输入为内置麦克风
            if let builtInMic = audioSession.availableInputs?.first(where: {
                $0.portType == .builtInMic
            }) {
                try audioSession.setPreferredInput(builtInMic)
            }
            
            // 3. 激活音频会话
            try audioSession.setActive(true)
            
            // 4. 创建录音文件路径
            let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                        in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent(
                "recording_\(Date().timeIntervalSince1970).wav"
            )
            
            // 5. 优化的录音设置
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,  // 改为16kHz，与ESP32设置一致
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue  // 添加高质量设置
            ]
            
            // 6. 删除旧文件（如果存在）
            if FileManager.default.fileExists(atPath: audioFilename.path) {
                try FileManager.default.removeItem(at: audioFilename)
            }
            
            // 7. 创建并配置录音器
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()  // 添加准备录音
            
            // 8. 软启动录音，减少咔嗒声
            // 先以很低音量开始，然后快速提升到正常音量
            let recordingStarted = audioRecorder?.record() ?? false
            
            // 添加短暂延迟让系统稳定
            if recordingStarted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    // 确保录音器仍然有效并且在录音
                    guard let self = self, 
                          let recorder = self.audioRecorder,
                          recorder.isRecording else { return }
                    
                    // 录音器已稳定，可以开始正常处理
                    print("🎤 录音器已稳定启动")
                }
            }
            
            if recordingStarted {
                print("✅ 手机录音已开始")
                print("📁 录音文件路径: \(audioFilename.path)")
                
                // 开始计时器
                startPhoneRecordingTimer()
            } else {
                print("❌ 录音启动失败")
                throw NSError(domain: "AudioRecording",
                            code: -4,
                            userInfo: [NSLocalizedDescriptionKey: "无法启动录音"])
            }
            
        } catch {
            print("❌ 设置录音失败: \(error.localizedDescription)")
            failPipeline(with: .recordingFailed(error))
        }
    }
    
    /// 停止手机录音（修复版）
    private func stopPhoneAudioRecording() {
        phoneRecordingTimer?.invalidate()
        phoneRecordingTimer = nil
        
        guard let recorder = audioRecorder else {
            print("⚠️ 录音器不存在")
            // 如果有录音片段，尝试合并
            if !recordingSegments.isEmpty {
                processRecordingSegments()
            }
            return
        }
        
        // 记录当前时间和录音状态
        let isRecording = recorder.isRecording
        let recordingTime = currentDuration // 使用累计时长而不是recorder.currentTime
        
        print("📊 录音状态: \(isRecording ? "录音中" : "未录音")")
        print("⏱ 录音时长: \(recordingTime)秒")
        
        // 停止录音
        recorder.stop()
        
        // 等待文件写入完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // 检查文件是否存在并读取数据
            let fileURL = recorder.url
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let finalSegmentData = try Data(contentsOf: fileURL)
                    
                    // 添加最后一个录音片段
                    if finalSegmentData.count > 0 {
                        self.recordingSegments.append(finalSegmentData)
                        print("✅ 保存最终录音片段，大小: \(finalSegmentData.count / 1024) KB")
                    }
                    
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // 处理录音片段
                    self.processRecordingSegments()
                    
                } catch {
                    print("❌ 读取最终录音文件失败: \(error.localizedDescription)")
                    // 仍然尝试处理已有的片段
                    self.processRecordingSegments()
                }
            } else {
                print("❌ 最终录音文件不存在")
                // 仍然尝试处理已有的片段
                self.processRecordingSegments()
            }
            
            self.audioRecorder = nil
        }
        
        // 重置音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("⚠️ 重置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    /// 处理录音片段
    private func processRecordingSegments() {
        let finalAudioData: Data
        let finalDuration = currentDuration
        
        if recordingSegments.isEmpty {
            print("❌ 没有录音片段可处理")
            failPipeline(with: .recordingFailed(
                NSError(domain: "AudioRecording",
                      code: -8,
                      userInfo: [NSLocalizedDescriptionKey: "没有录音数据"])
            ))
            return
        }
        
        // 合并录音片段
        if let mergedData = mergeRecordingSegments() {
            finalAudioData = mergedData
        } else {
            print("❌ 合并录音片段失败")
            failPipeline(with: .recordingFailed(
                NSError(domain: "AudioRecording",
                      code: -9,
                      userInfo: [NSLocalizedDescriptionKey: "合并录音片段失败"])
            ))
            return
        }
        
        print("✅ 最终录音数据大小: \(finalAudioData.count / 1024) KB，时长: \(finalDuration)秒")
        
        if finalAudioData.count > 0 {
            currentRecordingData = finalAudioData
            
            delegate?.pipeline(self,
                               didFinishRecording: finalAudioData,
                               duration: finalDuration)
            
            // 立即创建初始录音记录
            let initialRecording = createInitialRecording(audioData: finalAudioData, duration: finalDuration)
            delegate?.pipeline(self, didCreateInitialRecording: initialRecording)
            
            startSpeechRecognition(audioData: finalAudioData)
        } else {
            print("❌ 最终录音文件为空")
            failPipeline(with: .recordingFailed(
                NSError(domain: "AudioRecording",
                      code: -5,
                      userInfo: [NSLocalizedDescriptionKey: "录音文件为空"])
            ))
        }
    }
    
    /// 增强的录音计时器（添加调试信息）
    private func startPhoneRecordingTimer() {
        phoneRecordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            self.currentDuration = recorder.currentTime
            
            // 获取音频级别用于调试
            let averagePower = recorder.averagePower(forChannel: 0)
            let peakPower = recorder.peakPower(forChannel: 0)
            
            // 每秒打印一次调试信息
            if Int(self.currentDuration * 10) % 10 == 0 {
                print("🎤 录音中 - 时长: \(String(format: "%.1f", self.currentDuration))s, 平均音量: \(averagePower)dB, 峰值: \(peakPower)dB")
            }
            
            // 检测是否有声音输入
            if averagePower < -160 {
                // -160 dB 表示静音，可能麦克风没有工作
                print("⚠️ 检测到静音，请检查麦克风权限和输入源")
            }
        }
    }
    
    /// 暂停手机录音
    private func pausePhoneRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        // 保存当前录音片段
        let currentURL = recorder.url
        recorder.stop()
        
        // 读取并保存当前录音数据
        if FileManager.default.fileExists(atPath: currentURL.path) {
            do {
                let segmentData = try Data(contentsOf: currentURL)
                recordingSegments.append(segmentData)
                print("✅ 保存录音片段，大小: \(segmentData.count / 1024) KB")
                
                // 删除临时文件
                try? FileManager.default.removeItem(at: currentURL)
            } catch {
                print("❌ 保存录音片段失败: \(error.localizedDescription)")
            }
        }
        
        pausedRecordingURL = currentURL
        print("⏸ 录音已暂停")
    }
    
    /// 恢复手机录音
    private func resumePhoneRecording() {
        guard pausedRecordingURL != nil else { return }
        
        do {
            // 创建新的录音文件
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let newAudioFilename = documentsPath.appendingPathComponent("recording_resume_\(Date().timeIntervalSince1970).wav")
            
            // 使用相同的录音设置
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // 删除旧文件（如果存在）
            if FileManager.default.fileExists(atPath: newAudioFilename.path) {
                try FileManager.default.removeItem(at: newAudioFilename)
            }
            
            // 创建新的录音器
            audioRecorder = try AVAudioRecorder(url: newAudioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // 开始新的录音
            let recordingStarted = audioRecorder?.record() ?? false
            
            if recordingStarted {
                print("▶️ 录音已恢复")
                pausedRecordingURL = nil
            } else {
                print("❌ 恢复录音失败")
                throw NSError(domain: "AudioRecording", code: -7, userInfo: [NSLocalizedDescriptionKey: "无法恢复录音"])
            }
            
        } catch {
            print("❌ 恢复录音设置失败: \(error.localizedDescription)")
            failPipeline(with: .recordingFailed(error))
        }
    }
    
    /// 合并所有录音片段
    private func mergeRecordingSegments() -> Data? {
        guard !recordingSegments.isEmpty else { return nil }
        
        // 如果只有一个片段，直接返回
        if recordingSegments.count == 1 {
            return recordingSegments.first
        }
        
        // 优化的音频片段合并，减少咔嗒声
        var mergedAudioData = Data()
        var totalSamples: UInt32 = 0
        
        for (index, segment) in recordingSegments.enumerated() {
            let audioData = extractAudioDataFromWAV(segment)
            
            if index == 0 {
                // 第一个片段：保留完整音频数据
                mergedAudioData.append(audioData)
                totalSamples += UInt32(audioData.count / 2) // 16位 = 2字节per样本
            } else {
                // 后续片段：应用渐变处理减少咔嗒声
                let processedAudio = applyCrossfade(mergedAudioData, newAudio: audioData)
                mergedAudioData = processedAudio
                totalSamples += UInt32(audioData.count / 2)
            }
        }
        
        // 创建新的WAV文件头
        let finalWAV = createWAVHeader(audioDataSize: mergedAudioData.count) + mergedAudioData
        
        print("✅ 合并了 \(recordingSegments.count) 个录音片段，总大小: \(finalWAV.count / 1024) KB，总采样数: \(totalSamples)")
        return finalWAV
    }
    
    /// 从WAV文件中提取纯音频数据
    private func extractAudioDataFromWAV(_ wavData: Data) -> Data {
        // WAV文件结构：RIFF头(12字节) + fmt块(24字节) + data块头(8字节) = 最少44字节
        // 但实际可能有其他块，需要找到"data"标识符
        
        guard wavData.count > 44 else { return wavData }
        
        // 查找"data"标识符 (0x64617461)
        let dataMarker: [UInt8] = [0x64, 0x61, 0x74, 0x61] // "data"
        
        for i in 0..<(wavData.count - 4) {
            let slice = wavData.subdata(in: i..<(i+4))
            if slice.elementsEqual(dataMarker) {
                // 找到data标记，跳过data标记(4字节) + 数据长度(4字节)
                let audioStartIndex = i + 8
                if audioStartIndex < wavData.count {
                    return wavData.subdata(in: audioStartIndex..<wavData.count)
                }
            }
        }
        
        // 如果找不到data标记，使用默认44字节偏移
        return wavData.subdata(in: 44..<wavData.count)
    }
    
    /// 应用交叉淡化减少咔嗒声
    private func applyCrossfade(_ existingAudio: Data, newAudio: Data) -> Data {
        let crossfadeSamples = 160 // 10ms at 16kHz (160 samples)
        let crossfadeBytes = crossfadeSamples * 2 // 16位 = 2字节per样本
        
        guard existingAudio.count >= crossfadeBytes,
              newAudio.count >= crossfadeBytes else {
            // 如果音频太短，直接拼接
            print("⚠️ 音频片段太短，跳过交叉淡化: existing=\(existingAudio.count), new=\(newAudio.count)")
            return existingAudio + newAudio
        }
        
        var result = Data(existingAudio)
        
        // 获取交叉淡化区域的数据 - 转换为Array以避免SubSequence索引问题
        let existingEndBytes = Array(existingAudio.suffix(crossfadeBytes))
        let newStartBytes = Array(newAudio.prefix(crossfadeBytes))
        
        print("🔄 应用交叉淡化: existing=\(existingEndBytes.count)字节, new=\(newStartBytes.count)字节, samples=\(crossfadeSamples)")
        
        // 应用交叉淡化
        var crossfadeData = Data()
        crossfadeData.reserveCapacity(crossfadeBytes)
        
        for i in 0..<crossfadeSamples {
            let byteIndex = i * 2
            
            // 安全边界检查
            guard byteIndex + 1 < existingEndBytes.count,
                  byteIndex + 1 < newStartBytes.count else {
                print("❌ 交叉淡化索引越界: i=\(i), byteIndex=\(byteIndex)")
                break
            }
            
            // 读取16位PCM样本 (小端序)
            let existingSample = Int16(existingEndBytes[byteIndex]) | (Int16(existingEndBytes[byteIndex + 1]) << 8)
            let newSample = Int16(newStartBytes[byteIndex]) | (Int16(newStartBytes[byteIndex + 1]) << 8)
            
            // 计算交叉淡化权重
            let fadeOut = Float(crossfadeSamples - i) / Float(crossfadeSamples)
            let fadeIn = Float(i) / Float(crossfadeSamples)
            
            // 混合样本
            let mixedSample = Int16(Float(existingSample) * fadeOut + Float(newSample) * fadeIn)
            
            // 写回数据 (小端序)
            crossfadeData.append(UInt8(mixedSample & 0xFF))
            crossfadeData.append(UInt8((mixedSample >> 8) & 0xFF))
        }
        
        // 替换重叠区域并添加剩余的新音频
        result.removeLast(crossfadeBytes)
        result.append(crossfadeData)
        result.append(newAudio.suffix(from: crossfadeBytes))
        
        print("✅ 交叉淡化完成: 最终大小=\(result.count)字节")
        return result
    }
    
    /// 创建WAV文件头
    private func createWAVHeader(audioDataSize: Int) -> Data {
        var header = Data()
        
        // RIFF头
        header.append("RIFF".data(using: .ascii)!) // ChunkID
        let fileSize = UInt32(36 + audioDataSize) // ChunkSize
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!) // Format
        
        // fmt子块
        header.append("fmt ".data(using: .ascii)!) // Subchunk1ID
        let fmtSize = UInt32(16) // Subchunk1Size
        header.append(withUnsafeBytes(of: fmtSize.littleEndian) { Data($0) })
        let audioFormat = UInt16(1) // PCM
        header.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
        let numChannels = UInt16(1) // Mono
        header.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        let sampleRate = UInt32(16000) // 16kHz
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        let byteRate = UInt32(16000 * 1 * 16 / 8) // SampleRate * NumChannels * BitsPerSample/8
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        let blockAlign = UInt16(1 * 16 / 8) // NumChannels * BitsPerSample/8
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        let bitsPerSample = UInt16(16)
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data子块
        header.append("data".data(using: .ascii)!) // Subchunk2ID
        let dataSize = UInt32(audioDataSize)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        return header
    }
}

// MARK: - 添加权限检查辅助方法
extension AudioProcessingPipeline {
    
    /// 检查并请求必要的权限
    func checkAndRequestPermissions(completion: @escaping (Bool) -> Void) {
        // 检查麦克风权限
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            print("✅ 麦克风权限已授权")
            completion(true)
            
        case .denied:
            print("❌ 麦克风权限被拒绝")
            completion(false)
            
        case .undetermined:
            print("🔔 请求麦克风权限")
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    print(granted ? "✅ 用户授权麦克风权限" : "❌ 用户拒绝麦克风权限")
                    completion(granted)
                }
            }
            
        @unknown default:
            completion(false)
        }
    }
    
    /// 诊断音频配置
    func diagnoseAudioConfiguration() {
        let session = AVAudioSession.sharedInstance()
        
        print("===== 音频配置诊断 =====")
        print("🎯 当前类别: \(session.category.rawValue)")
        print("🎯 当前模式: \(session.mode.rawValue)")
        print("🎯 采样率: \(session.sampleRate) Hz")
        print("🎯 输入通道数: \(session.inputNumberOfChannels)")
        print("🎯 当前输入: \(session.currentRoute.inputs.first?.portName ?? "无")")
        print("🎯 可用输入设备:")
        
        session.availableInputs?.forEach { input in
            print("  - \(input.portName) (\(input.portType.rawValue))")
        }
        
        print("========================")
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioProcessingPipeline: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            failPipeline(with: .recordingFailed(NSError(domain: "AudioRecording", code: -3, userInfo: [NSLocalizedDescriptionKey: "录音结束失败"])))
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            failPipeline(with: .recordingFailed(error))
        }
    }
}
