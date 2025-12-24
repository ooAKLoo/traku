//
//  ClassificationStage.swift
//  raku
//
//  分类阶段 - LLM分析（只处理数据，不产生副作用）
//

import Foundation

final class ClassificationStage: PipelineStage {
    let name = "内容分类"
    private let llmService: TwoStepLLMService
    private var isLLMEnabled: Bool

    /// 第一步完成后的回调，用于及时更新UI
    var onFirstStepComplete: ((ProcessingContext) -> Void)?

    init(llmService: TwoStepLLMService = TwoStepLLMService(), isLLMEnabled: Bool = true) {
        self.llmService = llmService
        self.isLLMEnabled = isLLMEnabled
    }

    func setLLMEnabled(_ enabled: Bool) {
        isLLMEnabled = enabled
    }

    func shouldSkip(_ context: ProcessingContext) -> Bool {
        if !isLLMEnabled {
            print("⏭️ [\(name)] LLM已关闭，跳过分类阶段")
            return true
        }

        if context.transcription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            print("⏭️ [\(name)] 转录文本为空，跳过分类阶段")
            return true
        }

        return false
    }

    func process(_ context: ProcessingContext) async throws -> ProcessingContext {
        guard let transcription = context.transcription else {
            throw ProcessingStageError.emptyTranscription
        }

        print("🤖 [\(name)] 开始LLM分析")

        return try await withCheckedThrowingContinuation { continuation in
            let handler = ClassificationResultHandler(
                context: context,
                onFirstStepComplete: { [weak self] updatedContext in
                    self?.onFirstStepComplete?(updatedContext)
                },
                onComplete: { updatedContext in
                    print("🤖 [\(self.name)] 分类完成: \(updatedContext.thoughtType)")
                    continuation.resume(returning: updatedContext)
                },
                onError: { error in
                    print("❌ [\(self.name)] 分类失败: \(error.localizedDescription)")
                    continuation.resume(throwing: ProcessingStageError.classificationFailed(error))
                }
            )

            self.llmService.delegate = handler
            objc_setAssociatedObject(self.llmService, "handler", handler, .OBJC_ASSOCIATION_RETAIN)

            self.llmService.analyzeText(transcription, recordingId: context.id)
        }
    }
}

// MARK: - 分类结果处理器（纯数据处理，无副作用）
private class ClassificationResultHandler: NSObject, TwoStepLLMServiceDelegate {
    private var context: ProcessingContext
    private let onFirstStepComplete: (ProcessingContext) -> Void
    private let onComplete: (ProcessingContext) -> Void
    private let onError: (Error) -> Void
    private var hasCompleted = false

    init(
        context: ProcessingContext,
        onFirstStepComplete: @escaping (ProcessingContext) -> Void,
        onComplete: @escaping (ProcessingContext) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.context = context
        self.onFirstStepComplete = onFirstStepComplete
        self.onComplete = onComplete
        self.onError = onError
        super.init()
    }

    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFirstStep result: FirstStepAnalysis) {
        // 更新 context
        context.firstStepAnalysis = result
        print("📝 第一步完成: 标题=\(result.title), 类型=\(result.thoughtType)")

        // 通知外部，以便及时更新UI
        onFirstStepComplete(context)
    }

    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFinalAnalysis result: TwoStepAnalysisResult) {
        guard !hasCompleted else { return }
        hasCompleted = true

        // 更新 context
        context.enrichedContent = result.enrichedContent
        onComplete(context)
    }

    func twoStepLLMService(_ service: TwoStepLLMService, didFailWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        onError(error)
    }
}
