//
//  AudioProcessingPipeline.swift
//  音频处理流水线 - 简化语音识别结果处理流程
//  优化 ESP32 → Adapter → LLM 的绕弯架构
//

import Foundation
import Combine
import UIKit

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
    private let updateManager = RecordingUpdateManager.shared
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    // 将Pipeline的ProcessingStage转换为UI的UIProcessingStage
    private func convertToUIStage(_ stage: ProcessingStage) -> UIProcessingStage {
        switch stage {
        case .idle: return .idle
        case .recording: return .recording
        case .speechRecognition: return .speechRecognition
        case .llmAnalysisFirstStep: return .llmAnalysisFirstStep
        case .llmAnalysisSecondStep: return .llmAnalysisSecondStep
        case .completed: return .completed
        case .failed: return .failed
        }
    }
    
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
        
        // 如果录音已被取消（currentRecordingId为nil且不在处理中），忽略数据
        if !isProcessing && currentRecordingId == nil {
            print("🚫 录音已取消，忽略接收到的音频数据")
            return
        }
        
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
        
        // 立即保存原始录音数据到独立表
        guard let recordingId = currentRecordingId else {
            print("❌ currentRecordingId 为空，无法保存录音数据")
            return
        }
        
        let recordingData = RawRecordingData(
            id: recordingId,
            timestamp: recordingStartTime ?? Date(),
            duration: duration,
            audioData: audioData,
            createdAt: Date()
        )
        
        let saveSuccess = DatabaseManager.shared.saveRecordingData(recordingData)
        print("💾 保存原始录音数据: \(saveSuccess ? "成功" : "失败")")
        
        // 立即创建初始录音记录
        let initialRecording = createInitialRecording(audioData: nil, duration: duration) // 不传递音频数据
        print("📝 创建初始录音记录，ID: \(initialRecording.id)")
        
        // 首先保存到数据库进行持久化
        let saveRecordingSuccess = DatabaseManager.shared.saveRecording(initialRecording)
        print("💾 保存初始录音记录到数据库: \(saveRecordingSuccess ? "成功" : "失败")")
        
        // 更新录音数据到实时管理器
        updateManager.updateRecording(initialRecording)
        
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
    
    /// 取消录音（不保存）
    func cancelRecording() {
        print("🚫 开始取消录音流程")
        
        // 停止所有正在进行的服务
        speechService.stopRecognition()
        llmService.stopAnalysis()
        
        // 重置状态
        isProcessing = false
        isPaused = false
        currentStage = .idle
        progress = 0.0
        
        // 清理当前录音数据
        currentRecordingData = nil
        currentDuration = 0
        recordingStartTime = nil
        currentRecordingId = nil
        
        print("🚫 录音已取消，未保存任何数据，不会进行ASR处理")
        // 注意：这里不调用 delegate?.pipeline 的失败回调，避免触发其他处理流程
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
        
        // 开始后台任务
        beginBackgroundTask()
        
        // 更新实时状态
        if let recordingId = currentRecordingId {
            updateManager.updateProcessingStatus(for: recordingId, stage: convertToUIStage(.speechRecognition), progress: 0.3)
        }
        
        speechService.processRecordingAudio(audioData, duration: currentDuration)
    }
    
    private func startLLMAnalysis(recognitionText: String) {
        currentStage = .llmAnalysisFirstStep
        progress = 0.6
        
        // 确保后台任务正在运行
        if backgroundTaskIdentifier == .invalid {
            beginBackgroundTask()
        }
        
        // 更新实时状态
        if let recordingId = currentRecordingId {
            updateManager.updateProcessingStatus(for: recordingId, stage: convertToUIStage(.llmAnalysisFirstStep), progress: 0.6)
        }
        
        // 使用真实LLM服务，传递录音ID
        llmService.analyzeText(recognitionText, recordingId: currentRecordingId)
    }
    
    private func createInitialRecording(audioData: Data?, duration: TimeInterval) -> AudioRecording {
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
        guard let startTime = recordingStartTime,
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
                audioData: nil,  // 不再在这里存储音频数据
                enrichedContent: nil,
                polishedText: ""
            )
        }
        
        print("📝 创建LLM处理后的最终录音记录，使用相同会话ID: \(recordingId.uuidString)")
        
        let contentType = analysisResult.thoughtType == .insight ? "inspiration" : "thinking"
        print("dataprocess--- AudioProcessingPipeline.createFinalRecording: ID=\(recordingId.uuidString.prefix(8)), thoughtType=\(analysisResult.thoughtType), 设置contentType=\(contentType)")
        
        return AudioRecording(
            id: recordingId,  // 使用相同的ID
            timestamp: startTime,
            duration: currentDuration,
            transcription: analysisResult.originalText,
            title: analysisResult.title,
            summary: analysisResult.summary,
            tags: analysisResult.tags,
            audioData: nil,  // 不再在这里存储音频数据
            enrichedContent: analysisResult.enrichedContent,
            polishedText: analysisResult.polishedText,
            contentType: contentType
        )
    }
    
    private func completePipeline(with recording: AudioRecording) {
        print("🏁 完成流水线处理，录音ID: \(recording.id)")
        currentStage = .completed
        progress = 1.0
        isProcessing = false
        
        // 结束后台任务
        endBackgroundTask()
        
        // 更新实时管理器的状态为完成
        updateManager.updateProcessingStatus(for: recording.id, stage: .completed, progress: 1.0)
        
        print("📢 通知代理：最终分析完成")
        delegate?.pipeline(self, didCompleteFinalAnalysis: recording)
    }
    
    private func failPipeline(with error: AudioProcessingError) {
        currentStage = .failed
        progress = 0.0
        isProcessing = false
        
        // 结束后台任务
        endBackgroundTask()
        
        delegate?.pipeline(self, didFailWithError: error)
    }
    
    /// 直接使用语音识别结果创建最终录音记录（不使用LLM）
    private func createAndCompleteFinalRecordingWithSpeechResult(_ result: SpeechRecognitionResult) {
        guard let startTime = recordingStartTime,
              let recordingId = currentRecordingId else {
            // 创建fallback录音，使用当前会话ID或新UUID
            print("⚠️ 创建fallback录音，原因：")
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
                audioData: nil,
                enrichedContent: nil
            )
            completePipeline(with: fallbackRecording)
            return
        }
        
        print("📝 创建基于语音识别的最终录音记录，使用相同会话ID: \(recordingId.uuidString)")
        print("🎤 ASR返回的转录文本: \(result.text)")
        
        
        // 创建基于语音识别结果的最终录音记录
        let finalRecording = AudioRecording(
            id: recordingId,  // 使用相同的ID
            timestamp: startTime,
            duration: currentDuration,
            transcription: result.text,
            title: "录音转录",
            summary: "录音转录 - \(result.text.prefix(20))...",
            tags: ["录音", "转录"],
            audioData: nil,  // 不再在这里存储音频数据
            enrichedContent: nil
        )
        
        print("📝 不使用LLM，直接完成录音处理")
        print("🎯 最终录音记录创建完成 - ID: \(finalRecording.id), 转录: \(finalRecording.transcription)")
        
        // 先保存录音记录到数据库和更新管理器
        updateManager.updateRecording(finalRecording)
        
        // 无LLM流程完成，生成基于转录文本的embedding
        print("🎯 无LLM流程完成，生成最终embedding")
        generateEmbeddingForRecording(
            recordingId: recordingId,
            thoughtType: .unknown,  // 无LLM时设为未分类
            polishedText: nil,
            transcription: result.text
        )
        
        // 后台获取天气信息
        print("🌤️ 开始获取天气信息（无LLM流程）...")
        Task {
            await self.fetchAndUpdateWeatherInfo(for: recordingId, updatedRecording: finalRecording)
        }
        
        completePipeline(with: finalRecording)
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
        
        // 立即更新转录文本到实时管理器
        if let recordingId = currentRecordingId {
            let updatedRecording = AudioRecording(
                id: recordingId,
                timestamp: recordingStartTime ?? Date(),
                duration: currentDuration,
                transcription: result.text,
                title: "录音转录",
                summary: "转录完成 - \(result.text.prefix(20))...",
                tags: ["录音", "转录"],
                audioData: nil,  // 不再传递音频数据
                enrichedContent: nil
            )
            updateManager.updateRecording(updatedRecording)
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
        
        // 更新处理状态到实时管理器
        if let recordingId = currentRecordingId {
            updateManager.updateProcessingStatus(for: recordingId, stage: convertToUIStage(.llmAnalysisSecondStep), progress: 0.8)
            
            // 更新录音数据（包含润色文本和正确的内容类型）
            let contentType = result.thoughtType == .insight ? "inspiration" : "thinking"
            print("dataprocess--- AudioProcessingPipeline.didCompleteFirstStep: ID=\(recordingId.uuidString.prefix(8)), thoughtType=\(result.thoughtType), 设置contentType=\(contentType)")
            let updatedRecording = AudioRecording(
                id: recordingId,
                timestamp: recordingStartTime ?? Date(),
                duration: currentDuration,
                transcription: result.originalText,
                title: result.title,
                summary: result.oneSentenceSummary ?? "处理中...",
                tags: result.tags,
                audioData: nil,  // 不再传递音频数据
                enrichedContent: nil,
                polishedText: result.polishedText ?? "",
                contentType: contentType
            )
            updateManager.updateRecording(updatedRecording)
            
            print("✅ 录音数据已更新，content_type设置为: \(contentType)")
            
            // 灵感类内容在第一步完成后即可生成embedding（LLM处理结束）
            if result.thoughtType == .insight {
                print("🎯 灵感类内容LLM处理完成，生成最终embedding")
                generateEmbeddingForRecording(
                    recordingId: recordingId,
                    thoughtType: result.thoughtType,
                    polishedText: result.polishedText,
                    transcription: result.originalText
                )
            } else {
                print("⏸️ 思考类内容，等待第二步完成后生成embedding")
            }
            
            // 后台线程获取天气信息
            print("🌤️ 开始获取天气信息...")
            Task {
                await self.fetchAndUpdateWeatherInfo(for: recordingId, updatedRecording: updatedRecording)
            }
        }
        
        delegate?.pipeline(self, didCompleteFirstStep: result)
    }
    
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFinalAnalysis result: TwoStepAnalysisResult) {
        guard isProcessing else { return }
        
        print("🎯 LLM第二步完成，准备更新状态")
        
        let finalRecording = createFinalRecording(analysisResult: result)
        
        // 先完成pipeline（这会清除处理状态）
        completePipeline(with: finalRecording)
        
        // 然后更新录音数据（但不会重新设置处理状态，因为already completed）
        updateManager.updateRecording(finalRecording)
        
        // 思考类内容在第二步完成后生成embedding（LLM处理结束）
        if let recordingId = currentRecordingId {
            print("🎯 LLM第二步完成，生成最终embedding")
            generateEmbeddingForRecording(
                recordingId: recordingId,
                thoughtType: result.thoughtType,
                polishedText: result.polishedText,
                enrichedContent: result.enrichedContent,
                transcription: result.originalText
            )
        }
        
        // 在LLM完成后也需要更新天气信息到最终记录
        print("🌤️ LLM完成，更新最终记录的天气信息...")
        if let recordingId = currentRecordingId {
            Task {
                await self.fetchAndUpdateWeatherInfo(for: recordingId, updatedRecording: finalRecording)
            }
        }
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
    
    // MARK: - 后台任务管理
    
    private func beginBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            return  // 已经有后台任务在运行
        }
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "AudioProcessing") { [weak self] in
            print("⚠️ 后台任务即将超时，尝试结束处理")
            self?.endBackgroundTask()
        }
        
        print("🔄 开始后台任务: \(backgroundTaskIdentifier.rawValue)")
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            print("✅ 结束后台任务: \(backgroundTaskIdentifier.rawValue)")
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
    
    // MARK: - 天气信息处理
    
    /// 在后台线程获取并更新录音的天气信息
    @MainActor
    private func fetchAndUpdateWeatherInfo(for recordingId: UUID, updatedRecording: AudioRecording) async {
        do {
            // 获取天气信息
            let weatherData = try await WeatherService.shared.getWeatherForNote(noteId: recordingId.uuidString)
            
            // 创建包含天气信息的录音记录
            var recordingWithWeather = updatedRecording
            recordingWithWeather.setWeather(weatherData)
            
            // 更新数据库
            let success = try await DatabaseManager.shared.recordingRepository.update(recordingWithWeather)
            
            if success {
                // 更新实时管理器
                updateManager.updateRecording(recordingWithWeather)
                print("✅ [Pipeline] 天气信息已更新: \(weatherData.type.displayName) @ \(weatherData.location)")
            } else {
                print("❌ [Pipeline] 天气信息数据库更新失败")
            }
            
        } catch {
            print("⚠️ [Pipeline] 天气信息获取失败，使用默认值: \(error.localizedDescription)")
            
            // 设置默认天气信息
            var recordingWithDefaultWeather = updatedRecording
            recordingWithDefaultWeather.weather = .sunny
            recordingWithDefaultWeather.weatherLocation = "位置未知"
            
            // 更新数据库
            do {
                let success = try await DatabaseManager.shared.recordingRepository.update(recordingWithDefaultWeather)
                if success {
                    updateManager.updateRecording(recordingWithDefaultWeather)
                    print("✅ [Pipeline] 已设置默认天气信息")
                }
            } catch {
                print("❌ [Pipeline] 默认天气信息更新失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 统一的embedding生成方法 - 根据录音类型和内容生成合适的embedding
    /// - Parameters:
    ///   - recordingId: 录音ID
    ///   - thoughtType: 思想类型
    ///   - polishedText: 润色文本
    ///   - enrichedContent: 富化内容（可选，仅思考类内容有）
    ///   - transcription: 原始转录文本（备选）
    private func generateEmbeddingForRecording(
        recordingId: UUID,
        thoughtType: FlashThoughtType,
        polishedText: String?,
        enrichedContent: String? = nil,
        transcription: String? = nil
    ) {
        print("🔄 为录音生成embedding - ID: \(recordingId.uuidString.prefix(8)), 类型: \(thoughtType.rawValue)")
        
        // 根据类型决定embedding内容
        let embeddingContent: String?
        
        switch thoughtType {
        case .insight:
            // 灵感类：使用润色文本，如果没有则使用转录文本
            embeddingContent = polishedText ?? transcription
            print("  📝 灵感类内容，使用润色文本生成embedding")
            
        case .reflection:
            // 思考类：组合润色文本和富化内容
            if let polished = polishedText, let enriched = enrichedContent {
                embeddingContent = combineContentForEmbedding(polishedText: polished, enrichedContent: enriched)
                print("  📝 思考类内容，使用润色文本+富化内容生成embedding")
            } else {
                embeddingContent = polishedText ?? transcription
                print("  ⚠️ 思考类内容缺少富化内容，使用润色文本生成embedding")
            }
            
        case .unknown:
            // 未分类：优先使用润色文本，否则使用转录文本
            embeddingContent = polishedText ?? transcription
            print("  📝 未分类内容，使用可用文本生成embedding")
        }
        
        guard let content = embeddingContent, !content.isEmpty else {
            print("  ❌ 没有可用内容生成embedding，跳过")
            return
        }
        
        VolcEngineEmbeddingService.shared.generateEmbeddings(
            for: recordingId.uuidString,
            title: nil,  // 不使用标题
            tags: [],    // 不使用标签
            polishedText: content,
            transcription: nil
        ) { embeddingResult in
            switch embeddingResult {
            case .success(let embeddings):
                DatabaseManager.shared.saveEmbeddings(embeddings)
                print("✅ [Pipeline] Embedding生成成功 - 录音ID: \(recordingId.uuidString.prefix(8)), 类型: \(thoughtType.rawValue)")
            case .failure(let error):
                print("❌ [Pipeline] Embedding生成失败 - 录音ID: \(recordingId.uuidString.prefix(8)), 错误: \(error)")
            }
        }
    }
    
    /// 组合润色文本和富化内容，用于生成思考类内容的embedding
    private func combineContentForEmbedding(polishedText: String, enrichedContent: String) -> String {
        // 将润色文本和富化内容组合，中间用分隔符分开
        var components: [String] = []
        
        // 添加润色文本
        if !polishedText.isEmpty {
            components.append(polishedText)
        }
        
        // 添加富化内容
        if !enrichedContent.isEmpty {
            components.append(enrichedContent)
        }
        
        // 用换行符连接，让两部分内容有清晰的分隔
        let combinedText = components.joined(separator: "\n\n")
        
        print("    📎 组合内容详情:")
        print("      - 润色文本长度: \(polishedText.count)")
        print("      - 富化内容长度: \(enrichedContent.count)")
        print("      - 组合后总长度: \(combinedText.count)")
        
        return combinedText
    }
}
