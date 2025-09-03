//
//  DoubaoLLMService.swift
//  raku
//
//  豆包大模型API服务
//  用于对语音识别结果进行AI总结和分析
//

import Foundation
import Combine

// MARK: - 豆包API配置
struct DoubaoConfiguration {
    let apiURL: String
    let apiKey: String
    let model: String
    let timeout: TimeInterval
    
    // 默认配置
    static let `default` = DoubaoConfiguration(
        apiURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        apiKey: "7dda38f8-2383-434c-9d8d-a26263d4b5d1",
        model: "doubao-seed-1-6-flash-250715",
        timeout: 30.0
    )
}

// MARK: - LLM分析结果
struct LLMAnalysisResult {
    let summary: String
    let keyPoints: [String]
    let tags: [String]
    let sentiment: String?
    let confidence: Float
    let timestamp: Date
    
    init(summary: String, keyPoints: [String] = [], tags: [String] = [], sentiment: String? = nil, confidence: Float = 0.8) {
        self.summary = summary
        self.keyPoints = keyPoints
        self.tags = tags
        self.sentiment = sentiment
        self.confidence = confidence
        self.timestamp = Date()
    }
}

// MARK: - 豆包LLM服务协议
protocol DoubaoLLMServiceDelegate: AnyObject {
    func llmService(_ service: DoubaoLLMService, didCompleteAnalysis result: LLMAnalysisResult)
    func llmService(_ service: DoubaoLLMService, didFailWithError error: Error)
}

// MARK: - 豆包大模型服务
class DoubaoLLMService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var lastResult: LLMAnalysisResult?
    
    // MARK: - Private Properties
    private let configuration: DoubaoConfiguration
    private var urlSession: URLSession
    private let queue = DispatchQueue(label: "com.raku.doubao.llm", qos: .userInitiated)
    private var currentTask: URLSessionDataTask?
    
    // MARK: - Delegate
    weak var delegate: DoubaoLLMServiceDelegate?
    
    // MARK: - Initialization
    init(configuration: DoubaoConfiguration = .default) {
        self.configuration = configuration
        
        // 配置URLSession
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
    
    deinit {
        stopAnalysis()
    }
    
    // MARK: - Public Methods
    
    /// 分析语音识别文本
    func analyzeText(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("分析文本为空")
            return
        }
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
        }
        
        queue.async { [weak self] in
            self?.performLLMAnalysis(text)
        }
    }
    
    /// 停止分析
    func stopAnalysis() {
        currentTask?.cancel()
        currentTask = nil
        
        DispatchQueue.main.async {
            self.isAnalyzing = false
        }
    }
    
    // MARK: - Private Methods
    
    /// 执行LLM分析
    private func performLLMAnalysis(_ text: String) {
        guard let url = URL(string: configuration.apiURL) else {
            DispatchQueue.main.async {
                self.delegate?.llmService(self, didFailWithError: DoubaoLLMError.invalidURL)
            }
            return
        }
        
        // 构建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 构建消息内容
        let systemPrompt = """
        你是一个**瞬时闪念辅助助手**，专注于帮用户处理**散步/地铁/睡前等场景下的瞬时灵感、想法、思考**——核心是「保留闪念原生感，给出轻量化辅助」，不做过度总结或结构化。

        请严格遵循以下步骤处理：
        1. **识别闪念类型**：先判断用户内容属于哪一类（优先匹配最贴合的类型）：
           - 灵感：未落地的创意/突然冒出来的点子（如“想做桂花香蜡烛”“咖啡加柠檬”）；
           - 想法：主观观点/明确决策（如“PPT封面用蓝色”“明天早餐吃包子”）；
           - 思考：带疑问/矛盾的深度探索（如“为什么年轻人容易焦虑”“露营好玩但贵”）。
        2. **生成对应辅助**：根据类型输出轻量化内容（不超过2条，用短句）：
           - 灵感：① 推荐1-2个分类标签（如「美食创意」「手工DIY」）；② 1个场景延伸提示（如“需要帮你记录尝试时间吗？”“要不要关联「香薰」分类？”）；
           - 想法：补充1-2个细节（如“推荐深空蓝（Pantone 19-4052）”“包子铺早8点开始营业”）；
           - 思考：给出2-3个思考方向（如“1. 信息过载的认知负担；2. 对「成功标准」的迷茫”）。
        3. **输出格式要求**：严格用JSON返回，字段含义：
           - summary：**保留原生感的干净描述**（过滤“哦对了”“其实吧”等语气词，但保留用户口语风格，如“想做桂花香蜡烛”而非“用户计划开发桂花香型蜡烛”）；
           - keyPoints：辅助内容（按类型对应，如灵感的“场景延伸提示”、思考的“思考方向”）；
           - tags：推荐的分类标签（数组，1-2个）；
           - sentiment（可选）：闪念的情绪倾向（positive/neutral/negative，无法判断则省略）。

        注意：
        - 不做语法润色，不改变用户原意；
        - 辅助内容务必轻量化，不用长句或复杂结构；
        - 若无法明确类型，默认按「想法」处理。
        """
        
        let requestBody: [String: Any] = [
            "model": configuration.model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user", 
                    "content": "请分析以下语音转写内容：\n\n\(text)"
                ]
            ],
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.llmService(self, didFailWithError: DoubaoLLMError.requestError(error))
            }
            return
        }
        
        print("正在发送分析请求到豆包API...")
        
        // 发送请求
        currentTask = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isAnalyzing = false
            }
            
            // 检查网络错误
            if let error = error {
                print("网络请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.delegate?.llmService(self, didFailWithError: DoubaoLLMError.networkError(error))
                }
                return
            }
            
            // 检查HTTP响应
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    let errorMessage = "HTTP错误: \(httpResponse.statusCode)"
                    print(errorMessage)
                    
                    if let data = data,
                       let errorBody = String(data: data, encoding: .utf8) {
                        print("错误详情: \(errorBody)")
                    }
                    
                    DispatchQueue.main.async {
                        let error = DoubaoLLMError.apiError(
                            code: httpResponse.statusCode,
                            message: errorMessage
                        )
                        self.delegate?.llmService(self, didFailWithError: error)
                    }
                    return
                }
            }
            
            // 处理响应数据
            guard let data = data else {
                print("响应数据为空")
                DispatchQueue.main.async {
                    self.delegate?.llmService(self, didFailWithError: DoubaoLLMError.emptyResponse)
                }
                return
            }
            
            self.handleLLMResponse(data)
        }
        
        currentTask?.resume()
    }
    
    /// 处理LLM响应
    private func handleLLMResponse(_ data: Data) {
        do {
            // 解析API响应
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let response = json as? [String: Any] else {
                throw DoubaoLLMError.parseError
            }
            
            print("豆包API响应: \(response)")
            
            // 提取choices数组
            guard let choices = response["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw DoubaoLLMError.parseError
            }
            
            print("LLM返回内容: \(content)")
            
            // 解析LLM返回的JSON内容
            let analysisResult = try parseLLMContent(content)
            
            DispatchQueue.main.async {
                self.lastResult = analysisResult
                self.delegate?.llmService(self, didCompleteAnalysis: analysisResult)
            }
            
        } catch {
            print("解析响应失败: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("原始响应: \(responseString)")
            }
            
            DispatchQueue.main.async {
                self.delegate?.llmService(self, didFailWithError: error)
            }
        }
    }
    
    /// 解析LLM返回的内容
    private func parseLLMContent(_ content: String) throws -> LLMAnalysisResult {
        // 尝试直接解析JSON
        if let jsonData = content.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            
            let summary = jsonObject["summary"] as? String ?? ""
            let keyPoints = jsonObject["keyPoints"] as? [String] ?? []
            let tags = jsonObject["tags"] as? [String] ?? []
            let sentiment = jsonObject["sentiment"] as? String
            
            return LLMAnalysisResult(
                summary: summary,
                keyPoints: keyPoints,
                tags: tags,
                sentiment: sentiment,
                confidence: 0.9
            )
        }
        
        // 如果JSON解析失败，从文本中提取信息
        return extractAnalysisFromText(content)
    }
    
    /// 从文本中提取分析结果
    private func extractAnalysisFromText(_ content: String) -> LLMAnalysisResult {
        // 简单的文本提取逻辑
        var summary = content
        var keyPoints: [String] = []
        var tags: [String] = []
        
        // 提取要点（查找数字列表）
        let keyPointPattern = #"\d+\.\s*([^\n\r]+)"#
        if let regex = try? NSRegularExpression(pattern: keyPointPattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            keyPoints = matches.compactMap { match in
                if let range = Range(match.range(at: 1), in: content) {
                    return String(content[range])
                }
                return nil
            }
        }
        
        // 提取标签（查找#标签）
        let tagPattern = #"#(\w+)"#
        if let regex = try? NSRegularExpression(pattern: tagPattern) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            tags = matches.compactMap { match in
                if let range = Range(match.range(at: 1), in: content) {
                    return String(content[range])
                }
                return nil
            }
        }
        
        // 清理总结内容
        summary = summary.replacingOccurrences(of: #"\d+\.\s*[^\n\r]*"#, with: "", options: .regularExpression)
        summary = summary.replacingOccurrences(of: #"#\w+"#, with: "", options: .regularExpression)
        summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return LLMAnalysisResult(
            summary: summary.isEmpty ? content : summary,
            keyPoints: keyPoints,
            tags: tags,
            confidence: 0.7
        )
    }
}

// MARK: - 错误类型
enum DoubaoLLMError: Error, LocalizedError {
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
