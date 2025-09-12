import Foundation

/// 文本搜索器 - 负责基于关键词的全文搜索
final class TextSearcher {
    
    /// 执行文本搜索
    /// - Parameters:
    ///   - query: 搜索查询
    ///   - searchFields: 要搜索的字段
    ///   - limit: 返回结果数量限制
    ///   - completion: 完成回调
    func search(
        query: String,
        searchFields: Set<SearchField>,
        limit: Int,
        completion: @escaping (Result<[SearchResult], Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let recordings = DatabaseManager.shared.loadRecordings()
                let results = self.performTextSearch(
                    query: query,
                    recordings: recordings,
                    searchFields: searchFields,
                    limit: limit
                )
                
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// 执行实际的文本搜索
    private func performTextSearch(
        query: String,
        recordings: [AudioRecording],
        searchFields: Set<SearchField>,
        limit: Int
    ) -> [SearchResult] {
        let keywords = extractKeywords(from: query)
        var results: [(recording: AudioRecording, score: Float, snippets: [MatchedSnippet])] = []
        
        for recording in recordings {
            var totalScore: Float = 0
            var matchedSnippets: [MatchedSnippet] = []
            
            // 在不同字段中搜索
            for field in searchFields {
                let (score, snippets) = searchInField(
                    keywords: keywords,
                    recording: recording,
                    field: field
                )
                totalScore += score
                matchedSnippets.append(contentsOf: snippets)
            }
            
            if totalScore > 0 {
                results.append((
                    recording: recording,
                    score: totalScore,
                    snippets: matchedSnippets
                ))
            }
        }
        
        // 按分数降序排序
        results.sort { $0.score > $1.score }
        
        // 转换为SearchResult格式
        return results.prefix(limit).map { result in
            SearchResult(
                recordingId: result.recording.id.uuidString,
                score: result.score,
                matchType: .text,
                matchedSnippets: result.snippets,
                recording: result.recording
            )
        }
    }
    
    /// 从查询中提取关键词
    private func extractKeywords(from query: String) -> [String] {
        // 分割字符串并过滤空白和停用词
        return query
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { word in
                let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
                return trimmed.count > 1 ? trimmed.lowercased() : nil
            }
            .filter { !isStopWord($0) }
    }
    
    /// 判断是否为停用词
    private func isStopWord(_ word: String) -> Bool {
        let stopWords = Set([
            "的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都", "一", "一个",
            "上", "也", "很", "到", "说", "要", "去", "你", "会", "着", "没有", "看", "好",
            "自己", "这", "那", "其", "里", "面", "等", "但", "或", "与"
        ])
        return stopWords.contains(word)
    }
    
    /// 在指定字段中搜索关键词
    private func searchInField(
        keywords: [String],
        recording: AudioRecording,
        field: SearchField
    ) -> (score: Float, snippets: [MatchedSnippet]) {
        let content = getFieldContent(recording: recording, field: field)
        guard !content.isEmpty else {
            return (0, [])
        }
        
        let normalizedContent = content.lowercased()
        var fieldScore: Float = 0
        var highlightRanges: [NSRange] = []
        
        for keyword in keywords {
            let matches = findMatches(for: keyword, in: normalizedContent)
            
            if !matches.isEmpty {
                // 计算字段权重
                let fieldWeight = getFieldWeight(field: field)
                
                // 计算关键词分数 (基于匹配数量和字段权重)
                let keywordScore = Float(matches.count) * fieldWeight
                fieldScore += keywordScore
                
                // 记录高亮范围
                highlightRanges.append(contentsOf: matches)
            }
        }
        
        var snippets: [MatchedSnippet] = []
        if fieldScore > 0 {
            let snippet = extractSnippet(
                content: content,
                highlightRanges: highlightRanges
            )
            
            snippets.append(MatchedSnippet(
                field: field,
                snippet: snippet,
                highlightRanges: highlightRanges
            ))
        }
        
        return (fieldScore, snippets)
    }
    
    /// 获取字段内容
    private func getFieldContent(recording: AudioRecording, field: SearchField) -> String {
        switch field {
        case .title:
            return recording.title
        case .tags:
            return recording.tags.joined(separator: " ")
        case .transcription:
            return recording.transcription
        case .summary:
            return recording.summary
        case .polishedText:
            return recording.polishedText
        }
    }
    
    /// 获取字段权重
    private func getFieldWeight(field: SearchField) -> Float {
        switch field {
        case .title:
            return 3.0
        case .tags:
            return 2.5
        case .summary:
            return 2.0
        case .transcription:
            return 1.5
        case .polishedText:
            return 1.0
        }
    }
    
    /// 查找关键词在文本中的所有匹配位置
    private func findMatches(for keyword: String, in content: String) -> [NSRange] {
        var matches: [NSRange] = []
        let nsContent = content as NSString
        var searchRange = NSRange(location: 0, length: nsContent.length)
        
        while searchRange.location < nsContent.length {
            let foundRange = nsContent.range(
                of: keyword,
                options: [.caseInsensitive, .literal],
                range: searchRange
            )
            
            if foundRange.location == NSNotFound {
                break
            }
            
            matches.append(foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = nsContent.length - searchRange.location
        }
        
        return matches
    }
    
    /// 提取包含匹配内容的文本片段
    private func extractSnippet(content: String, highlightRanges: [NSRange]) -> String {
        guard !highlightRanges.isEmpty else {
            return String(content.prefix(100))
        }
        
        let nsContent = content as NSString
        let firstMatch = highlightRanges.first!
        
        // 计算片段范围
        let snippetLength = 150
        let contextLength = (snippetLength - firstMatch.length) / 2
        
        let startIndex = max(0, firstMatch.location - contextLength)
        let endIndex = min(nsContent.length, firstMatch.location + firstMatch.length + contextLength)
        
        let snippetRange = NSRange(location: startIndex, length: endIndex - startIndex)
        let snippet = nsContent.substring(with: snippetRange)
        
        // 添加省略号
        let prefix = startIndex > 0 ? "..." : ""
        let suffix = endIndex < nsContent.length ? "..." : ""
        
        return prefix + snippet + suffix
    }
}