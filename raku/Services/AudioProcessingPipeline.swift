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
class AudioProcessingPipeline: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var currentStage = ProcessingStage.idle
    @Published var progress: Float = 0.0
    
    // MARK: - Private Properties
    private let speechService: VolcEngineSpeechService
    private let llmService: TwoStepLLMService
    private var currentRecordingData: Data?
    private var currentDuration: TimeInterval = 0
    private var recordingStartTime: Date?
    
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
        
        setupServices()
    }
    
    // MARK: - Public Methods
    
    /// 开始录音处理流程
    func startRecording() {
        resetPipeline()
        isProcessing = true
        currentStage = .recording
        recordingStartTime = Date()
        progress = 0.1
        
        delegate?.pipelineDidStartRecording(self)
    }
    
    /// 接收录音数据（由ESP32AudioService调用）
    func processRecording(audioData: Data, duration: TimeInterval) {
        guard isProcessing, currentStage == .recording else { return }
        
        currentRecordingData = audioData
        currentDuration = duration
        
        delegate?.pipeline(self, didFinishRecording: audioData, duration: duration)
        
        // 直接开始语音识别
        startSpeechRecognition(audioData: audioData)
    }
    
    /// 取消当前处理
    func cancelProcessing() {
        speechService.stopRecognition()
        llmService.stopAnalysis()
        
        isProcessing = false
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
        progress = 0.0
    }
    
    private func startSpeechRecognition(audioData: Data) {
        currentStage = .speechRecognition
        progress = 0.3
        
        speechService.processRecordingAudio(audioData, duration: currentDuration)
    }
    
    private func startLLMAnalysis(recognitionText: String) {
        currentStage = .llmAnalysisFirstStep
        progress = 0.6
        
        llmService.analyzeText(recognitionText)
    }
    
    private func createFinalRecording(analysisResult: TwoStepAnalysisResult) -> AudioRecording {
        guard let audioData = currentRecordingData,
              let startTime = recordingStartTime else {
            // 创建fallback录音
            return AudioRecording(
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
}