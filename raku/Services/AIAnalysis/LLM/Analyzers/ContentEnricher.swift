//
//  ContentEnricher.swift
//  raku
//
//  内容丰富化分析器 - 负责生成深度 enrichedContent
//

import Foundation

final class ContentEnricher: LLMAnalyzer {
    typealias Input = (polishedText: String, thoughtType: FlashThoughtType)
    typealias Output = String

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

    func analyze(_ input: Input) async throws -> String {
        let (polishedText, thoughtType) = input

        guard !polishedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TwoStepLLMError.emptyResponse
        }

        return try await withCheckedThrowingContinuation { continuation in
            let systemPrompt = LLMPromptConfiguration.getMarkdownPromptForType(thoughtType)

            let parameters: [String: Any] = [
                "model": configuration.flashModel,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": polishedText]
                ],
                "temperature": 0.6,
                "max_tokens": 10000
            ]

            print("🚀 [ContentEnricher] 开始内容丰富化分析（使用 \(configuration.flashModel)）")

            _ = networkService.performJSONRequest(
                url: configuration.apiURL,
                method: .POST,
                parameters: parameters
            ) { result in
                switch result {
                case .success(let data):
                    do {
                        let enrichedContent = try self.parseResponse(data)
                        print("✅ [ContentEnricher] 内容丰富化完成")
                        continuation.resume(returning: enrichedContent)
                    } catch {
                        print("❌ [ContentEnricher] 解析失败: \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("❌ [ContentEnricher] 网络请求失败: \(error)")
                    continuation.resume(throwing: self.convertNetworkError(error))
                }
            }
        }
    }

    // MARK: - Private Methods

    private func parseResponse(_ data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let response = json as? [String: Any],
              let choices = response["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw TwoStepLLMError.parseError
        }

        print("📄 [ContentEnricher] 响应内容预览: \(content.prefix(100))...")
        return content
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
