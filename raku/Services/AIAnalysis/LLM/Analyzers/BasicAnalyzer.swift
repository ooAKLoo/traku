//
//  BasicAnalyzer.swift
//  raku
//
//  基础分析器 - 负责标题、分类、标签、润色
//

import Foundation

final class BasicAnalyzer: LLMAnalyzer {
    typealias Input = String
    typealias Output = LiteAnalysisResult

    // MARK: - Properties

    private let configuration: TwoStepLLMConfiguration
    private let networkService: NetworkService

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
    }

    // MARK: - LLMAnalyzer Protocol

    func analyze(_ text: String) async throws -> LiteAnalysisResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TwoStepLLMError.emptyResponse
        }

        return try await withCheckedThrowingContinuation { continuation in
            // 获取用户已有的标签
            let existingTags = DatabaseManager.shared.getAllUniqueTags()
            let hasExistingTags = !existingTags.isEmpty

            let systemPrompt = LLMPromptConfiguration.getFirstStepSystemPrompt(
                needsSummary: false,
                hasExistingTags: hasExistingTags
            )
            let userPrompt = LLMPromptConfiguration.getFirstStepUserPrompt(
                text: text,
                existingTags: existingTags
            )

            let parameters: [String: Any] = [
                "model": configuration.liteModel,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": userPrompt]
                ],
                "temperature": 0.3,
                "top_p": 0.5,
                "frequency_penalty": 0.2,
                "presence_penalty": 0.1,
                "max_tokens": 4096
            ]

            print("🔍 [BasicAnalyzer] 开始基础分析（使用 \(configuration.liteModel)）")

            _ = networkService.performJSONRequest(
                url: configuration.apiURL,
                method: .POST,
                parameters: parameters
            ) { result in
                switch result {
                case .success(let data):
                    do {
                        let analysisResult = try self.parseResponse(data, originalText: text)
                        print("✅ [BasicAnalyzer] 分析完成: \(analysisResult.title)")
                        continuation.resume(returning: analysisResult)
                    } catch {
                        print("❌ [BasicAnalyzer] 解析失败: \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("❌ [BasicAnalyzer] 网络请求失败: \(error)")
                    continuation.resume(throwing: self.convertNetworkError(error))
                }
            }
        }
    }

    // MARK: - Private Methods

    private func parseResponse(_ data: Data, originalText: String) throws -> LiteAnalysisResult {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let response = json as? [String: Any],
              let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TwoStepLLMError.parseError
        }

        print("📄 [BasicAnalyzer] 响应内容: \(content)")

        // 解析 lite 模型返回的 JSON
        guard let jsonData = content.data(using: .utf8),
              let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw TwoStepLLMError.parseError
        }

        let title = result["title"] as? String ?? "未命名"
        let typeString = result["type"] as? String ?? "unknown"
        let tags = result["tags"] as? [String] ?? []
        let summary = result["summary"] as? String
        let polishedText = result["polishedText"] as? String ?? originalText

        let thoughtType: FlashThoughtType
        switch typeString {
        case "reflection":
            thoughtType = .reflection
        case "insight":
            thoughtType = .insight
        default:
            thoughtType = .unknown
        }

        return LiteAnalysisResult(
            title: title,
            oneSentenceSummary: summary,
            thoughtType: thoughtType,
            tags: tags,
            originalText: originalText,
            polishedText: polishedText,
            timestamp: Date()
        )
    }

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
