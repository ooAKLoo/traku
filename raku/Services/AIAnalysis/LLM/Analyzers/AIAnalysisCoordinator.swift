//
//  AIAnalysisCoordinator.swift
//  raku
//
//  AI分析协调器 - 简化版：仅协调多步分析，支持灵活组合
//

import Foundation

final class AIAnalysisCoordinator {

    // MARK: - Properties

    private let basicAnalyzer: BasicAnalyzer
    private let contentEnricher: ContentEnricher

    /// 每个步骤完成后的回调（用于及时更新UI）
    var onStepComplete: ((String, Any) -> Void)?

    // MARK: - Initialization

    init(
        configuration: TwoStepLLMConfiguration = .default,
        basicAnalyzer: BasicAnalyzer? = nil,
        contentEnricher: ContentEnricher? = nil
    ) {
        self.basicAnalyzer = basicAnalyzer ?? BasicAnalyzer(configuration: configuration)
        self.contentEnricher = contentEnricher ?? ContentEnricher(configuration: configuration)
    }

    // MARK: - Public Methods

    /// 执行基础分析（标题、分类、标签、润色）
    func performBasicAnalysis(_ text: String) async throws -> LiteAnalysisResult {
        let result = try await basicAnalyzer.analyze(text)
        onStepComplete?("basicAnalysis", result)
        return result
    }

    /// 执行内容丰富化（需要先有基础分析结果）
    func performContentEnrichment(polishedText: String, thoughtType: FlashThoughtType) async throws -> String {
        let result = try await contentEnricher.analyze((polishedText, thoughtType))
        onStepComplete?("contentEnrichment", result)
        return result
    }

    /// 执行完整分析（基础分析 + 内容丰富化）
    func performFullAnalysis(_ text: String) async throws -> FullAnalysisResult {
        // 步骤1：基础分析
        let basicResult = try await performBasicAnalysis(text)

        // 步骤2：内容丰富化
        let enrichedContent = try await performContentEnrichment(
            polishedText: basicResult.polishedText,
            thoughtType: basicResult.thoughtType
        )

        return FullAnalysisResult(liteResult: basicResult, enrichedContent: enrichedContent)
    }
}
