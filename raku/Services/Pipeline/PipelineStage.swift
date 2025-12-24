//
//  PipelineStage.swift
//  raku
//
//  处理阶段协议定义
//

import Foundation

// MARK: - 处理阶段协议
protocol PipelineStage {
    var name: String { get }
    func process(_ context: ProcessingContext) async throws -> ProcessingContext
    func shouldSkip(_ context: ProcessingContext) -> Bool
}

extension PipelineStage {
    func shouldSkip(_ context: ProcessingContext) -> Bool {
        return false
    }
}

// MARK: - 处理阶段错误
enum ProcessingStageError: Error, LocalizedError {
    case asrFailed(Error)
    case classificationFailed(Error)
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
