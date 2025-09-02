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
        你是一个专业的会议记录分析助手。请根据提供的语音转写文本，生成简洁明了的总结。

        要求：
        1. 提取核心内容和关键信息
        2. 生成3-5个要点
        3. 识别2-4个相关标签
        4. 判断整体语调（positive/neutral/negative）
        5. 保持客观、准确的表述

        请用JSON格式返回结果：
        {
            "summary": "总结内容",
            "keyPoints": ["要点1", "要点2", "要点3"],
            "tags": ["标签1", "标签2"],
            "sentiment": "positive/neutral/negative"
        }
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