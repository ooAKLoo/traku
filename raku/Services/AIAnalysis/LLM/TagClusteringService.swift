//
//  TagClusteringService.swift
//  raku
//
//  Created by Assistant on 2025/9/19.
//  标签聚类分析服务
//

import Foundation
import Combine

// MARK: - 标签聚类结果模型

struct TagCluster {
    let representative: String      // 代表性标签
    let members: [String]          // 要合并的标签
    let reason: String             // 合并原因
}

struct TagClusteringResult {
    let clusters: [TagCluster]
    let totalClusters: Int
    let analysisSummary: String
}

// MARK: - 标签聚类错误类型

enum TagClusteringError: Error, LocalizedError {
    case invalidURL
    case requestError(Error)
    case networkError(Error)
    case apiError(code: Int, message: String)
    case parseError
    case emptyResponse
    case timeout
    case noTagsProvided
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的API地址"
        case .requestError(let error):
            return "请求错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API错误(\(code)): \(message)"
        case .parseError:
            return "响应解析失败"
        case .emptyResponse:
            return "服务器返回空响应"
        case .timeout:
            return "请求超时"
        case .noTagsProvided:
            return "未提供标签数据"
        }
    }
}

// MARK: - 标签聚类服务代理协议

protocol TagClusteringServiceDelegate: NSObjectProtocol {
    func tagClusteringService(_ service: TagClusteringService, didCompleteAnalysis result: TagClusteringResult)
    func tagClusteringService(_ service: TagClusteringService, didFailWithError error: TagClusteringError)
}

// MARK: - 标签聚类分析服务

class TagClusteringService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAnalyzing = false
    @Published var lastResult: TagClusteringResult?
    
    // MARK: - Private Properties
    private let apiURL: String
    private let apiKey: String
    private let model: String
    private let timeout: TimeInterval
    private var currentTask: URLSessionDataTask?
    
    // MARK: - Delegate
    weak var delegate: TagClusteringServiceDelegate?
    
    // MARK: - Initialization
    init(apiURL: String = "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
         apiKey: String = "7dda38f8-2383-434c-9d8d-a26263d4b5d1",
         model: String = "doubao-1-5-lite-32k-250115",
         timeout: TimeInterval = 30) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.model = model
        self.timeout = timeout
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 分析标签聚类
    func analyzeTags(_ tags: [String]) {
        guard !tags.isEmpty else {
            let error = TagClusteringError.noTagsProvided
            DispatchQueue.main.async {
                self.delegate?.tagClusteringService(self, didFailWithError: error)
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
        }
        
        performTagClustering(tags)
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
    
    private func performTagClustering(_ tags: [String]) {
        let systemPrompt = getSystemPrompt()
        let tagsString = tags.joined(separator: ", ")
        
        let parameters: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "请分析以下标签的聚类合并可能性：\n\n\(tagsString)"]
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        ]
        
        guard let url = URL(string: apiURL) else {
            DispatchQueue.main.async {
                self.delegate?.tagClusteringService(self, didFailWithError: .invalidURL)
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeout
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            DispatchQueue.main.async {
                self.delegate?.tagClusteringService(self, didFailWithError: .requestError(error))
            }
            return
        }
        
        print("🔍 开始标签聚类分析，共 \(tags.count) 个标签")
        
        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isAnalyzing = false
            }
            
            if let error = error {
                if (error as NSError).code == NSURLErrorTimedOut {
                    DispatchQueue.main.async {
                        self.delegate?.tagClusteringService(self, didFailWithError: .timeout)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.tagClusteringService(self, didFailWithError: .networkError(error))
                    }
                }
                return
            }
            
            guard let data = data, !data.isEmpty else {
                DispatchQueue.main.async {
                    self.delegate?.tagClusteringService(self, didFailWithError: .emptyResponse)
                }
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode != 200 {
                    DispatchQueue.main.async {
                        self.delegate?.tagClusteringService(self, didFailWithError: .apiError(code: statusCode, message: "HTTP错误"))
                    }
                    return
                }
            }
            
            self.handleResponse(data)
        }
        
        currentTask?.resume()
    }
    
    private func handleResponse(_ data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let response = json as? [String: Any],
                  let choices = response["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw TagClusteringError.parseError
            }
            
            print("📊 LLM分析响应: \(content)")
            
            // 解析JSON响应
            guard let jsonData = content.data(using: .utf8),
                  let result = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw TagClusteringError.parseError
            }
            
            let clustersData = result["clusters"] as? [[String: Any]] ?? []
            let totalClusters = result["total_clusters"] as? Int ?? clustersData.count
            let analysisSummary = result["analysis_summary"] as? String ?? ""
            
            var clusters: [TagCluster] = []
            for clusterData in clustersData {
                let representative = clusterData["representative"] as? String ?? ""
                let members = clusterData["members"] as? [String] ?? []
                let reason = clusterData["reason"] as? String ?? ""
                
                let cluster = TagCluster(
                    representative: representative,
                    members: members,
                    reason: reason
                )
                clusters.append(cluster)
            }
            
            let clusteringResult = TagClusteringResult(
                clusters: clusters,
                totalClusters: totalClusters,
                analysisSummary: analysisSummary
            )
            
            DispatchQueue.main.async {
                self.lastResult = clusteringResult
                self.delegate?.tagClusteringService(self, didCompleteAnalysis: clusteringResult)
            }
            
        } catch {
            print("❌ 解析标签聚类响应失败: \(error)")
            DispatchQueue.main.async {
                self.delegate?.tagClusteringService(self, didFailWithError: .parseError)
            }
        }
    }
    
    private func getSystemPrompt() -> String {
        return """
你是一个专业的标签聚类分析专家。请分析以下标签，找出语义相似、可以合并的标签组，并给出合并建议。

分析要求：
1. 识别语义相似的标签（如：AI 和 机器学习，UI 和 用户体验）
2. 考虑包含关系（如：编程 可能包含 开发）
3. 找出同义词或近义词
4. 每组至少包含2个标签才建议合并

输出格式（严格JSON）：
{
  "clusters": [
    {
      "representative": "代表性标签",
      "members": ["要合并的标签1", "要合并的标签2"],
      "reason": "合并原因说明"
    }
  ],
  "total_clusters": 聚类数量,
  "analysis_summary": "整体分析总结"
}

要求：
- 只返回纯JSON，不要额外文字
- representative 应该选择最通用、最具代表性的标签
- reason 要简洁明了地说明为什么这些标签应该合并
- 如果没有找到可合并的标签组，clusters 数组为空
"""
    }
}