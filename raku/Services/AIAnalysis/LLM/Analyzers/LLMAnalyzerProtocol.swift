//
//  LLMAnalyzerProtocol.swift
//  raku
//
//  核心协议层 - 定义分析器抽象和结果类型
//

import Foundation

// MARK: - 分析器协议

/// 分析器协议 - 支持独立的分析任务
protocol LLMAnalyzer {
    associatedtype Input
    associatedtype Output

    /// 执行分析任务
    func analyze(_ input: Input) async throws -> Output
}

// MARK: - 分析结果类型

/// 基础分析结果（标题、分类、标签、润色）
struct LiteAnalysisResult {
    let title: String
    let oneSentenceSummary: String?
    let thoughtType: FlashThoughtType
    let tags: [String]
    let originalText: String
    let polishedText: String
    let timestamp: Date

    /// 转换为 FirstStepAnalysis（兼容旧代码）
    func toFirstStepAnalysis() -> FirstStepAnalysis {
        return FirstStepAnalysis(
            title: title,
            oneSentenceSummary: oneSentenceSummary,
            thoughtType: thoughtType,
            tags: tags,
            originalText: originalText,
            polishedText: polishedText,
            timestamp: timestamp
        )
    }
}

/// 完整分析结果
struct FullAnalysisResult {
    let liteResult: LiteAnalysisResult
    let enrichedContent: String?
}

// MARK: - 兼容类型（用于保持与现有代码的兼容）

/// 第一步分析结果（用于 ProcessingContext 等现有代码）
typealias FirstStepAnalysis = LiteAnalysisResult

/// 最终分析结果（已废弃，建议使用 FullAnalysisResult）
@available(*, deprecated, message: "Use FullAnalysisResult instead")
struct TwoStepAnalysisResult {
    let title: String
    let summary: String
    let thoughtType: FlashThoughtType
    let tags: [String]
    let enrichedContent: String
    let originalText: String
    let polishedText: String
    let timestamp: Date
}
