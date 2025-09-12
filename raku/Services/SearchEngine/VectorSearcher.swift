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
        embeddingService.generateEmbeddings(
            for: "query",
            title: query,  // 直接使用查询文本，与Python逻辑对齐
            tags: [],  // 不提取标签，与Python逻辑对齐
            polishedText: nil  // 不需要额外的文本
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let embeddingResult):
                guard let queryEmbedding = embeddingResult.titleEmbedding else {
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
        // 获取查询文本用于关键词匹配
        let query = self.lastQuery
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [(recording: AudioRecording, titleScore: Float, tagScore: Float, contentScore: Float, vectorScore: Float, textScore: Float, combinedScore: Float)] = []
            
            print("\n========== 向量搜索打分详情 ==========")
            print("查询: \(query)")
            print("查询向量维度: \(queryEmbedding.count)")
            
            // 准备查询关键词（小写，分词）
            let queryWords = Set(query.lowercased().components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
            
            for recording in recordings {
                let recordingId = recording.id.uuidString
                let embeddings = DatabaseManager.shared.getEmbeddings(for: recordingId)
                
                print("\n录音: \(recording.title)")
                print("标签: \(recording.tags.joined(separator: ", "))")
                
                // 分别计算三个向量的相似度
                var titleScore: Float = 0.0
                var tagScore: Float = 0.0
                var contentScore: Float = 0.0
                
                // 1. 标题向量得分
                if let titleEmbedding = embeddings["title"] {
                    titleScore = self.cosineSimilarityCalculator.calculate(
                        vector1: queryEmbedding,
                        vector2: titleEmbedding
                    )
                    print("  标题向量得分: \(String(format: "%.3f", titleScore))")
                } else {
                    print("  标题向量: 无")
                }
                
                // 2. 标签向量得分（取所有tag向量的最高分）
                var maxTagScore: Float = 0.0
                var tagCount = 0
                for (key, embedding) in embeddings {
                    if key.starts(with: "tag_") {
                        let score = self.cosineSimilarityCalculator.calculate(
                            vector1: queryEmbedding,
                            vector2: embedding
                        )
                        maxTagScore = max(maxTagScore, score)
                        tagCount += 1
                    }
                }
                tagScore = maxTagScore
                if tagCount > 0 {
                    print("  标签向量得分: \(String(format: "%.3f", tagScore)) (共\(tagCount)个标签向量)")
                } else {
                    print("  标签向量: 无")
                }
                
                // 3. 内容向量得分
                if let contentEmbedding = embeddings["polished_text"] {
                    contentScore = self.cosineSimilarityCalculator.calculate(
                        vector1: queryEmbedding,
                        vector2: contentEmbedding
                    )
                    print("  内容向量得分: \(String(format: "%.3f", contentScore))")
                } else {
                    print("  内容向量: 无")
                }
                
                // 计算综合向量得分（权重分配）
                let hasTitle = titleScore > 0
                let hasTag = tagScore > 0  
                let hasContent = contentScore > 0
                
                var vectorScore: Float = 0.0
                
                // 固定权重分配（4:3:3比例，总和为1.0）
                let titleWeight: Float = 0.4    // 标题权重40%
                let tagWeight: Float = 0.3      // 标签权重30%
                let contentWeight: Float = 0.3  // 内容权重30%
                
                var actualWeights: [Float] = []
                var actualScores: [Float] = []
                
                if hasTitle {
                    vectorScore += titleScore * titleWeight
                    actualWeights.append(titleWeight)
                    actualScores.append(titleScore)
                }
                if hasTag {
                    vectorScore += tagScore * tagWeight
                    actualWeights.append(tagWeight)
                    actualScores.append(tagScore)
                }
                if hasContent {
                    vectorScore += contentScore * contentWeight
                    actualWeights.append(contentWeight)
                    actualScores.append(contentScore)
                }
                
                if actualWeights.isEmpty {
                    print("  无任何向量，跳过")
                    continue
                }
                
                // 如果某些向量缺失，重新归一化权重
                let totalActualWeight = actualWeights.reduce(0, +)
                if totalActualWeight > 0 && totalActualWeight < 1.0 {
                    vectorScore = vectorScore / totalActualWeight
                    print("  权重归一化: \(String(format: "%.2f", totalActualWeight)) -> 1.0")
                }
                
                // 打印权重详情
                var weightInfo = "权重分配: "
                if hasTitle { weightInfo += "标题(\(String(format: "%.1f", titleWeight*100))%) " }
                if hasTag { weightInfo += "标签(\(String(format: "%.1f", tagWeight*100))%) " }
                if hasContent { weightInfo += "内容(\(String(format: "%.1f", contentWeight*100))%) " }
                print("  \(weightInfo)")
                
                print("  综合向量得分: \(String(format: "%.3f", vectorScore))")
                
                // 计算关键词匹配得分（类似Python的实现）
                let recordingText = (recording.title + " " + recording.tags.joined(separator: " ")).lowercased()
                let recordingWords = Set(recordingText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
                let commonWords = queryWords.intersection(recordingWords)
                let textMatchScore = queryWords.isEmpty ? 0 : Float(commonWords.count) / Float(queryWords.count)
                
                print("  关键词匹配: \(commonWords.count)/\(queryWords.count) = \(String(format: "%.3f", textMatchScore))")
                
                // 综合得分：70%向量相似度 + 30%关键词匹配（与Python保持一致）
                let combinedScore = vectorScore * 0.7 + textMatchScore * 0.3
                
                print("  最终综合得分: \(String(format: "%.3f", combinedScore)) (70%向量 + 30%关键词)")
                
                if combinedScore > 0 {
                    results.append((recording: recording, titleScore: titleScore, tagScore: tagScore, contentScore: contentScore, vectorScore: vectorScore, textScore: textMatchScore, combinedScore: combinedScore))
                }
            }
            
            // 按分数降序排序
            results.sort { $0.combinedScore > $1.combinedScore }
            
            print("\n========== 排序后的前\(limit)个结果 ==========")
            for (index, result) in results.prefix(limit).enumerated() {
                print("\(index + 1). \(result.recording.title)")
                print("   标题向量得分: \(String(format: "%.3f", result.titleScore))")
                print("   标签向量得分: \(String(format: "%.3f", result.tagScore))")
                print("   内容向量得分: \(String(format: "%.3f", result.contentScore))")
                print("   综合向量得分: \(String(format: "%.3f", result.vectorScore))")
                print("   关键词得分: \(String(format: "%.3f", result.textScore))")
                print("   最终综合得分: \(String(format: "%.3f", result.combinedScore)) (70%向量 + 30%关键词)")
                print("   ---")
            }
            print("=====================================\n")
            
            // 转换为SearchResult格式
            let searchResults = results.prefix(limit).map { result in
                SearchResult(
                    recordingId: result.recording.id.uuidString,
                    score: result.combinedScore,
                    matchType: .vector,
                    matchedSnippets: [],
                    recording: result.recording
                )
            }
            
            completion(.success(Array(searchResults)))
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