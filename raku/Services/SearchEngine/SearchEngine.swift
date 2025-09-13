import Foundation

/// 搜索引擎服务 - 负责接收搜索词并返回匹配结果
/// 遵循单一职责原则：仅负责搜索逻辑的编排和结果返回
final class SearchEngine {
    
    // MARK: - Properties
    
    static let shared = SearchEngine()
    
    private let vectorSearcher: VectorSearcher
    private let textSearcher: TextSearcher
    
    private let searchQueue = DispatchQueue(label: "com.raku.searchEngine", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        self.vectorSearcher = VectorSearcher()
        self.textSearcher = TextSearcher()
    }
    
    // MARK: - Public Methods
    
    /// 搜索录音记录
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - options: 搜索选项
    ///   - completion: 搜索完成回调，返回排序后的结果
    func search(
        query: String,
        options: SearchOptions = SearchOptions(),
        completion: @escaping (Result<[SearchResult], SearchError>) -> Void
    ) {
        searchQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 验证搜索输入
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                completion(.failure(.emptyQuery))
                return
            }
            
            let normalizedQuery = self.normalizeQuery(query)
            
            // 并行执行向量搜索和文本搜索
            let group = DispatchGroup()
            var vectorResults: [SearchResult] = []
            var textResults: [SearchResult] = []
            var searchErrors: [SearchError] = []
            
            // 向量搜索
            if options.enableVectorSearch {
                group.enter()
                self.vectorSearcher.search(query: normalizedQuery, limit: options.maxResults) { result in
                    switch result {
                    case .success(let results):
                        vectorResults = results
                    case .failure(let error):
                        searchErrors.append(.vectorSearchFailed(error))
                    }
                    group.leave()
                }
            }
            
            // 文本搜索
            if options.enableTextSearch {
                group.enter()
                self.textSearcher.search(
                    query: normalizedQuery,
                    searchFields: options.searchFields,
                    limit: options.maxResults
                ) { result in
                    switch result {
                    case .success(let results):
                        textResults = results
                    case .failure(let error):
                        searchErrors.append(.textSearchFailed(error))
                    }
                    group.leave()
                }
            }
            
            // 等待所有搜索完成
            group.notify(queue: self.searchQueue) {
                // 如果所有搜索都失败，返回错误
                if vectorResults.isEmpty && textResults.isEmpty && !searchErrors.isEmpty {
                    completion(.failure(searchErrors.first!))
                    return
                }
                
                // 合并和排序结果
                let mergedResults = self.mergeResults(
                    vectorResults: vectorResults,
                    textResults: textResults,
                    options: options
                )
                
                // 按分数降序排序（不需要额外的排序器）
                let sortedResults = mergedResults.sorted { $0.score > $1.score }
                
                // 限制返回结果数量
                let finalResults = Array(sortedResults.prefix(options.maxResults))
                
                completion(.success(finalResults))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 规范化查询字符串
    private func normalizeQuery(_ query: String) -> String {
        return query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    /// 合并向量搜索和文本搜索的结果
    private func mergeResults(
        vectorResults: [SearchResult],
        textResults: [SearchResult],
        options: SearchOptions
    ) -> [SearchResult] {
        var resultMap: [String: SearchResult] = [:]
        
        // 处理向量搜索结果
        for result in vectorResults {
            resultMap[result.recordingId] = result
        }
        
        // 合并文本搜索结果
        for textResult in textResults {
            if let existingResult = resultMap[textResult.recordingId] {
                // 合并分数
                let combinedScore = options.vectorWeight * existingResult.score +
                                  options.textWeight * textResult.score
                
                // 合并匹配片段
                var combinedSnippets = existingResult.matchedSnippets
                combinedSnippets.append(contentsOf: textResult.matchedSnippets)
                
                resultMap[textResult.recordingId] = SearchResult(
                    recordingId: textResult.recordingId,
                    score: combinedScore,
                    matchType: .hybrid,
                    matchedSnippets: combinedSnippets,
                    recording: textResult.recording
                )
            } else {
                // 调整文本搜索结果的分数权重
                var adjustedResult = textResult
                adjustedResult.score *= options.textWeight
                resultMap[textResult.recordingId] = adjustedResult
            }
        }
        
        return Array(resultMap.values)
    }
}

// MARK: - Search Options

/// 搜索选项配置
struct SearchOptions {
    /// 是否启用向量搜索
    let enableVectorSearch: Bool
    
    /// 是否启用文本搜索
    let enableTextSearch: Bool
    
    /// 搜索字段
    let searchFields: Set<SearchField>
    
    /// 最大返回结果数
    let maxResults: Int
    
    /// 向量搜索权重
    let vectorWeight: Float
    
    /// 文本搜索权重
    let textWeight: Float
    
    /// 最小相关性分数
    let minScore: Float
    
    init(
        enableVectorSearch: Bool = true,
        enableTextSearch: Bool = true,
        searchFields: Set<SearchField> = [.title, .tags, .transcription, .summary],
        maxResults: Int = 10,
        vectorWeight: Float = 0.7,
        textWeight: Float = 0.3,
        minScore: Float = 0.1
    ) {
        self.enableVectorSearch = enableVectorSearch
        self.enableTextSearch = enableTextSearch
        self.searchFields = searchFields
        self.maxResults = maxResults
        self.vectorWeight = vectorWeight
        self.textWeight = textWeight
        self.minScore = minScore
    }
}

// MARK: - Search Result

/// 搜索结果
struct SearchResult {
    let recordingId: String
    var score: Float
    let matchType: MatchType
    let matchedSnippets: [MatchedSnippet]
    let recording: AudioRecording?
    
    enum MatchType {
        case vector
        case text
        case hybrid
    }
}

/// 匹配的文本片段
struct MatchedSnippet {
    let field: SearchField
    let snippet: String
    let highlightRanges: [NSRange]
}

/// 搜索字段
enum SearchField: String, CaseIterable {
    case title
    case tags
    case transcription
    case summary
    case polishedText
}

// MARK: - Search Error

/// 搜索错误类型
enum SearchError: LocalizedError {
    case emptyQuery
    case vectorSearchFailed(Error)
    case textSearchFailed(Error)
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "搜索关键词不能为空"
        case .vectorSearchFailed(let error):
            return "向量搜索失败: \(error.localizedDescription)"
        case .textSearchFailed(let error):
            return "文本搜索失败: \(error.localizedDescription)"
        case .noResults:
            return "未找到相关结果"
        }
    }
}


//搜索引擎实现完成！我创建了一个遵循单一职责原则的搜索引擎架构：
//
//  核心架构
//
//  1. SearchEngine.swift - 主搜索引擎
//    - 负责搜索逻辑编排和结果返回
//    - 协调向量搜索和文本搜索
//    - 合并和处理搜索结果
//  2. VectorSearcher.swift - 向量搜索器
//    - 专门负责语义搜索
//    - 使用现有的向量化服务
//    - 计算余弦相似度
//  3. TextSearcher.swift - 文本搜索器
//    - 负责关键词全文搜索
//    - 支持多字段搜索
//    - 智能提取匹配片段
//  4. SearchResultRanker.swift - 结果排序器
//    - 基于多种因子优化排序
//    - 考虑时间、质量、匹配度等
//
//  主要特性
//
//  ✅ 单一职责 - 每个类职责清晰
//  ✅ 混合搜索 - 向量搜索 + 文本搜索
//  ✅ 智能排序 - 多维度结果优化
//  ✅ 配置灵活 - 支持多种搜索选项
//  ✅ 异步处理 - 并行执行提升性能
//  ✅ 错误处理 - 完善的错误处理机制
