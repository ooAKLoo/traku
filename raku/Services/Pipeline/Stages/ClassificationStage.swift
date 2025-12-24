//
//  ClassificationStage.swift
//  raku
//
//  分类阶段 - LLM第一步分析
//

import Foundation

final class ClassificationStage: ProcessingStage {
    let name = "内容分类"
    private let llmService: TwoStepLLMService
    private var isLLMEnabled: Bool

    init(llmService: TwoStepLLMService = TwoStepLLMService(), isLLMEnabled: Bool = true) {
        self.llmService = llmService
        self.isLLMEnabled = isLLMEnabled
    }

    func setLLMEnabled(_ enabled: Bool) {
        isLLMEnabled = enabled
    }

    func shouldSkip(_ context: ProcessingContext) -> Bool {
        // 跳过条件：LLM关闭 或 转录文本为空
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

        print("🤖 [\(name)] 开始LLM第一步分析")

        return try await withCheckedThrowingContinuation { continuation in
            let handler = ClassificationResultHandler(context: context) { updatedContext in
                print("🤖 [\(self.name)] 分类完成: \(updatedContext.thoughtType)")
                continuation.resume(returning: updatedContext)
            } onError: { error in
                print("❌ [\(self.name)] 分类失败: \(error.localizedDescription)")
                continuation.resume(throwing: ProcessingStageError.classificationFailed(error))
            }

            self.llmService.delegate = handler
            objc_setAssociatedObject(self.llmService, "handler", handler, .OBJC_ASSOCIATION_RETAIN)

            self.llmService.analyzeText(transcription, recordingId: context.id)
        }
    }
}

// MARK: - 分类结果处理器
private class ClassificationResultHandler: NSObject, TwoStepLLMServiceDelegate {
    private var context: ProcessingContext
    private let onComplete: (ProcessingContext) -> Void
    private let onError: (Error) -> Void
    private var hasCompleted = false

    init(context: ProcessingContext, onComplete: @escaping (ProcessingContext) -> Void, onError: @escaping (Error) -> Void) {
        self.context = context
        self.onComplete = onComplete
        self.onError = onError
        super.init()
    }

    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFirstStep result: FirstStepAnalysis) {
        context.firstStepAnalysis = result

        // 灵感类直接完成，不需要第二步
        if result.thoughtType == .insight {
            guard !hasCompleted else { return }
            hasCompleted = true
            onComplete(context)
        }
        // 思考类等待第二步完成
    }

    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFinalAnalysis result: TwoStepAnalysisResult) {
        guard !hasCompleted else { return }
        hasCompleted = true

        // 更新富化内容
        context.enrichedContent = result.enrichedContent
        onComplete(context)
    }

    func twoStepLLMService(_ service: TwoStepLLMService, didFailWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        onError(error)
    }
}
