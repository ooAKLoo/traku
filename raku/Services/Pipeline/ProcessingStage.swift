//
//  ProcessingStage.swift
//  raku
//
//  处理阶段协议定义
//

import Foundation

// MARK: - 处理阶段协议
protocol ProcessingStage {
    /// 阶段名称
    var name: String { get }

    /// 处理上下文
    func process(_ context: ProcessingContext) async throws -> ProcessingContext

    /// 是否应该跳过此阶段
    func shouldSkip(_ context: ProcessingContext) -> Bool
}

// MARK: - 默认实现
extension ProcessingStage {
    func shouldSkip(_ context: ProcessingContext) -> Bool {
        return false
    }
}

// MARK: - 处理阶段错误
enum ProcessingStageError: Error, LocalizedError {
    case asrFailed(Error)
    case classificationFailed(Error)
    case enrichmentFailed(Error)
    case embeddingFailed(Error)
    case metadataFailed(Error)
    case emptyTranscription
    case cancelled

    var errorDescription: String? {
        switch self {
        case .asrFailed(let error):
            return "语音识别失败: \(error.localizedDescription)"
        case .classificationFailed(let error):
            return "分类失败: \(error.localizedDescription)"
        case .enrichmentFailed(let error):
            return "内容富化失败: \(error.localizedDescription)"
        case .embeddingFailed(let error):
            return "向量生成失败: \(error.localizedDescription)"
        case .metadataFailed(let error):
            return "元数据获取失败: \(error.localizedDescription)"
        case .emptyTranscription:
            return "语音识别结果为空"
        case .cancelled:
            return "处理已取消"
        }
    }
}

// MARK: - 处理阶段枚举（用于进度报告）
enum PipelineStage: String, CaseIterable {
    case idle = "空闲"
    case saving = "保存中"
    case speechRecognition = "语音识别中"
    case classification = "分类中"
    case enrichment = "生成中"
    case embedding = "向量化中"
    case metadata = "获取信息中"
    case completed = "完成"
    case failed = "失败"

    var progress: Float {
        switch self {
        case .idle: return 0.0
        case .saving: return 0.1
        case .speechRecognition: return 0.3
        case .classification: return 0.5
        case .enrichment: return 0.7
        case .embedding: return 0.85
        case .metadata: return 0.95
        case .completed: return 1.0
        case .failed: return 0.0
        }
    }

    func toUIStage() -> UIProcessingStage {
        switch self {
        case .idle: return .idle
        case .saving: return .recording
        case .speechRecognition: return .speechRecognition
        case .classification: return .llmAnalysisFirstStep
        case .enrichment: return .llmAnalysisSecondStep
        case .embedding, .metadata: return .llmAnalysisSecondStep
        case .completed: return .completed
        case .failed: return .failed
        }
    }
}
