//
//  AudioProcessingPipeline.swift
//  音频处理流水线 - 简化语音识别结果处理流程
//  优化 ESP32 → Adapter → LLM 的绕弯架构
//

import Foundation
import Combine

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
    case audioProcessingError
    
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
        case .audioProcessingError:
            return "音频处理失败"
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
    @Published var isLLMEnabled = true  // LLM开关，默认关闭
    
    // MARK: - Private Properties
    private let speechService: VolcEngineSpeechService
    private let llmService: TwoStepLLMService
    private var currentRecordingData: Data?
    private var currentDuration: TimeInterval = 0
    private var recordingStartTime: Date?
    private var currentRecordingId: UUID?  // 当前录音的唯一ID，整个流程中保持不变
    
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
        
        print("🎙️ 开始新录音")
        delegate?.pipelineDidStartRecording(self)
    }
    
    /// 开始手机录音处理流程
    func startPhoneRecording() {
        resetPipeline()
        isProcessing = true
        currentStage = .recording
        recordingStartTime = Date()
        progress = 0.1
        
        print("📱 开始手机录音")
        delegate?.pipelineDidStartRecording(self)
    }
    
    /// 接收录音数据（由ESP32AudioService或PhoneRecordingManager调用）
    func processRecording(audioData: Data, duration: TimeInterval) {
        print("🔄 AudioProcessingPipeline.processRecording: 接收数据，大小: \(audioData.count / 1024) KB，时长: \(duration)秒")
        print("🔄 当前状态检查 - isProcessing: \(isProcessing), currentStage: \(currentStage)")
        
        // 如果pipeline未处于正确状态，重新启动处理流程
        if !isProcessing || currentStage != .recording {
            print("⚠️ Pipeline状态不正确，重新启动处理流程")
            print("🔍 当前currentRecordingId: \(currentRecordingId?.uuidString ?? "nil")")
            
            // 只重置状态，保持现有的录音ID（如果存在）
            let existingRecordingId = currentRecordingId
            resetPipelineStateOnly()
            
            // 如果之前没有录音ID，才生成新的
            if existingRecordingId == nil {
                currentRecordingId = UUID()
                print("🆔 为新录音会话生成ID: \(currentRecordingId?.uuidString ?? "unknown")")
            } else {
                currentRecordingId = existingRecordingId
                print("🔄 保持现有录音ID: \(currentRecordingId?.uuidString ?? "unknown")")
            }
            
            isProcessing = true
            currentStage = .recording
            progress = 0.1
            
            print("✅ Pipeline状态已重置，使用录音ID: \(currentRecordingId?.uuidString ?? "nil")")
        }
        
        currentRecordingData = audioData
        currentDuration = duration
        
        print("📢 通知代理：录音完成")
        delegate?.pipeline(self, didFinishRecording: audioData, duration: duration)
        
        // 立即创建初始录音记录
        let initialRecording = createInitialRecording(audioData: audioData, duration: duration)
        print("📝 创建初始录音记录，ID: \(initialRecording.id)")
        delegate?.pipeline(self, didCreateInitialRecording: initialRecording)
        
        // 直接开始语音识别
        print("🎤 开始语音识别")
        startSpeechRecognition(audioData: audioData)
    }
    
    /// 停止录音
    func stopRecording() {
        // 重置状态
        isProcessing = false
        isPaused = false
        currentStage = .idle
        progress = 0.0
    }
    
    /// 暂停录音
    func pauseRecording() {
        guard isProcessing, currentStage == .recording, !isPaused else { return }
        
        isPaused = true
    }
    
    /// 恢复录音
    func resumeRecording() {
        guard isProcessing, currentStage == .recording, isPaused else { return }
        
        isPaused = false
    }
    
    /// 取消当前处理
    func cancelProcessing() {
        speechService.stopRecognition()
        llmService.stopAnalysis()
        
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
        resetPipelineStateOnly()
        currentRecordingId = UUID()  // 为新录音生成唯一ID
        print("🆔 为新录音会话生成ID: \(currentRecordingId?.uuidString ?? "unknown")")
    }
    
    /// 只重置pipeline状态，不生成新的录音ID，保留录音相关数据
    private func resetPipelineStateOnly() {
        // 保留录音相关数据，因为我们仍在处理同一次录音
        // currentRecordingData = nil
        // currentDuration = 0 
        // recordingStartTime = nil
        progress = 0.0
        isPaused = false
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
        // 使用当前会话的UUID，确保整个流程中ID保持一致
        guard let recordingId = currentRecordingId else {
            fatalError("currentRecordingId 应该在 resetPipeline() 中被设置")
        }
        
        print("📝 创建初始录音记录，使用会话ID: \(recordingId.uuidString)")
        
        guard let startTime = recordingStartTime else {
            return AudioRecording(
                id: recordingId,
                timestamp: Date(),
                duration: duration,
                transcription: "处理中...",
                title: "录音处理中",
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
            title: "录音处理中",
            summary: "录音正在处理中",
            tags: [],
            audioData: audioData,
            enrichedContent: nil
        )
    }
    
    private func createFinalRecording(analysisResult: TwoStepAnalysisResult) -> AudioRecording {
        guard let audioData = currentRecordingData,
              let startTime = recordingStartTime,
              let recordingId = currentRecordingId else {
            // 创建fallback录音，使用当前会话ID或新UUID
            return AudioRecording(
                id: currentRecordingId ?? UUID(),
                timestamp: Date(),
                duration: currentDuration,
                transcription: "录音处理失败",
                title: "处理失败",
                summary: "录音处理失败",
                tags: ["错误"],
                audioData: Data(),
                enrichedContent: nil,
                polishedText: ""
            )
        }
        
        print("📝 创建LLM处理后的最终录音记录，使用相同会话ID: \(recordingId.uuidString)")
        
        return AudioRecording(
            id: recordingId,  // 使用相同的ID
            timestamp: startTime,
            duration: currentDuration,
            transcription: analysisResult.originalText,
            title: analysisResult.title,
            summary: analysisResult.summary,
            tags: analysisResult.tags,
            audioData: audioData,
            enrichedContent: analysisResult.enrichedContent,
            polishedText: analysisResult.polishedText
        )
    }
    
    private func completePipeline(with recording: AudioRecording) {
        print("🏁 完成流水线处理，录音ID: \(recording.id)")
        currentStage = .completed
        progress = 1.0
        isProcessing = false
        
        print("📢 通知代理：最终分析完成")
        delegate?.pipeline(self, didCompleteFinalAnalysis: recording)
    }
    
    private func failPipeline(with error: AudioProcessingError) {
        currentStage = .failed
        progress = 0.0
        isProcessing = false
        
        delegate?.pipeline(self, didFailWithError: error)
    }
    
    /// 直接使用语音识别结果创建最终录音记录（不使用LLM）
    private func createAndCompleteFinalRecordingWithSpeechResult(_ result: SpeechRecognitionResult) {
        guard let audioData = currentRecordingData,
              let startTime = recordingStartTime,
              let recordingId = currentRecordingId else {
            // 创建fallback录音，使用当前会话ID或新UUID
            print("⚠️ 创建fallback录音，原因：")
            print("   - currentRecordingData: \(currentRecordingData?.count ?? -1) bytes")
            print("   - recordingStartTime: \(recordingStartTime?.description ?? "nil")")
            print("   - currentRecordingId: \(currentRecordingId?.uuidString ?? "nil")")
            
            let fallbackRecording = AudioRecording(
                id: currentRecordingId ?? UUID(),
                timestamp: Date(),
                duration: currentDuration,
                transcription: result.text,
                title: "录音转录完成",
                summary: "录音转录完成",
                tags: ["录音"],
                audioData: Data(),
                enrichedContent: nil
            )
            completePipeline(with: fallbackRecording)
            return
        }
        
        print("📝 创建基于语音识别的最终录音记录，使用相同会话ID: \(recordingId.uuidString)")
        print("🎤 ASR返回的转录文本: \(result.text)")
        print("🎵 音频数据大小: \(audioData.count) bytes")
        
        // 创建基于语音识别结果的最终录音记录
        let finalRecording = AudioRecording(
            id: recordingId,  // 使用相同的ID
            timestamp: startTime,
            duration: currentDuration,
            transcription: result.text,
            title: "录音转录",
            summary: "录音转录 - \(result.text.prefix(20))...",
            tags: ["录音", "转录"],
            audioData: audioData,
            enrichedContent: nil
        )
        
        print("📝 不使用LLM，直接完成录音处理")
        print("🎯 最终录音记录创建完成 - ID: \(finalRecording.id), 转录: \(finalRecording.transcription)")
        completePipeline(with: finalRecording)
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
                polishedText: text,
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
                    polishedText: text,
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
        print("🎤✅ 语音识别完成，文本: \(result.text)")
        guard isProcessing, currentStage == .speechRecognition else { 
            print("❌ 语音识别结果被忽略，当前状态不正确 - isProcessing: \(isProcessing), currentStage: \(currentStage)")
            return 
        }
        
        delegate?.pipeline(self, didReceiveSpeechResult: result)
        
        // 检查识别结果是否为空
        let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            print("⚠️ 检测到空录音，直接结束流程")
            
            // 显示Toast提示
            DispatchQueue.main.async {
                ToastManager.shared.showWarning("录音内容为空，请重新录制")
            }
            
            // 重置流程状态，不保存到数据库
            currentStage = .idle
            progress = 0.0
            isProcessing = false
            
            // 清理录音数据
            currentRecordingData = nil
            currentDuration = 0
            recordingStartTime = nil
            
            return
        }
        
        // 语音识别完成，检查是否需要LLM分析
        if isLLMEnabled {
            print("🤖 开始LLM分析")
            // 开始LLM分析
            startLLMAnalysis(recognitionText: result.text)
        } else {
            print("⚡ 跳过LLM分析，直接创建最终录音记录")
            // 不使用LLM，直接创建最终录音记录
            createAndCompleteFinalRecordingWithSpeechResult(result)
        }
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
