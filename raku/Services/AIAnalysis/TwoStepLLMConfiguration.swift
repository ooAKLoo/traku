//
//  TwoStepLLMConfiguration.swift
//  raku
//
//  Created by 杨东举 on 2025/9/2.
//  优化版本：第二步使用Markdown输出格式
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
//        flashModel: "doubao-seed-1-6-flash-250715",
        flashModel: "doubao-seed-1-6-thinking-250715",
        timeout: 300.0
    )
}

// MARK: - 闪念类型枚举
enum FlashThoughtType: String, CaseIterable {
    case reflection = "思考"
    case unknown = "未分类"
    
    var promptKey: String {
        switch self {
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
    let polishedText: String  // 润色后的文本
    let timestamp: Date
}

// MARK: - 最终分析结果（简化版）
struct TwoStepAnalysisResult {
    let title: String
    let summary: String  // 一句话总结（如果有）或原文
    let thoughtType: FlashThoughtType
    let tags: [String]
    let enrichedContent: String  // 第二步生成的Markdown内容
    let originalText: String
    let polishedText: String  // 润色后的文本
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
    
    // MARK: - Step 1: 分类和标题生成（保持不变）
    
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
        
        let summaryField = needsSummary ? "\"summary\": \"用30-50字概括主要观点和核心论据\"," : ""
        
        let systemPrompt = """
        你是一个精准的闪念分类助手。请严格按照以下要求处理用户asr处理后的输入内容：

        1. **ASR文本矫正（用于polishedText字段）**：
           - 必须保留原文的所有句子和观点，不能遗漏或合并
           - 不允许省略补充论点、例子、细节，哪怕是次要的
           - 仅删除语气词（如"呃"、"嗯"、"就是"、"然后"、"Yeah"等）
           - 必须保持原文的完整逻辑链和所有表达
           - 不要对文本进行压缩、总结或抽象

        2. **类型判定**（必须选择其一）：
           - 思考(reflection)：深度思考、疑问探索、矛盾分析

        3. **生成标题**：
           - 提取核心内容，生成20字以内的概括标题
           - 保持原意，不过度概括

        4. **标签生成**：
           - 生成1-2个相关标签，每个标签2-4个字

        输出格式要求（严格JSON）：
        {
          "polishedText": "完整的润色后文本（去除口语词但保留所有内容）",
          "title": "简洁标题",
          "type": "reflection",
          "tags": ["标签1", "标签2"],
          \(summaryField)
          "confidence": 0.9
        }

        重要说明：
        - polishedText：必须是原文的完整润色版本，只清理口语化表达，不做任何总结
        - summary（如有）：这才是一句话总结
        - 两个字段功能完全不同，不要混淆
        - polishedText 必须与原文句子数量和顺序保持一致，只删除语气词和修正错误，不得合并句子或缩写。

        注意：必须输出纯JSON，不要有任何额外文字。
        """
        
        let requestBody: [String: Any] = [
            "model": configuration.flashModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 1,
            "max_tokens": 10000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didFailWithError: error)
            }
            return
        }
        
        print("第一步：使用flash模型进行分类...")
        
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
            let polishedText = result["polishedText"] as? String ?? originalText
            
            let thoughtType = FlashThoughtType(rawValue:
                typeString == "reflection" ? "思考" : "未分类"
            ) ?? .unknown
            
            let firstStepResult = FirstStepAnalysis(
                title: title,
                oneSentenceSummary: summary,
                thoughtType: thoughtType,
                tags: tags,
                originalText: originalText,
                polishedText: polishedText,
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
    
    // MARK: - Step 2: 生成Markdown格式的深度内容
    
    private func performSecondStepAnalysis(_ firstStepResult: FirstStepAnalysis) {
        guard let url = URL(string: configuration.apiURL) else {
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didFailWithError: TwoStepLLMError.invalidURL)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 获取特定类型的深度分析prompt
        let systemPrompt = getMarkdownPromptForType(firstStepResult.thoughtType)
        
        let requestBody: [String: Any] = [
            "model": configuration.flashModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": firstStepResult.polishedText]
            ],
            "temperature": 0.6,
            "max_tokens": 10000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.twoStepLLMService(self, didFailWithError: error)
            }
            return
        }
        
        print("第二步：使用flash模型进行深度分析...")
        
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
            
            // 构建最终结果
            let finalResult = TwoStepAnalysisResult(
                title: firstStepResult.title,
                summary: firstStepResult.oneSentenceSummary ?? firstStepResult.polishedText,
                thoughtType: firstStepResult.thoughtType,
                tags: firstStepResult.tags,
                enrichedContent: content, // 直接使用Markdown内容
                originalText: firstStepResult.originalText,
                polishedText: firstStepResult.polishedText,
                timestamp: firstStepResult.timestamp
            )
            
            DispatchQueue.main.async {
                self.lastResult = finalResult
                self.delegate?.twoStepLLMService(self, didCompleteFinalAnalysis: finalResult)
            }
            
        } catch {
            print("第二步解析失败: \(error)")
            // 提供降级方案
            let fallbackContent = "## 内容记录\n\n> 已成功保存您的\(firstStepResult.thoughtType.rawValue)\n\nLLM分析服务暂时不可用，但您的内容已安全记录。"
            
            let fallbackResult = TwoStepAnalysisResult(
                title: firstStepResult.title,
                summary: firstStepResult.oneSentenceSummary ?? firstStepResult.polishedText,
                thoughtType: firstStepResult.thoughtType,
                tags: firstStepResult.tags,
                enrichedContent: fallbackContent,
                originalText: firstStepResult.originalText,
                polishedText: firstStepResult.polishedText,
                timestamp: firstStepResult.timestamp
            )
            
            DispatchQueue.main.async {
                self.lastResult = fallbackResult
                self.delegate?.twoStepLLMService(self, didCompleteFinalAnalysis: fallbackResult)
            }
        }
    }
    
    // MARK: - Markdown Prompt生成器
    
    private func getMarkdownPromptForType(_ type: FlashThoughtType) -> String {
        switch type {
        case .reflection:
            return getReflectionMarkdownPrompt()
        case .unknown:
            return getGeneralMarkdownPrompt()
        }
    }
    
    private func getReflectionMarkdownPrompt() -> String {
            return """
            你是一个专业的思维整理专家，擅长使用金字塔原理（Pyramid Principle）来结构化杂乱的想法，帮助人们深化和闭环他们的思考。通过分析用户的初步想法，提炼核心要素，串联逻辑，并以人性化、自然流畅的方式呈现，帮助用户获得更清晰的洞见和行动启发。

            输出要求：
            - 以Markdown格式输出，确保整体简洁、易读，避免学术化。
            - 不使用emoji符号。
            """
        }
    
    private func getGeneralMarkdownPrompt() -> String {
        return """
        你是一个专业的思维整理专家，擅长使用金字塔原理（Pyramid Principle）来结构化杂乱的想法，帮助人们深化和闭环他们的思考。通过分析用户的初步想法，提炼核心要素，串联逻辑，并以人性化、自然流畅的方式呈现，帮助用户获得更清晰的洞见和行动启发。

        输出要求：
        - 以Markdown格式输出，确保整体简洁、易读，避免学术化。
        - 不使用emoji符号。
        """
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
