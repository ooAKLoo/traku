//
//  ClassificationStage.swift
//  raku
//
//  分类阶段 - LLM分析（只处理数据，不产生副作用）
//

import Foundation

final class ClassificationStage: PipelineStage {
    let name = "内容分类"
    private let coordinator: AIAnalysisCoordinator
    private var isLLMEnabled: Bool

    /// 第一步完成后的回调，用于及时更新UI
    var onFirstStepComplete: ((ProcessingContext) -> Void)?

    init(coordinator: AIAnalysisCoordinator = AIAnalysisCoordinator(), isLLMEnabled: Bool = true) {
        self.coordinator = coordinator
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

    /// 仅执行基础分析（标题、分类、标签、润色）- 不执行内容丰富化
    func processFirstStepOnly(_ context: ProcessingContext) async throws -> ProcessingContext {
        guard let transcription = context.transcription else {
            throw ProcessingStageError.emptyTranscription
        }

        print("🤖 [\(name)] 开始基础分析（仅分类）")

        var updatedContext = context

        // 执行基础分析
        let basicResult = try await coordinator.performBasicAnalysis(transcription)
        updatedContext.firstStepAnalysis = basicResult.toFirstStepAnalysis()

        // 通知外部（用于及时更新UI）
        onFirstStepComplete?(updatedContext)

        print("🤖 [\(name)] 基础分析完成: \(updatedContext.thoughtType)")
        return updatedContext
    }

    func process(_ context: ProcessingContext) async throws -> ProcessingContext {
        guard let transcription = context.transcription else {
            throw ProcessingStageError.emptyTranscription
        }

        print("🤖 [\(name)] 开始完整AI分析")

        var updatedContext = context

        // 步骤1：基础分析
        let basicResult = try await coordinator.performBasicAnalysis(transcription)
        updatedContext.firstStepAnalysis = basicResult.toFirstStepAnalysis()

        // 通知外部基础分析已完成（用于及时更新UI）
        onFirstStepComplete?(updatedContext)

        // 步骤2：内容丰富化
        let enrichedContent = try await coordinator.performContentEnrichment(
            polishedText: basicResult.polishedText,
            thoughtType: basicResult.thoughtType
        )
        updatedContext.enrichedContent = enrichedContent

        print("🤖 [\(name)] 完整分析完成: \(updatedContext.thoughtType)")
        return updatedContext
    }
}
