import Foundation

/// 向量搜索器 - 负责基于向量相似度的搜索
final class VectorSearcher {
    
    private let embeddingService = VolcEngineEmbeddingService.shared
    private let cosineSimilarityCalculator = CosineSimilarityCalculator()
    private var lastQuery: String = ""
    
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
        // 保存查询用于后续关键词匹配
        lastQuery = query
        
        // 生成查询向量
        embeddingService.generateSearchEmbedding(for: query) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let queryEmbedding):
                guard !queryEmbedding.isEmpty else {
                    completion(.success([]))
                    return
                }
                let queryPreview = queryEmbedding.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", ")
                print("vectorprocess--- 🔢 查询向量前5值: [\(queryPreview)]")
                
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
        // 获取查询文本用于关键词匹配
        let query = self.lastQuery
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [SearchResult] = []
            
            print("VectorSearcher--- ========== 向量搜索打分详情 ==========")
            print("VectorSearcher--- 🔍 查询内容: \(query)")
            print("VectorSearcher--- 🔢 查询向量维度: \(queryEmbedding.count)")
            print("VectorSearcher--- 🏷️ 查询关键词: \(query.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })")
            print("VectorSearcher--- 📊 共找到 \(recordings.count) 条录音记录进行匹配")
            
            // 准备查询关键词（小写，分词）
            let queryWords = Set(query.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
            
            for (index, recording) in recordings.enumerated() {
                let recordingId = recording.id.uuidString
                let embeddingVector = DatabaseManager.shared.getEmbeddingVector(id: recording.id)
                
                print("VectorSearcher--- 📝 === 录音记录 \(index + 1)/\(recordings.count) ===")
                print("VectorSearcher--- 🆔 ID: \(recordingId.prefix(8))...")
                print("VectorSearcher--- 📋 标题: \(recording.title)")
                print("VectorSearcher--- 🏷️ 标签: \(recording.tags.joined(separator: ", "))")
                print("VectorSearcher--- 🎵 时长: \(String(format: "%.1f", recording.duration))秒")
                
                // 计算统一向量的相似度
                var vectorScore: Float = 0.0
                
                if let embedding = embeddingVector {
                    vectorScore = self.cosineSimilarityCalculator.calculate(
                        vector1: queryEmbedding,
                        vector2: embedding
                    )
                    let embeddingPreview = embedding.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", ")
                    print("VectorSearcher--- 🎯 向量相似度: \(String(format: "%.4f", vectorScore)) (向量维度: \(embedding.count))")
                    print("vectorprocess--- 📊 录音向量前5值: [\(embeddingPreview)]")
                } else {
                    print("VectorSearcher--- ❌ 无向量数据")
                }
                
                // 如果没有向量数据，跳过此记录
                if embeddingVector == nil {
                    print("VectorSearcher--- ⏭️ 跳过此记录（无向量数据）")
                    continue
                }
                
                // 计算关键词匹配得分
                let recordingText = (recording.title + " " + recording.tags.joined(separator: " ")).lowercased()
                let recordingWords = Set(recordingText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
                let commonWords = queryWords.intersection(recordingWords)
                let textMatchScore = queryWords.isEmpty ? 0 : Float(commonWords.count) / Float(queryWords.count)
                
                print("VectorSearcher--- 📊 关键词分析:")
                print("VectorSearcher---    查询词汇: \(Array(queryWords).sorted())")
                print("VectorSearcher---    录音词汇: \(Array(recordingWords).sorted())")
                print("VectorSearcher---    匹配词汇: \(Array(commonWords).sorted())")
                print("VectorSearcher---    匹配得分: \(commonWords.count)/\(queryWords.count) = \(String(format: "%.4f", textMatchScore))")
                
                // 综合得分：70%向量相似度 + 30%关键词匹配
                let vectorWeight: Float = 0.7
                let textWeight: Float = 0.3
                let combinedScore = vectorScore * vectorWeight + textMatchScore * textWeight
                
                print("VectorSearcher--- 🏆 综合得分计算:")
                print("VectorSearcher---    向量得分: \(String(format: "%.4f", vectorScore)) × \(vectorWeight) = \(String(format: "%.4f", vectorScore * vectorWeight))")
                print("VectorSearcher---    文本得分: \(String(format: "%.4f", textMatchScore)) × \(textWeight) = \(String(format: "%.4f", textMatchScore * textWeight))")
                print("VectorSearcher---    最终得分: \(String(format: "%.4f", combinedScore))")
                
                if combinedScore > 0 {
                    let searchResult = SearchResult(
                        recordingId: recording.id.uuidString,
                        score: combinedScore,
                        matchType: .vector,
                        matchedSnippets: [],
                        recording: recording
                    )
                    results.append(searchResult)
                    print("VectorSearcher--- ✅ 加入候选结果 (得分: \(String(format: "%.4f", combinedScore)))")
                } else {
                    print("VectorSearcher--- ❌ 得分过低，不加入结果")
                }
            }
            
            // 按分数降序排序
            results.sort { $0.score > $1.score }
            
            print("VectorSearcher--- ========== 排序后的前\(limit)个结果 ==========")
            for (index, result) in results.prefix(limit).enumerated() {
                print("VectorSearcher--- 🏆 第\(index + 1)名: \(result.recording?.title ?? "未知标题")")
                print("VectorSearcher---    最终得分: \(String(format: "%.4f", result.score))")
                print("VectorSearcher---    录音ID: \(result.recordingId.prefix(8))...")
            }
            print("VectorSearcher--- ===========================================")
            print("VectorSearcher--- 📊 总计找到 \(results.count) 条匹配结果，返回前 \(min(limit, results.count)) 条")
            
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
    /// - Returns: 相似度分数 (0-1)
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
        
        // 返回原始余弦相似度[-1, 1]，与Python保持一致
        return dotProduct / magnitude
    }
}