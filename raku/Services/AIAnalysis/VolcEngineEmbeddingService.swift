import Foundation

/// 火山引擎文本向量化服务
final class VolcEngineEmbeddingService {
    
    // MARK: - Properties
    
    static let shared = VolcEngineEmbeddingService()
    
    private let apiKey: String
    private let apiEndpoint = "https://ark.cn-beijing.volces.com/api/v3/embeddings/multimodal"
    private let model = "doubao-embedding-vision-250615"
    private let maxTokensPerElement = 4096
    private let maxBatchSize = 1  // 新API每次只处理一个输入
    
    private let networkService: NetworkService
    private let processingQueue = DispatchQueue(label: "com.raku.embeddingService", qos: .background)
    
    // MARK: - Models
    
    struct EmbeddingRequest: Encodable {
        let model: String
        let input: [InputItem]
        let encoding_format: String = "float"
        let dimensions: Int = 1024  // 指定向量维度，与Python保持一致
    }
    
    struct InputItem: Encodable {
        let type: String
        let text: String?
        let image_url: ImageURL?
        
        init(text: String) {
            self.type = "text"
            self.text = text
            self.image_url = nil
        }
        
        init(imageURL: String) {
            self.type = "image_url"
            self.text = nil
            self.image_url = ImageURL(url: imageURL)
        }
    }
    
    struct ImageURL: Encodable {
        let url: String
    }
    
    struct EmbeddingResponse: Decodable {
        let id: String
        let model: String
        let created: Int
        let object: String
        let data: EmbeddingData  // 新API返回单个data对象，不是数组
        let usage: Usage
        
        struct EmbeddingData: Decodable {
            let embedding: [Float]  // 直接包含embedding数组
        }
        
        struct Usage: Decodable {
            let prompt_tokens: Int
            let total_tokens: Int
        }
    }
    
    struct EmbeddingResult {
        let recordingId: String
        let embedding: [Float]  // 简化为单个向量
    }
    
    // MARK: - Initialization
    
    private init() {
        // 直接使用硬编码的API Key
        self.apiKey = "7dda38f8-2383-434c-9d8d-a26263d4b5d1"
        
        let networkConfig = NetworkConfiguration(
            defaultHeaders: [
                "Authorization": "Bearer \(apiKey)"
            ]
            // 使用默认的200秒超时、后台支持、3次重试
        )
        self.networkService = NetworkService(configuration: networkConfig)
    }
    
    // MARK: - Public Methods
    
    /// 生成录音内容的向量化表示
    /// - Parameters:
    ///   - recordingId: 录音记录ID
    ///   - polishedText: 润色后的文本
    ///   - transcription: 原始转录文本（作为备选）
    ///   - completion: 完成回调
    func generateEmbeddings(
        for recordingId: String,
        polishedText: String?,
        transcription: String? = nil,
        completion: @escaping (Result<EmbeddingResult, Error>) -> Void
    ) {
        print("🔷 [service--embedding--START] 录音ID: \(recordingId), 润色文本长度: \(polishedText?.count ?? 0)")
        print("🔷 [service--embedding--START] 时间戳: \(Date())")
        
        // 生成统一的语义文本
        let semanticText = generateSemanticText(
            polishedText: polishedText,
            transcription: transcription
        )
        
        print("[EmbeddingService] 生成录音向量化:")
        print("  录音ID: \(recordingId)")
        print("  润色文本长度: \(polishedText?.count ?? 0)")
        print("  转录文本长度: \(transcription?.count ?? 0)")
        print("  最终内容文本长度: \(semanticText.count)")
        
        guard !semanticText.isEmpty else {
            print("🔷 [service--embedding--SKIP] 语义文本为空，跳过向量生成，录音ID: \(recordingId)")
            print("  ⚠️ 语义文本为空，跳过向量生成")
            completion(.success(EmbeddingResult(recordingId: recordingId, embedding: [])))
            return
        }
        
        // 直接调用多模态API
        generateMultimodalEmbeddings(
            for: recordingId,
            textInput: semanticText,
            completion: completion
        )
    }
    
    /// 为搜索查询生成向量化表示
    /// - Parameters:
    ///   - query: 搜索查询文本
    ///   - completion: 完成回调
    func generateSearchEmbedding(
        for query: String,
        completion: @escaping (Result<[Float], Error>) -> Void
    ) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[EmbeddingService] 搜索查询为空")
            completion(.success([]))
            return
        }
        
        print("[EmbeddingService] 生成搜索向量化:")
        print("  查询内容: \(query)")
        print("  查询长度: \(query.count)")
        
        // 直接使用查询文本生成向量
        generateMultimodalEmbeddings(
            for: "search_query",
            textInput: query,
            completion: { result in
                switch result {
                case .success(let embeddingResult):
                    completion(.success(embeddingResult.embedding))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        )
    }
    
    /// 支持多模态输入的向量化方法
    /// - Parameters:
    ///   - recordingId: 录音记录ID
    ///   - textInput: 文本输入
    ///   - imageURL: 可选的图像URL（用于多模态嵌入）
    ///   - completion: 完成回调
    func generateMultimodalEmbeddings(
        for recordingId: String,
        textInput: String,
        imageURL: String? = nil,
        completion: @escaping (Result<EmbeddingResult, Error>) -> Void
    ) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            var inputItems: [InputItem] = []
            
            // 添加文本输入
            if !textInput.isEmpty {
                inputItems.append(InputItem(text: textInput))
            }
            
            // 添加图像输入（如果有的话）
            if let imageURL = imageURL, !imageURL.isEmpty {
                inputItems.append(InputItem(imageURL: imageURL))
            }
            
            guard !inputItems.isEmpty else {
                completion(.success(EmbeddingResult(recordingId: recordingId, embedding: [])))
                return
            }
            
            // 调用多模态API
            self.callMultimodalEmbeddingAPI(inputs: inputItems) { result in
                switch result {
                case .success(let response):
                    let result = EmbeddingResult(
                        recordingId: recordingId,
                        embedding: response.data.embedding
                    )
                    print("🔷 [service--embedding--SUCCESS] 向量生成成功，录音ID: \(recordingId), 向量维度: \(response.data.embedding.count)")
                    completion(.success(result))
                    
                case .failure(let error):
                    print("🔷 [service--embedding--FAIL] 向量生成失败，录音ID: \(recordingId), 错误: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// 批量处理未完成向量化的录音记录
    func processUnembeddedRecordings() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let databaseManager = (DatabaseManager.shared as DatabaseManager)
            
            // 查询未处理的记录
            let unprocessedIds = databaseManager.getRecordingsWithoutEmbeddings()
            
            print("[EmbeddingService] Found \(unprocessedIds.count) recordings without embeddings")
            
            for recordingId in unprocessedIds {
                // 获取录音记录
                guard let recording = databaseManager.getRecording(by: recordingId) else {
                    continue
                }
                
                // 生成向量
                self.generateEmbeddings(
                    for: recordingId,
                    polishedText: recording.polishedText,
                    transcription: recording.transcription
                ) { result in
                    switch result {
                    case .success(let embeddingResult):
                        // 保存到数据库
                        databaseManager.saveEmbeddings(embeddingResult)
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
    
    /// 生成统一的语义文本
    private func generateSemanticText(
        polishedText: String?,
        transcription: String?
    ) -> String {
        // 内容：优先使用润色文本，如果没有则使用原始转录
        var contentText: String? = nil
        if let polishedText = polishedText, !polishedText.isEmpty {
            contentText = polishedText
            print("  ✅ 使用润色文本生成embedding")
        } else if let transcription = transcription, !transcription.isEmpty {
            contentText = transcription
            print("  ⚠️ 润色文本为空，使用原始转录文本")
        } else {
            print("  ❌ 警告：没有可用的内容文本（润色文本和转录文本都为空）")
            return ""
        }
        
        // 限制文本长度，避免超出token限制
        let truncatedText = String(contentText!.prefix(8000))
        
        // 如果结果太短，可能导致向量相似
        if truncatedText.count < 20 {
            print("  ⚠️ 警告：内容文本太短: \(truncatedText)")
        }
        
        return truncatedText
    }
    
    // 移除复杂的批处理逻辑，新API每次只处理一个输入
    
    private func callEmbeddingAPI(
        textInputs: [String],
        completion: @escaping (Result<EmbeddingResponse, Error>) -> Void
    ) {
        guard let firstText = textInputs.first else {
            completion(.failure(EmbeddingError.invalidRequest))
            return
        }
        
        // 新API每次只处理一个输入
        let inputItems = [InputItem(text: firstText)]
        
        let requestBody = EmbeddingRequest(
            model: model,
            input: inputItems
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
    
    /// 调用多模态嵌入API
    private func callMultimodalEmbeddingAPI(
        inputs: [InputItem],
        completion: @escaping (Result<EmbeddingResponse, Error>) -> Void
    ) {
        print("🔷 [service--embedding--API-CALL] 开始调用API")
        
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
                    print("🔷 [service--embedding--API-RESPONSE] 收到响应, 向量维度: \(embeddingResponse.data.embedding.count)")
                    completion(.success(embeddingResponse))
                } catch {
                    print("🔷 [service--embedding--API-ERROR] 响应解析失败: \(error)")
                    completion(.failure(EmbeddingError.invalidResponse))
                }
            case .failure(let networkError):
                print("🔷 [service--embedding--API-ERROR] 网络请求失败: \(networkError)")
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