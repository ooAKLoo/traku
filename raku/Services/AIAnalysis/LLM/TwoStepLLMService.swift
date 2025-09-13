//
//  TwoStepLLMService.swift
//  raku
//
//  Created by 杨东举 on 2025/9/2.
//  优化版本：第二步使用Markdown输出格式
//

import Foundation
import Combine

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
    private let networkService: NetworkService
    private var currentTask: URLSessionDataTask?
    
    // MARK: - Delegate
    weak var delegate: TwoStepLLMServiceDelegate?
    
    // MARK: - Initialization
    init(configuration: TwoStepLLMConfiguration = .default) {
        self.configuration = configuration
        
        let networkConfig = NetworkConfiguration(
            timeout: configuration.timeout,
            defaultHeaders: [
                "Authorization": "Bearer \(configuration.apiKey)"
            ]
        )
        self.networkService = NetworkService(configuration: networkConfig)
        
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
        
        performFirstStepAnalysis(text)
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
        // 判断是否需要一句话总结
        let needsSummary = text.count > 150
        
        let systemPrompt = LLMPromptConfiguration.getFirstStepSystemPrompt(needsSummary: needsSummary)
        
        let parameters: [String: Any] = [
            "model": configuration.flashModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 1,
            "max_tokens": 10000
        ]
        
        print("第一步：使用flash模型进行分类...")
        
        currentTask = networkService.performJSONRequest(
            url: configuration.apiURL,
            method: .POST,
            parameters: parameters
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                self.handleFirstStepResponse(data, originalText: text)
            case .failure(let error):
                DispatchQueue.main.async {
                    let llmError = self.convertNetworkError(error)
                    self.delegate?.twoStepLLMService(self, didFailWithError: llmError)
                }
            }
        }
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
        // 获取特定类型的深度分析prompt
        let systemPrompt = LLMPromptConfiguration.getMarkdownPromptForType(firstStepResult.thoughtType)
        
        let parameters: [String: Any] = [
            "model": configuration.flashModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": firstStepResult.polishedText]
            ],
            "temperature": 0.6,
            "max_tokens": 10000
        ]
        
        print("第二步：使用flash模型进行深度分析...")
        
        currentTask = networkService.performJSONRequest(
            url: configuration.apiURL,
            method: .POST,
            parameters: parameters
        ) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.currentStep = 0
            }
            
            switch result {
            case .success(let data):
                self.handleSecondStepResponse(data, firstStepResult: firstStepResult)
            case .failure(let error):
                DispatchQueue.main.async {
                    let llmError = self.convertNetworkError(error)
                    self.delegate?.twoStepLLMService(self, didFailWithError: llmError)
                }
            }
        }
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
    
    // MARK: - 错误转换
    private func convertNetworkError(_ networkError: NetworkError) -> TwoStepLLMError {
        switch networkError {
        case .invalidURL:
            return .invalidURL
        case .requestError(let error):
            return .requestError(error)
        case .networkError(let error):
            return .networkError(error)
        case .httpError(let code):
            return .apiError(code: code, message: "HTTP错误")
        case .emptyResponse:
            return .emptyResponse
        case .timeout:
            return .timeout
        }
    }
}