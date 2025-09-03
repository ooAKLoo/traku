//
//  TwoStepLLMConfiguration.swift
//  raku
//
//  Created by 杨东举 on 2025/9/2.
//


//
//  TwoStepLLMService.swift
//  raku
//
//  两步式LLM处理服务
//  第一步：使用doubao-lite进行分类和标题生成
//  第二步：使用doubao-flash生成类别对应的辅助内容
//

import Foundation
import Combine

// MARK: - 两步式LLM配置
struct TwoStepLLMConfiguration {
    let apiURL: String
    let apiKey: String
    let liteModel: String  // 用于分类和标题生成
    let flashModel: String // 用于生成辅助内容
    let timeout: TimeInterval
    
    static let `default` = TwoStepLLMConfiguration(
        apiURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        apiKey: "7dda38f8-2383-434c-9d8d-a26263d4b5d1",
        liteModel: "doubao-1-5-lite-32k-250115",
        flashModel: "doubao-seed-1-6-flash-250715",
        timeout: 30.0
    )
}

// MARK: - 闪念类型枚举
enum FlashThoughtType: String, CaseIterable {
    case inspiration = "灵感"
    case idea = "想法"
    case reflection = "思考"
    case unknown = "未分类"
    
    var promptKey: String {
        switch self {
        case .inspiration:
            return "inspiration"
        case .idea:
            return "idea"
        case .reflection:
            return "reflection"
        case .unknown:
            return "general"
        }
    }
}

// MARK: - 第一步分析结果
struct FirstStepAnalysis {
    let title: String
    let oneSentenceSummary: String?  // 仅当文本超过150字时才有
    let thoughtType: FlashThoughtType
    let tags: [String]
    let originalText: String
    let timestamp: Date
}

// MARK: - 最终分析结果
struct TwoStepAnalysisResult {
    let title: String
    let summary: String  // 一句话总结（如果有）或原文
    let thoughtType: FlashThoughtType
    let tags: [String]
    let keyPoints: [String]  // 辅助内容
    let sentiment: String?
    let originalText: String
    let timestamp: Date
}

// MARK: - 服务代理协议
protocol TwoStepLLMServiceDelegate: AnyObject {
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFirstStep result: FirstStepAnalysis)
    func twoStepLLMService(_ service: TwoStepLLMService, didCompleteFinalAnalysis result: TwoStepAnalysisResult)
    func twoStepLLMService(_ service: TwoStepLLMService, didFailWithError error: Error)
}

// MARK: - 两步式LLM服务
class TwoStepLLMService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var currentStep = 0  // 0: idle, 1: first step, 2: second step
    @Published var lastResult: TwoStepAnalysisResult?
    
    // MARK: - Private Properties
    private let configuration: TwoStepLLMConfiguration
    private var urlSession: URLSession
    private let queue = DispatchQueue(label: "com.raku.twostep.llm", qos: .userInitiated)
    private var currentTask: URLSessionDataTask?
    
    // MARK: - Delegate
    weak var delegate: TwoStepLLMServiceDelegate?
    
    // MARK: - Initialization
    init(configuration: TwoStepLLMConfiguration = .default) {
        self.configuration = configuration
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        sessionConfig.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(configuration.apiKey)"
        ]
        self.urlSession = URLSession(configuration: sessionConfig)
        
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 分析文本（两步处理）
    func analyzeText(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("分析文本为空")
            return
        }
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.currentStep = 1
        }
        
        queue.async { [weak self] in
            self?.performFirstStepAnalysis(text)
        }
    }
    
    /// 停止分析
    func stopAnalysis() {
        currentTask?.cancel()
        currentTask = nil
        
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.currentStep = 0
        }
    }
    
    // MARK: - Step 1: 分类和标题生成
    
    private func performFirstStepAnalysis(_ text: String) {
        guard let url = URL(string: configuration.apiURL) else {
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didFailWithError: TwoStepLLMError.invalidURL)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 判断是否需要一句话总结
        let needsSummary = text.count > 150
        
        let systemPrompt = """
        你是一个精准的闪念分类助手。请严格按照以下要求处理用户输入：

        1. **类型判定**（必须选择其一）：
           - 灵感(inspiration)：创意想法、突发奇想、新点子
           - 想法(idea)：明确计划、具体决定、行动意向
           - 思考(reflection)：深度思考、疑问探索、矛盾分析

        2. **生成标题**：
           - 提取核心内容，生成10字以内的简洁标题
           - 保持原意，不过度概括

        3. **标签生成**：
           - 生成1-3个相关标签，每个标签2-4个字

        \(needsSummary ? "4. **一句话总结**：\n   - 因为输入超过150字，请提供一句话总结（30字以内）\n   - 保留核心信息，去除冗余内容" : "")

        输出格式要求（严格JSON）：
        {
          "title": "简洁标题",
          "type": "inspiration/idea/reflection",
          "tags": ["标签1", "标签2"],
          \(needsSummary ? "\"summary\": \"一句话总结\"," : "")
          "confidence": 0.9
        }

        注意：必须输出纯JSON，不要有任何额外文字。
        """
        
        let requestBody: [String: Any] = [
            "model": configuration.liteModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 200
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didFailWithError: error)
            }
            return
        }
        
        print("第一步：使用lite模型进行分类...")
        
        currentTask = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.twoStepLLMService(self, didFailWithError: error)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.delegate?.twoStepLLMService(self, didFailWithError: TwoStepLLMError.emptyResponse)
                }
                return
            }
            
            self.handleFirstStepResponse(data, originalText: text)
        }
        
        currentTask?.resume()
    }
    
    private func handleFirstStepResponse(_ data: Data, originalText: String) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let response = json as? [String: Any],
                  let choices = response["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw TwoStepLLMError.parseError
            }
            
            print("第一步响应内容: \(content)")
            
            // 解析lite模型返回的JSON
            guard let jsonData = content.data(using: .utf8),
                  let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw TwoStepLLMError.parseError
            }
            
            let title = result["title"] as? String ?? "未命名"
            let typeString = result["type"] as? String ?? "unknown"
            let tags = result["tags"] as? [String] ?? []
            let summary = result["summary"] as? String
            
            let thoughtType = FlashThoughtType(rawValue: 
                typeString == "inspiration" ? "灵感" :
                typeString == "idea" ? "想法" :
                typeString == "reflection" ? "思考" : "未分类"
            ) ?? .unknown
            
            let firstStepResult = FirstStepAnalysis(
                title: title,
                oneSentenceSummary: summary,
                thoughtType: thoughtType,
                tags: tags,
                originalText: originalText,
                timestamp: Date()
            )
            
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didCompleteFirstStep: firstStepResult)
                self.currentStep = 2
            }
            
            // 继续第二步
            self.performSecondStepAnalysis(firstStepResult)
            
        } catch {
            print("第一步解析失败: \(error)")
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didFailWithError: error)
            }
        }
    }
    
    // MARK: - Step 2: 生成辅助内容
    
    private func performSecondStepAnalysis(_ firstStepResult: FirstStepAnalysis) {
        guard let url = URL(string: configuration.apiURL) else {
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didFailWithError: TwoStepLLMError.invalidURL)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 根据类型选择不同的prompt
        let typePrompt = getPromptForType(firstStepResult.thoughtType)
        
        let systemPrompt = """
        你是一个闪念辅助助手，用户记录了一个\(firstStepResult.thoughtType.rawValue)类型的闪念。
        
        原始内容：\(firstStepResult.originalText)
        类型：\(firstStepResult.thoughtType.rawValue)
        标题：\(firstStepResult.title)
        
        \(typePrompt)
        
        输出要求（严格JSON格式）：
        {
          "keyPoints": ["辅助点1", "辅助点2"],
          "sentiment": "positive/neutral/negative"
        }
        
        注意：
        - keyPoints数组包含2-3个辅助内容点
        - 每个点控制在20字以内
        - sentiment表示内容的情感倾向
        - 必须输出纯JSON，不要有任何额外文字
        """
        
        let requestBody: [String: Any] = [
            "model": configuration.flashModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "请根据上述内容生成辅助信息"]
            ],
            "temperature": 0.5,
            "max_tokens": 300
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didFailWithError: error)
            }
            return
        }
        
        print("第二步：使用flash模型生成辅助内容...")
        
        currentTask = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.currentStep = 0
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.twoStepLLMService(self, didFailWithError: error)
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.delegate?.twoStepLLMService(self, didFailWithError: TwoStepLLMError.emptyResponse)
                }
                return
            }
            
            self.handleSecondStepResponse(data, firstStepResult: firstStepResult)
        }
        
        currentTask?.resume()
    }
    
    private func handleSecondStepResponse(_ data: Data, firstStepResult: FirstStepAnalysis) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let response = json as? [String: Any],
                  let choices = response["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw TwoStepLLMError.parseError
            }
            
            print("第二步响应内容: \(content)")
            
            // 解析flash模型返回的JSON
            let keyPoints: [String]
            let sentiment: String?
            
            if let jsonData = content.data(using: .utf8),
               let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                keyPoints = result["keyPoints"] as? [String] ?? []
                sentiment = result["sentiment"] as? String
            } else {
                // 如果解析失败，使用默认值
                keyPoints = ["已记录\(firstStepResult.thoughtType.rawValue)"]
                sentiment = "neutral"
            }
            
            // 构建最终结果
            let finalResult = TwoStepAnalysisResult(
                title: firstStepResult.title,
                summary: firstStepResult.oneSentenceSummary ?? firstStepResult.originalText,
                thoughtType: firstStepResult.thoughtType,
                tags: firstStepResult.tags,
                keyPoints: keyPoints,
                sentiment: sentiment,
                originalText: firstStepResult.originalText,
                timestamp: firstStepResult.timestamp
            )
            
            DispatchQueue.main.async {
                self.lastResult = finalResult
                self.delegate?.twoStepLLMService(self, didCompleteFinalAnalysis: finalResult)
            }
            
        } catch {
            print("第二步解析失败: \(error)")
            // 即使第二步失败，也返回第一步的结果
            let fallbackResult = TwoStepAnalysisResult(
                title: firstStepResult.title,
                summary: firstStepResult.oneSentenceSummary ?? firstStepResult.originalText,
                thoughtType: firstStepResult.thoughtType,
                tags: firstStepResult.tags,
                keyPoints: ["已记录\(firstStepResult.thoughtType.rawValue)"],
                sentiment: nil,
                originalText: firstStepResult.originalText,
                timestamp: firstStepResult.timestamp
            )
            
            DispatchQueue.main.async {
                self.lastResult = fallbackResult
                self.delegate?.twoStepLLMService(self, didCompleteFinalAnalysis: fallbackResult)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPromptForType(_ type: FlashThoughtType) -> String {
        switch type {
        case .inspiration:
            return """
            这是一个灵感类型的闪念。请生成：
            1. 2-3个场景延伸提示或实现建议
            2. 帮助用户将灵感具体化的辅助点
            重点：激发创意、提供方向、保持灵感的新鲜感
            """
            
        case .idea:
            return """
            这是一个想法类型的闪念。请生成：
            1. 2-3个执行细节或补充信息
            2. 帮助用户完善想法的具体建议
            重点：提供细节、明确步骤、增强可执行性
            """
            
        case .reflection:
            return """
            这是一个思考类型的闪念。请生成：
            1. 2-3个思考方向或深入角度
            2. 帮助用户深化思考的引导点
            重点：拓展视角、深化理解、提供新的思考维度
            """
            
        case .unknown:
            return """
            请生成2-3个相关的辅助信息点，帮助用户更好地记录和理解这个内容。
            """
        }
    }
}

// MARK: - 错误类型
enum TwoStepLLMError: Error, LocalizedError {
    case invalidURL
    case requestError(Error)
    case networkError(Error)
    case apiError(code: Int, message: String)
    case parseError
    case emptyResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的API URL"
        case .requestError(let error):
            return "请求错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API错误 \(code): \(message)"
        case .parseError:
            return "响应解析错误"
        case .emptyResponse:
            return "响应数据为空"
        case .timeout:
            return "请求超时"
        }
    }
}