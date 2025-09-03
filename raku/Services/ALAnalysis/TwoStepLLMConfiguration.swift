//
//  TwoStepLLMConfiguration.swift
//  raku
//
//  Created by 杨东举 on 2025/9/2.
//  优化版本：增强第二步处理的深度和实用性
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

// MARK: - 最终分析结果（优化后的结构）
struct TwoStepAnalysisResult {
    let title: String
    let summary: String  // 一句话总结（如果有）或原文
    let thoughtType: FlashThoughtType
    let tags: [String]
    let structuredContent: StructuredContent  // 根据类型不同的结构化内容
    let originalText: String
    let timestamp: Date
}

// MARK: - 结构化内容（根据不同类型有不同的内容）
enum StructuredContent {
    case inspiration(InspirationContent)
    case idea(IdeaContent)
    case reflection(ReflectionContent)
    case general(GeneralContent)
}

// 灵感类型的结构化内容
struct InspirationContent {
    let coreValue: String           // 核心价值
    let possibilities: [String]     // 可能性探索（2-3个）
    let nextSteps: [String]         // 下一步建议（2-3个）
    let relatedDomains: [String]    // 相关领域
}

// 想法类型的结构化内容
struct IdeaContent {
    let objective: String           // 明确目标
    let actionItems: [String]       // 行动清单（3-5个）
    let resources: [String]         // 所需资源
    let timeline: String           // 时间框架
    let potentialChallenges: [String]  // 潜在挑战
}

// 思考类型的结构化内容
struct ReflectionContent {
    let coreQuestion: String        // 核心问题
    let logicalStructure: LogicalStructure  // 逻辑结构
    let perspectives: [String]      // 多元视角（2-3个）
    let insights: [String]         // 关键洞察（2-3个）
    let conclusion: String         // 思考结论
}

// 逻辑结构
struct LogicalStructure {
    let premise: String            // 前提
    let reasoning: [String]        // 推理过程（2-3步）
    let synthesis: String          // 综合
}

// 通用类型的结构化内容
struct GeneralContent {
    let keyPoints: [String]        // 要点
    let sentiment: String          // 情感倾向
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
           - 生成1-2个相关标签，每个标签2-4个字

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
    
    // MARK: - Step 2: 生成深度辅助内容（优化版）
    
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
        let (systemPrompt, expectedFormat) = getAdvancedPromptForType(firstStepResult.thoughtType)
        
        let requestBody: [String: Any] = [
            "model": configuration.flashModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": firstStepResult.originalText]  // 只传递原文
            ],
            "temperature": 0.6,  // 稍微提高温度以获得更有创意的回应
            "max_tokens": 800    // 增加token数以容纳更丰富的内容
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
            
            // 解析结构化内容
            let structuredContent = parseStructuredContent(
                content: content,
                thoughtType: firstStepResult.thoughtType
            )
            
            // 构建最终结果
            let finalResult = TwoStepAnalysisResult(
                title: firstStepResult.title,
                summary: firstStepResult.oneSentenceSummary ?? firstStepResult.originalText,
                thoughtType: firstStepResult.thoughtType,
                tags: firstStepResult.tags,
                structuredContent: structuredContent,
                originalText: firstStepResult.originalText,
                timestamp: firstStepResult.timestamp
            )
            
            DispatchQueue.main.async {
                self.lastResult = finalResult
                self.delegate?.twoStepLLMService(self, didCompleteFinalAnalysis: finalResult)
            }
            
        } catch {
            print("第二步解析失败: \(error)")
            // 提供降级方案
            let fallbackContent = StructuredContent.general(
                GeneralContent(
                    keyPoints: ["已记录\(firstStepResult.thoughtType.rawValue)"],
                    sentiment: "neutral"
                )
            )
            
            let fallbackResult = TwoStepAnalysisResult(
                title: firstStepResult.title,
                summary: firstStepResult.oneSentenceSummary ?? firstStepResult.originalText,
                thoughtType: firstStepResult.thoughtType,
                tags: firstStepResult.tags,
                structuredContent: fallbackContent,
                originalText: firstStepResult.originalText,
                timestamp: firstStepResult.timestamp
            )
            
            DispatchQueue.main.async {
                self.lastResult = fallbackResult
                self.delegate?.twoStepLLMService(self, didCompleteFinalAnalysis: fallbackResult)
            }
        }
    }
    
    // MARK: - 高级Prompt生成器
    
    private func getAdvancedPromptForType(_ type: FlashThoughtType) -> (prompt: String, format: String) {
        switch type {
        case .inspiration:
            return getInspirationPrompt()
        case .idea:
            return getIdeaPrompt()
        case .reflection:
            return getReflectionPrompt()
        case .unknown:
            return getGeneralPrompt()
        }
    }
    
    private func getInspirationPrompt() -> (String, String) {
        let prompt = """
        你是一位创新思维教练，擅长帮助人们将灵感转化为可能性。请对用户的灵感进行深度分析。

        分析框架：
        1. **价值挖掘**：找出这个灵感的核心价值和独特之处
        2. **可能性探索**：基于SCAMPER创新方法论，探索2-3个发展方向
        3. **行动转化**：提供2-3个将灵感落地的具体下一步
        4. **跨界连接**：识别可能相关的领域，促进创意融合

        分析原则：
        - 保护灵感的原创性和新鲜感
        - 激发而非限制创造力
        - 提供具体可行的探索路径
        - 鼓励大胆尝试和实验

        请输出严格的JSON格式：
        {
          "coreValue": "这个灵感的核心价值（20-30字）",
          "possibilities": [
            "可能性1：具体描述（20-30字）",
            "可能性2：具体描述（20-30字）"
          ],
          "nextSteps": [
            "步骤1：具体行动（15-20字）",
            "步骤2：具体行动（15-20字）"
          ],
          "relatedDomains": ["领域1", "领域2"]
        }
        """
        
        let format = "inspiration"
        return (prompt, format)
    }
    
    private func getIdeaPrompt() -> (String, String) {
        let prompt = """
        你是一位执行力专家，擅长将想法转化为可执行的行动计划。请对用户的想法进行实施分析。

        分析框架（基于SMART原则和GTD方法论）：
        1. **目标明确化**：将想法转化为清晰、可衡量的目标
        2. **行动分解**：运用WBS（工作分解结构）创建3-5个具体行动项
        3. **资源评估**：识别实现想法所需的关键资源
        4. **时间规划**：制定现实可行的时间框架
        5. **风险预判**：识别2-3个可能的挑战及应对思路

        分析原则：
        - 将抽象想法具体化
        - 确保每个行动项都可执行
        - 平衡理想与现实
        - 提供明确的优先级

        请输出严格的JSON格式：
        {
          "objective": "SMART目标描述（30-40字）",
          "actionItems": [
            "行动1：具体任务（15-20字）",
            "行动2：具体任务（15-20字）",
            "行动3：具体任务（15-20字）"
          ],
          "resources": [
            "资源1：具体说明（10-15字）",
            "资源2：具体说明（10-15字）"
          ],
          "timeline": "时间框架描述（15-20字）",
          "potentialChallenges": [
            "挑战1及应对（15-20字）",
            "挑战2及应对（15-20字）"
          ]
        }
        """
        
        let format = "idea"
        return (prompt, format)
    }
    
    private func getReflectionPrompt() -> (String, String) {
        let prompt = """
        你是一位认知心理学专家，精通金字塔原理、批判性思维和系统思考。请帮助用户将思考内容结构化。

        分析框架（融合金字塔原理和批判性思维）：
        
        1. **问题聚焦**：提炼用户思考的核心问题或矛盾点
        
        2. **逻辑梳理**（MECE原则）：
           - 识别核心前提
           - 展现推理链条（2-3步）
           - 形成逻辑综合

        3. **多维视角**（六顶思考帽）：
           - 提供2-3个不同的观察角度
           - 每个视角都能带来新的理解

        4. **洞察提炼**：
           - 从思考中提取2-3个关键洞察
           - 这些洞察应该是可以指导行动的

        5. **思考闭环**：
           - 形成一个明确的结论或下一步思考方向
           - 确保思考有所收获

        分析原则：
        - 尊重原始思考的复杂性
        - 使用结构化方法提升清晰度
        - 识别思维盲点和认知偏见
        - 促进深度理解而非表面分析

        请输出严格的JSON格式：
        {
          "coreQuestion": "核心问题或矛盾（20-30字）",
          "logicalStructure": {
            "premise": "基础前提（15-20字）",
            "reasoning": [
              "推理步骤1（15-20字）",
              "推理步骤2（15-20字）"
            ],
            "synthesis": "逻辑综合（20-25字）"
          },
          "perspectives": [
            "视角1：描述（20-25字）",
            "视角2：描述（20-25字）"
          ],
          "insights": [
            "洞察1：具体内容（20-25字）",
            "洞察2：具体内容（20-25字）"
          ],
          "conclusion": "思考结论或下一步方向（25-30字）"
        }
        """
        
        let format = "reflection"
        return (prompt, format)
    }
    
    private func getGeneralPrompt() -> (String, String) {
        let prompt = """
        请提炼用户输入的关键信息，并分析其情感倾向。

        输出JSON格式：
        {
          "keyPoints": [
            "要点1（15-20字）",
            "要点2（15-20字）"
          ],
          "sentiment": "positive/neutral/negative"
        }
        """
        
        let format = "general"
        return (prompt, format)
    }
    
    // MARK: - 解析结构化内容
    
    private func parseStructuredContent(content: String, thoughtType: FlashThoughtType) -> StructuredContent {
        guard let jsonData = content.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            // 返回降级内容
            return .general(GeneralContent(keyPoints: ["已记录内容"], sentiment: "neutral"))
        }
        
        switch thoughtType {
        case .inspiration:
            return parseInspirationContent(from: result)
        case .idea:
            return parseIdeaContent(from: result)
        case .reflection:
            return parseReflectionContent(from: result)
        case .unknown:
            return parseGeneralContent(from: result)
        }
    }
    
    private func parseInspirationContent(from json: [String: Any]) -> StructuredContent {
        let content = InspirationContent(
            coreValue: json["coreValue"] as? String ?? "",
            possibilities: json["possibilities"] as? [String] ?? [],
            nextSteps: json["nextSteps"] as? [String] ?? [],
            relatedDomains: json["relatedDomains"] as? [String] ?? []
        )
        return .inspiration(content)
    }
    
    private func parseIdeaContent(from json: [String: Any]) -> StructuredContent {
        let content = IdeaContent(
            objective: json["objective"] as? String ?? "",
            actionItems: json["actionItems"] as? [String] ?? [],
            resources: json["resources"] as? [String] ?? [],
            timeline: json["timeline"] as? String ?? "",
            potentialChallenges: json["potentialChallenges"] as? [String] ?? []
        )
        return .idea(content)
    }
    
    private func parseReflectionContent(from json: [String: Any]) -> StructuredContent {
        let logicalDict = json["logicalStructure"] as? [String: Any] ?? [:]
        let logicalStructure = LogicalStructure(
            premise: logicalDict["premise"] as? String ?? "",
            reasoning: logicalDict["reasoning"] as? [String] ?? [],
            synthesis: logicalDict["synthesis"] as? String ?? ""
        )
        
        let content = ReflectionContent(
            coreQuestion: json["coreQuestion"] as? String ?? "",
            logicalStructure: logicalStructure,
            perspectives: json["perspectives"] as? [String] ?? [],
            insights: json["insights"] as? [String] ?? [],
            conclusion: json["conclusion"] as? String ?? ""
        )
        return .reflection(content)
    }
    
    private func parseGeneralContent(from json: [String: Any]) -> StructuredContent {
        let content = GeneralContent(
            keyPoints: json["keyPoints"] as? [String] ?? [],
            sentiment: json["sentiment"] as? String ?? "neutral"
        )
        return .general(content)
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
