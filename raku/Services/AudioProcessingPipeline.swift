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
        }
        // ESP32录音由AudioManagerAdapter中的esp32Service处理
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
        
        // 清理手机录音相关状态
        phoneRecordingTimer?.invalidate()
        phoneRecordingTimer = nil
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
            
            // 8. 开始录音
            let recordingStarted = audioRecorder?.record() ?? false
            
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
            return
        }
        
        // 记录当前时间和录音状态
        let isRecording = recorder.isRecording
        let recordingTime = recorder.currentTime
        
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
                    let audioData = try Data(contentsOf: fileURL)
                    let fileSize = audioData.count
                    
                    print("✅ 录音文件读取成功")
                    print("📏 文件大小: \(fileSize / 1024) KB")
                    
                    if fileSize > 0 {
                        self.currentRecordingData = audioData
                        self.currentDuration = recordingTime
                        
                        self.delegate?.pipeline(self,
                                               didFinishRecording: audioData,
                                               duration: recordingTime)
                        
                        // 立即创建初始录音记录
                        let initialRecording = self.createInitialRecording(audioData: audioData, duration: recordingTime)
                        self.delegate?.pipeline(self, didCreateInitialRecording: initialRecording)
                        
                        self.startSpeechRecognition(audioData: audioData)
                    } else {
                        print("❌ 录音文件为空")
                        self.failPipeline(with: .recordingFailed(
                            NSError(domain: "AudioRecording",
                                  code: -5,
                                  userInfo: [NSLocalizedDescriptionKey: "录音文件为空"])
                        ))
                    }
                    
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: fileURL)
                    
                } catch {
                    print("❌ 读取录音文件失败: \(error.localizedDescription)")
                    self.failPipeline(with: .recordingFailed(error))
                }
            } else {
                print("❌ 录音文件不存在")
                self.failPipeline(with: .recordingFailed(
                    NSError(domain: "AudioRecording",
                          code: -6,
                          userInfo: [NSLocalizedDescriptionKey: "录音文件不存在"])
                ))
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
