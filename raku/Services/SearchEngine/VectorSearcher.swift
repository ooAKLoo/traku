import Foundation

/// 向量搜索器 - 负责基于向量相似度的搜索
/// 职责单一：只负责向量相似度计算，不做关键词匹配（由TextSearcher负责）
final class VectorSearcher {

    private let embeddingService = VolcEngineEmbeddingService.shared
    private let cosineSimilarityCalculator = CosineSimilarityCalculator()

    /// 执行向量搜索
    /// - Parameters:
    ///   - query: 搜索查询
    ///   - limit: 返回结果数量限制
    ///   - completion: 完成回调
    func search(
        query: String,
        limit: Int,
        completion: @escaping (Result<[SearchResult], Error>) -> Void
    ) {
        // 生成查询向量
        embeddingService.generateSearchEmbedding(for: query) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let queryEmbedding):
                guard !queryEmbedding.isEmpty else {
                    completion(.success([]))
                    return
                }

                // 从数据库获取所有录音
                let recordings = DatabaseManager.shared.loadRecordings()

                // 计算相似度并排序
                self.calculateSimilarities(
                    queryEmbedding: queryEmbedding,
                    recordings: recordings,
                    limit: limit,
                    completion: completion
                )

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 计算查询向量与所有录音向量的相似度
    private func calculateSimilarities(
        queryEmbedding: [Float],
        recordings: [AudioRecording],
        limit: Int,
        completion: @escaping (Result<[SearchResult], Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [SearchResult] = []

            for recording in recordings {
                guard let embedding = DatabaseManager.shared.getEmbeddingVector(id: recording.id) else {
                    continue
                }

                let vectorScore = self.cosineSimilarityCalculator.calculate(
                    vector1: queryEmbedding,
                    vector2: embedding
                )

                // 只返回有意义的相似度结果（余弦相似度 > 0）
                if vectorScore > 0 {
                    let searchResult = SearchResult(
                        recordingId: recording.id.uuidString,
                        score: vectorScore,
                        matchType: .vector,
                        matchedSnippets: [],
                        recording: recording
                    )
                    results.append(searchResult)
                }
            }

            // 按分数降序排序
            results.sort { $0.score > $1.score }

            // 返回限制数量的结果
            let limitedResults = Array(results.prefix(limit))
            completion(.success(limitedResults))
        }
    }
}

/// 余弦相似度计算器
final class CosineSimilarityCalculator {

    /// 计算两个向量的余弦相似度
    /// - Parameters:
    ///   - vector1: 第一个向量
    ///   - vector2: 第二个向量
    /// - Returns: 余弦相似度分数 [-1, 1]，1表示完全相同，-1表示完全相反，0表示正交
    func calculate(vector1: [Float], vector2: [Float]) -> Float {
        guard vector1.count == vector2.count else {
            return 0
        }

        var dotProduct: Float = 0
        var magnitude1: Float = 0
        var magnitude2: Float = 0

        for i in 0..<vector1.count {
            dotProduct += vector1[i] * vector2[i]
            magnitude1 += vector1[i] * vector1[i]
            magnitude2 += vector2[i] * vector2[i]
        }

        let magnitude = sqrt(magnitude1) * sqrt(magnitude2)

        guard magnitude > 0 else {
            return 0
        }

        return dotProduct / magnitude
    }
}
