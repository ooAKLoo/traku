//
//  RecordingPipeline.swift
//  raku
//
//  录音处理流水线 - 核心协调器
//

import Foundation
import Combine
import UIKit

// MARK: - Pipeline代理协议
protocol RecordingPipelineDelegate: AnyObject {
    func pipeline(_ pipeline: RecordingPipeline, didStartProcessing context: ProcessingContext)
    func pipeline(_ pipeline: RecordingPipeline, didUpdateStage stage: PipelineStage, progress: Float)
    func pipeline(_ pipeline: RecordingPipeline, didCreateInitialRecording recording: AudioRecording)
    func pipeline(_ pipeline: RecordingPipeline, didComplete recording: AudioRecording)
    func pipeline(_ pipeline: RecordingPipeline, didFailWithError error: Error)
    func pipeline(_ pipeline: RecordingPipeline, didDeleteEmptyRecording recordingId: UUID)
}

// MARK: - RecordingPipeline
final class RecordingPipeline: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var currentStage: PipelineStage = .idle
    @Published var progress: Float = 0.0
    @Published var isLLMEnabled = true

    // MARK: - Delegate
    weak var delegate: RecordingPipelineDelegate?

    // MARK: - Private Properties
    private let asrStage: ASRStage
    private let classificationStage: ClassificationStage
    private let embeddingStage: EmbeddingStage
    private let metadataStage: MetadataStage
    private let updateManager = RecordingUpdateManager.shared
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization
    init() {
        self.asrStage = ASRStage()
        self.classificationStage = ClassificationStage()
        self.embeddingStage = EmbeddingStage()
        self.metadataStage = MetadataStage()
    }

    // MARK: - Public Methods

    /// 处理录音
    func processRecording(audioData: Data, duration: TimeInterval, source: RecordingSource = .phone, existingId: UUID? = nil, createdAt: Date? = nil) {
        let context = ProcessingContext(
            id: existingId ?? UUID(),
            audioData: audioData,
            duration: duration,
            createdAt: createdAt ?? Date(),
            source: source
        )

        processContext(context)
    }

    /// 处理Watch录音
    func processWatchRecording(audioData: Data, duration: TimeInterval, recordingId: String, createdAt: Date) {
        guard let uuid = UUID(uuidString: recordingId) else {
            print("❌ 无效的录音ID: \(recordingId)")
            return
        }

        let context = ProcessingContext(
            id: uuid,
            audioData: audioData,
            duration: duration,
            createdAt: createdAt,
            source: .watch
        )

        processContext(context)
    }

    /// 取消处理
    func cancelProcessing() {
        currentTask?.cancel()
        currentTask = nil

        isProcessing = false
        currentStage = .idle
        progress = 0.0

        endBackgroundTask()
    }

    /// 设置LLM开关
    func setLLMEnabled(_ enabled: Bool) {
        isLLMEnabled = enabled
        classificationStage.setLLMEnabled(enabled)
    }

    // MARK: - Private Methods

    private func processContext(_ context: ProcessingContext) {
        print("🚀 开始处理录音: ID=\(context.id), 来源=\(context.source)")

        isProcessing = true
        beginBackgroundTask()

        // 通知开始处理
        delegate?.pipeline(self, didStartProcessing: context)

        // 保存原始数据和创建初始记录
        saveInitialData(context)

        // 启动处理任务
        currentTask = Task { [weak self] in
            guard let self = self else { return }

            await self.runPipeline(context)
        }
    }

    private func saveInitialData(_ context: ProcessingContext) {
        updateStage(.saving)

        // 保存原始录音数据
        let recordingData = RawRecordingData(
            id: context.id,
            timestamp: context.createdAt,
            duration: context.duration,
            audioData: context.audioData,
            createdAt: Date()
        )
        let saveDataSuccess = DatabaseManager.shared.saveRecordingData(recordingData)
        print("💾 保存原始录音数据: \(saveDataSuccess ? "成功" : "失败")")

        // 创建初始录音记录
        let initialRecording = AudioRecording(
            id: context.id,
            timestamp: context.createdAt,
            duration: context.duration,
            transcription: "处理中...",
            title: "录音处理中",
            summary: "录音正在处理中",
            tags: context.source == .watch ? ["Watch"] : [],
            audioData: nil,
            enrichedContent: nil
        )

        let saveRecordingSuccess = DatabaseManager.shared.saveRecording(initialRecording)
        print("💾 保存初始录音记录: \(saveRecordingSuccess ? "成功" : "失败")")

        // 更新实时管理器
        updateManager.updateRecording(initialRecording)

        // 通知代理
        DispatchQueue.main.async {
            self.delegate?.pipeline(self, didCreateInitialRecording: initialRecording)
        }
    }

    @MainActor
    private func runPipeline(_ context: ProcessingContext) async {
        var currentContext = context

        do {
            // 阶段1: 语音识别
            updateStage(.speechRecognition)
            currentContext = try await asrStage.process(currentContext)

            // 检查转录结果是否为空
            let trimmedText = currentContext.transcription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedText.isEmpty {
                await handleEmptyTranscription(context.id)
                return
            }

            // 更新转录结果到数据库
            await updateTranscriptionResult(currentContext)

            // 阶段2: 分类和富化（如果启用LLM）
            if isLLMEnabled {
                updateStage(.classification)
                currentContext = try await classificationStage.process(currentContext)
            }

            // 阶段3: 向量生成
            updateStage(.embedding)
            if !embeddingStage.shouldSkip(currentContext) {
                currentContext = try await embeddingStage.process(currentContext)
            }

            // 阶段4: 元数据（天气等）
            updateStage(.metadata)
            currentContext = try await metadataStage.process(currentContext)

            // 完成处理
            await completeProcessing(currentContext)

        } catch {
            if Task.isCancelled {
                print("🚫 处理已取消")
                return
            }
            await handleError(error, context: context)
        }
    }

    @MainActor
    private func updateTranscriptionResult(_ context: ProcessingContext) async {
        let updatedRecording = AudioRecording(
            id: context.id,
            timestamp: context.createdAt,
            duration: context.duration,
            transcription: context.transcription ?? "",
            title: "录音转录",
            summary: "转录完成 - \((context.transcription ?? "").prefix(20))...",
            tags: [],
            audioData: nil,
            enrichedContent: nil
        )
        updateManager.updateRecording(updatedRecording)
    }

    @MainActor
    private func handleEmptyTranscription(_ recordingId: UUID) async {
        print("⚠️ 检测到空录音，清理数据")

        ToastManager.shared.showWarning("录音内容为空，请重新录制")

        // 删除数据库记录
        let deleteSuccess = DatabaseManager.shared.deleteRecording(id: recordingId)
        print("🗑️ 删除录音记录: \(deleteSuccess ? "成功" : "失败")")

        // 清理实时管理器
        updateManager.recordingUpdates.removeValue(forKey: recordingId)
        updateManager.processingRecordings.removeValue(forKey: recordingId)

        // 通知代理
        delegate?.pipeline(self, didDeleteEmptyRecording: recordingId)

        // 重置状态
        isProcessing = false
        currentStage = .idle
        progress = 0.0
        endBackgroundTask()
    }

    @MainActor
    private func completeProcessing(_ context: ProcessingContext) async {
        print("🏁 完成录音处理: ID=\(context.id)")

        updateStage(.completed)

        // 构建最终录音记录
        let finalRecording = context.buildRecording()

        // 保存到数据库
        let saveSuccess = DatabaseManager.shared.saveOrUpdateRecording(finalRecording)
        print("💾 保存最终录音记录: \(saveSuccess ? "成功" : "失败")")

        // 更新实时管理器
        updateManager.updateRecording(finalRecording)
        updateManager.updateProcessingStatus(for: context.id, stage: .completed, progress: 1.0)

        // 通知代理
        delegate?.pipeline(self, didComplete: finalRecording)

        // 重置状态
        isProcessing = false
        endBackgroundTask()
    }

    @MainActor
    private func handleError(_ error: Error, context: ProcessingContext) async {
        print("❌ 处理失败: \(error.localizedDescription)")

        updateStage(.failed)

        // 尝试保存已处理的部分
        let partialRecording = context.buildRecording()
        _ = DatabaseManager.shared.saveOrUpdateRecording(partialRecording)
        updateManager.updateRecording(partialRecording)

        // 通知代理
        delegate?.pipeline(self, didFailWithError: error)

        // 重置状态
        isProcessing = false
        endBackgroundTask()
    }

    private func updateStage(_ stage: PipelineStage) {
        DispatchQueue.main.async {
            self.currentStage = stage
            self.progress = stage.progress

            // 更新实时管理器（通过当前任务上下文获取recordingId）
            self.delegate?.pipeline(self, didUpdateStage: stage, progress: stage.progress)
        }
    }

    // MARK: - Background Task Management

    private func beginBackgroundTask() {
        guard backgroundTaskIdentifier == .invalid else { return }

        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "RecordingPipeline") { [weak self] in
            print("⚠️ 后台任务即将超时")
            self?.endBackgroundTask()
        }
        print("🔄 开始后台任务: \(backgroundTaskIdentifier.rawValue)")
    }

    private func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else { return }

        print("✅ 结束后台任务: \(backgroundTaskIdentifier.rawValue)")
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }
}
