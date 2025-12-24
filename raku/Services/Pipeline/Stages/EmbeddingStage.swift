//
//  EmbeddingStage.swift
//  raku
//
//  向量生成阶段
//

import Foundation

final class EmbeddingStage: ProcessingStage {
    let name = "向量生成"
    private let embeddingService = VolcEngineEmbeddingService.shared

    func shouldSkip(_ context: ProcessingContext) -> Bool {
        // 跳过条件：没有可用文本
        let hasContent = !(context.polishedText?.isEmpty ?? true) || !(context.transcription?.isEmpty ?? true)
        if !hasContent {
            print("⏭️ [\(name)] 没有可用文本，跳过向量生成")
            return true
        }
        return false
    }

    func process(_ context: ProcessingContext) async throws -> ProcessingContext {
        print("🔷 [\(name)] 开始生成向量")

        // 根据类型决定embedding内容
        let embeddingContent = determineEmbeddingContent(context)

        guard !embeddingContent.isEmpty else {
            print("⚠️ [\(name)] 没有可用内容，跳过")
            return context
        }

        return try await withCheckedThrowingContinuation { continuation in
            embeddingService.generateEmbeddings(
                for: context.id.uuidString,
                polishedText: embeddingContent,
                transcription: nil
            ) { result in
                switch result {
                case .success(let embeddingResult):
                    var updatedContext = context
                    updatedContext.embedding = embeddingResult.embedding

                    // 保存到数据库
                    DatabaseManager.shared.saveEmbeddings(embeddingResult)
                    print("✅ [\(self.name)] 向量生成成功，维度: \(embeddingResult.embedding.count)")
                    continuation.resume(returning: updatedContext)

                case .failure(let error):
                    print("❌ [\(self.name)] 向量生成失败: \(error.localizedDescription)")
                    // 向量生成失败不阻塞流程，返回原context
                    continuation.resume(returning: context)
                }
            }
        }
    }

    private func determineEmbeddingContent(_ context: ProcessingContext) -> String {
        switch context.thoughtType {
        case .insight:
            // 灵感类：使用润色文本
            return context.polishedText ?? context.transcription ?? ""

        case .reflection:
            // 思考类：组合润色文本和富化内容
            if let polished = context.polishedText, let enriched = context.enrichedContent {
                return "\(polished)\n\n\(enriched)"
            }
            return context.polishedText ?? context.transcription ?? ""

        case .unknown:
            // 未分类：使用润色文本或转录
            return context.polishedText ?? context.transcription ?? ""
        }
    }
}
