import Foundation

/// 火山引擎文本向量化服务
final class VolcEngineEmbeddingService {
    
    // MARK: - Properties
    
    static let shared = VolcEngineEmbeddingService()
    
    private let apiKey: String
    private let apiEndpoint = "https://ark.cn-beijing.volces.com/api/v3/embeddings"
    private let model = "doubao-embedding-text-240715"
    private let maxTokensPerElement = 4096
    private let maxBatchSize = 4
    
    private let networkService: NetworkService
    private let processingQueue = DispatchQueue(label: "com.raku.embeddingService", qos: .background)
    
    // MARK: - Models
    
    struct EmbeddingRequest: Encodable {
        let model: String
        let input: [String]
        let encoding_format: String = "float"
    }
    
    struct EmbeddingResponse: Decodable {
        let id: String
        let model: String
        let created: Int
        let object: String
        let data: [EmbeddingData]
        let usage: Usage
        
        struct EmbeddingData: Decodable {
            let index: Int
            let embedding: [Float]
            let object: String
        }
        
        struct Usage: Decodable {
            let prompt_tokens: Int
            let total_tokens: Int
        }
    }
    
    struct EmbeddingResult {
        let recordingId: String
        let titleEmbedding: [Float]?
        let tagsEmbeddings: [[Float]]
        let polishedTextEmbedding: [Float]?
    }
    
    // MARK: - Initialization
    
    private init() {
        // 直接使用硬编码的API Key
        self.apiKey = "7dda38f8-2383-434c-9d8d-a26263d4b5d1"
        
        let networkConfig = NetworkConfiguration(
            timeout: 30.0,
            defaultHeaders: [
                "Authorization": "Bearer \(apiKey)"
            ]
        )
        self.networkService = NetworkService(configuration: networkConfig)
    }
    
    // MARK: - Public Methods
    
    /// 生成录音内容的向量化表示
    /// - Parameters:
    ///   - recordingId: 录音记录ID
    ///   - title: 标题文本
    ///   - tags: 标签数组
    ///   - polishedText: 润色后的文本
    ///   - completion: 完成回调
    func generateEmbeddings(
        for recordingId: String,
        title: String?,
        tags: [String],
        polishedText: String?,
        completion: @escaping (Result<EmbeddingResult, Error>) -> Void
    ) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 生成统一的语义文本，与Python版本保持一致
            let semanticText = self.generateSemanticText(
                title: title,
                tags: tags,
                polishedText: polishedText,
                recordingId: recordingId
            )
            
            guard !semanticText.isEmpty else {
                completion(.success(EmbeddingResult(
                    recordingId: recordingId,
                    titleEmbedding: nil,
                    tagsEmbeddings: [],
                    polishedTextEmbedding: nil
                )))
                return
            }
            
            // 为统一语义文本生成向量
            self.callEmbeddingAPI(inputs: [semanticText]) { result in
                switch result {
                case .success(let response):
                    guard let embedding = response.data.first?.embedding else {
                        completion(.failure(EmbeddingError.invalidResponse))
                        return
                    }
                    
                    // 将统一向量作为标题向量返回（保持向后兼容）
                    let result = EmbeddingResult(
                        recordingId: recordingId,
                        titleEmbedding: embedding,
                        tagsEmbeddings: [],
                        polishedTextEmbedding: nil
                    )
                    
                    completion(.success(result))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 批量处理未完成向量化的录音记录
    func processUnembeddedRecordings() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 查询未处理的记录
            let unprocessedIds = DatabaseManager.shared.getRecordingsWithoutEmbeddings()
            
            print("[EmbeddingService] Found \(unprocessedIds.count) recordings without embeddings")
            
            for recordingId in unprocessedIds {
                // 获取录音记录
                guard let recording = DatabaseManager.shared.getRecording(by: recordingId) else {
                    continue
                }
                
                // 生成向量
                self.generateEmbeddings(
                    for: recordingId,
                    title: recording.title,
                    tags: recording.tags,
                    polishedText: recording.polishedText
                ) { result in
                    switch result {
                    case .success(let embeddingResult):
                        // 保存到数据库
                        DatabaseManager.shared.saveEmbeddings(embeddingResult)
                        print("[EmbeddingService] Successfully generated embeddings for recording \(recordingId)")
                        
                    case .failure(let error):
                        print("[EmbeddingService] Failed to generate embeddings for recording \(recordingId): \(error)")
                    }
                }
                
                // 避免过于频繁的请求
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 生成统一的语义文本，与Python版本保持一致
    private func generateSemanticText(
        title: String?,
        tags: [String],
        polishedText: String?,
        recordingId: String
    ) -> String {
        var components: [String] = []
        
        // 标题
        if let title = title, !title.isEmpty {
            components.append("标题：\(title)")
        }
        
        // 标签
        if !tags.isEmpty {
            let tagsString = tags.joined(separator: ", ")
            components.append("标签：\(tagsString)")
        }
        
        // 润色文本（如果有的话）
        if let polishedText = polishedText, !polishedText.isEmpty {
            // 限制文本长度，避免超出token限制
            let truncatedText = String(polishedText.prefix(8000))
            components.append("内容：\(truncatedText)")
        }
        
        return components.joined(separator: " | ")
    }
    
    private func processInBatches(
        inputs: [String],
        completion: @escaping (Result<[[Float]], Error>) -> Void
    ) {
        var allEmbeddings: [[Float]] = Array(repeating: [], count: inputs.count)
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // 按批次处理
        for batchStart in stride(from: 0, to: inputs.count, by: maxBatchSize) {
            let batchEnd = min(batchStart + maxBatchSize, inputs.count)
            let batch = Array(inputs[batchStart..<batchEnd])
            
            group.enter()
            
            callEmbeddingAPI(inputs: batch) { result in
                switch result {
                case .success(let response):
                    // 将结果放入正确的位置
                    for embeddingData in response.data {
                        let globalIndex = batchStart + embeddingData.index
                        allEmbeddings[globalIndex] = embeddingData.embedding
                    }
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: processingQueue) {
            if !errors.isEmpty {
                completion(.failure(errors.first!))
            } else {
                completion(.success(allEmbeddings))
            }
        }
    }
    
    private func callEmbeddingAPI(
        inputs: [String],
        completion: @escaping (Result<EmbeddingResponse, Error>) -> Void
    ) {
        let requestBody = EmbeddingRequest(
            model: model,
            input: inputs
        )
        
        guard let jsonData = try? JSONEncoder().encode(requestBody) else {
            completion(.failure(EmbeddingError.invalidRequest))
            return
        }
        
        let parameters: [String: Any]
        do {
            parameters = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
        } catch {
            completion(.failure(error))
            return
        }
        
        networkService.performJSONRequest(
            url: apiEndpoint,
            method: .POST,
            parameters: parameters
        ) { result in
            switch result {
            case .success(let data):
                do {
                    let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
                    completion(.success(embeddingResponse))
                } catch {
                    completion(.failure(EmbeddingError.invalidResponse))
                }
            case .failure(let networkError):
                completion(.failure(self.convertNetworkError(networkError)))
            }
        }
    }
    
    // MARK: - Error Types
    
    enum EmbeddingError: LocalizedError {
        case invalidURL
        case noData
        case invalidResponse
        case invalidRequest
        case networkError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .noData:
                return "No data received from API"
            case .invalidResponse:
                return "Invalid response format"
            case .invalidRequest:
                return "Invalid request format"
            case .networkError:
                return "Network error occurred"
            }
        }
    }
    
    // MARK: - Error Conversion
    
    private func convertNetworkError(_ networkError: NetworkError) -> EmbeddingError {
        switch networkError {
        case .invalidURL:
            return .invalidURL
        case .requestError, .networkError, .httpError, .timeout:
            return .networkError
        case .emptyResponse:
            return .noData
        }
    }
}