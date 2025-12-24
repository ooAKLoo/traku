//
//  RecordingPipeline.swift
//  raku
//
//  录音处理流水线 - 纯协调器
//  职责：协调各阶段执行，统一管理状态更新
//

import Foundation
import UIKit

final class RecordingPipeline: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var currentStage: ProcessingStage = .idle
    @Published var isLLMEnabled = true

    // MARK: - Private Properties
    private let asrStage: ASRStage
    private let classificationStage: ClassificationStage
    private let embeddingStage: EmbeddingStage
    private let metadataStage: MetadataStage
    private let store = RecordingStore.shared
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var currentTask: Task<Void, Never>?

    // MARK: - Initialization
    init() {
        self.asrStage = ASRStage()
        self.classificationStage = ClassificationStage()
        self.embeddingStage = EmbeddingStage()
        self.metadataStage = MetadataStage()

        // 设置第一步完成回调，及时更新UI
        self.classificationStage.onFirstStepComplete = { [weak self] context in
            Task { @MainActor in
                self?.syncToStore(context)
            }
        }
    }

    // MARK: - Public Methods

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

    func cancelProcessing() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        currentStage = .idle
        endBackgroundTask()
    }

    func setLLMEnabled(_ enabled: Bool) {
        isLLMEnabled = enabled
        classificationStage.setLLMEnabled(enabled)
    }

    // MARK: - Private Methods

    private func processContext(_ context: ProcessingContext) {
        print("🚀 开始处理录音: ID=\(context.id), 来源=\(context.source)")

        isProcessing = true
        beginBackgroundTask()

        // 保存原始数据和创建初始记录
        saveInitialData(context)

        // 启动处理任务
        currentTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.runPipeline(context)
        }
    }

    private func saveInitialData(_ context: ProcessingContext) {
        updateStage(.saving, for: context.id)

        // 保存原始录音数据
        let recordingData = RawRecordingData(
            id: context.id,
            timestamp: context.createdAt,
            duration: context.duration,
            audioData: context.audioData,
            createdAt: Date()
        )
        _ = DatabaseManager.shared.saveRecordingData(recordingData)

        // 创建初始录音记录
        let initialRecording = AudioRecording(
            id: context.id,
            timestamp: context.createdAt,
            duration: context.duration,
            transcription: "处理中...",
            title: "录音处理中",
            summary: "",
            tags: context.source == .watch ? ["Watch"] : [],
            audioData: nil,
            enrichedContent: nil
        )

        // 通过 Store 统一更新
        Task { @MainActor in
            store.updateRecording(initialRecording)
        }
    }

    @MainActor
    private func runPipeline(_ context: ProcessingContext) async {
        var ctx = context

        do {
            // 阶段1: 语音识别
            updateStage(.speechRecognition, for: ctx.id)
            ctx = try await asrStage.process(ctx)

            // 检查转录结果是否为空
            let trimmedText = ctx.transcription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedText.isEmpty {
                await handleEmptyTranscription(ctx.id)
                return
            }

            // ASR完成，更新Store
            syncToStore(ctx)

            // 阶段2: 分类和富化
            if isLLMEnabled {
                updateStage(.classification, for: ctx.id)
                ctx = try await classificationStage.process(ctx)
                // 分类完成，更新Store（标题、标签、enrichedContent）
                syncToStore(ctx)
            }

            // 阶段3: 向量生成
            updateStage(.embedding, for: ctx.id)
            if !embeddingStage.shouldSkip(ctx) {
                ctx = try await embeddingStage.process(ctx)
            }

            // 阶段4: 元数据
            updateStage(.metadata, for: ctx.id)
            ctx = try await metadataStage.process(ctx)

            // 完成处理
            await completeProcessing(ctx)

        } catch {
            if Task.isCancelled {
                print("🚫 处理已取消")
                return
            }
            await handleError(error, context: ctx)
        }
    }

    /// 同步context到Store
    @MainActor
    private func syncToStore(_ context: ProcessingContext) {
        let recording = context.buildRecording()
        store.updateRecording(recording)
    }

    @MainActor
    private func handleEmptyTranscription(_ recordingId: UUID) async {
        print("⚠️ 检测到空录音，清理数据")

        ToastManager.shared.showWarning("录音内容为空，请重新录制")

        // 通过 Store 统一删除
        store.deleteRecording(id: recordingId)

        // 重置状态
        isProcessing = false
        currentStage = .idle
        endBackgroundTask()
    }

    @MainActor
    private func completeProcessing(_ context: ProcessingContext) async {
        print("🏁 完成录音处理: ID=\(context.id)")

        // 构建最终录音记录并更新Store
        let finalRecording = context.buildRecording()
        store.updateRecording(finalRecording)

        // 清除处理状态
        store.clearProcessingState(for: context.id)

        // 重置Pipeline状态
        isProcessing = false
        currentStage = .completed
        endBackgroundTask()
    }

    @MainActor
    private func handleError(_ error: Error, context: ProcessingContext) async {
        print("❌ 处理失败: \(error.localizedDescription)")

        updateStage(.failed, for: context.id)

        // 保存已处理的部分
        let partialRecording = context.buildRecording()
        store.updateRecording(partialRecording)

        // 延迟清除失败状态
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                store.clearProcessingState(for: context.id)
            }
        }

        // 重置状态
        isProcessing = false
        endBackgroundTask()
    }

    private func updateStage(_ stage: ProcessingStage, for recordingId: UUID) {
        Task { @MainActor in
            self.currentStage = stage
            store.setProcessingState(for: recordingId, stage: stage)
        }
    }

    // MARK: - Background Task Management

    private func beginBackgroundTask() {
        guard backgroundTaskIdentifier == .invalid else { return }

        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "RecordingPipeline") { [weak self] in
            print("⚠️ 后台任务即将超时")
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
    }
}
