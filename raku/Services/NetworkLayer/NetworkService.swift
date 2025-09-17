//
//  NetworkService.swift
//  raku
//
//  Created by 杨东举 on 2025/9/13.
//  网络服务统一管理层 - 纯粹的网络层，不感知业务逻辑
//

import Foundation
import UIKit

// MARK: - HTTP方法
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - 网络请求配置
struct NetworkConfiguration {
    let timeout: TimeInterval
    let defaultHeaders: [String: String]?
    let enableBackgroundRequests: Bool
    let maxRetryAttempts: Int
    let retryDelay: TimeInterval
    
    init(
        timeout: TimeInterval = 200.0,  // 默认200秒超时，适合AI服务
        defaultHeaders: [String: String]? = nil,
        enableBackgroundRequests: Bool = true,
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 2.0  // 默认2秒重试延迟
    ) {
        self.timeout = timeout
        self.defaultHeaders = defaultHeaders
        self.enableBackgroundRequests = enableBackgroundRequests
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
    }
}

// MARK: - 网络错误
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case requestError(Error)
    case networkError(Error)
    case httpError(code: Int)
    case emptyResponse
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .requestError(let error):
            return "请求错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP错误: \(code)"
        case .emptyResponse:
            return "响应数据为空"
        case .timeout:
            return "请求超时"
        }
    }
}

// MARK: - 网络服务
class NetworkService: NSObject {
    private let configuration: NetworkConfiguration
    private let urlSession: URLSession
    private let queue: DispatchQueue
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    
    // 存储待处理的请求
    private var pendingRequests: [URLSessionTask: (Result<Data, NetworkError>) -> Void] = [:]
    private let requestsLock = NSLock()
    
    init(configuration: NetworkConfiguration = NetworkConfiguration()) {
        self.configuration = configuration
        self.queue = DispatchQueue(label: "com.raku.network", qos: .userInitiated)
        
        // 始终使用默认会话，通过UIBackgroundTask支持后台执行
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        if let defaultHeaders = configuration.defaultHeaders {
            sessionConfig.httpAdditionalHeaders = defaultHeaders
        }
        
        // 创建URLSession，不使用delegate（避免后台会话问题）
        self.urlSession = URLSession(configuration: sessionConfig)
        
        super.init()
    }
    
    /// 执行网络请求（带重试机制）
    @discardableResult
    func performRequest(
        url: String,
        method: HTTPMethod = .GET,
        headers: [String: String]? = nil,
        body: Data? = nil,
        completion: @escaping (Result<Data, NetworkError>) -> Void
    ) -> URLSessionDataTask? {
        return performRequestWithRetry(
            url: url,
            method: method,
            headers: headers,
            body: body,
            retryCount: 0,
            completion: completion
        )
    }
    
    /// 带重试机制的网络请求
    private func performRequestWithRetry(
        url: String,
        method: HTTPMethod,
        headers: [String: String]?,
        body: Data?,
        retryCount: Int,
        completion: @escaping (Result<Data, NetworkError>) -> Void
    ) -> URLSessionDataTask? {
        
        guard let requestURL = URL(string: url) else {
            completion(.failure(.invalidURL))
            return nil
        }
        
        // 开始后台任务（如果启用）
        if configuration.enableBackgroundRequests {
            beginBackgroundTask()
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = method.rawValue
        request.httpBody = body
        
        // 设置headers
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            defer {
                if self?.configuration.enableBackgroundRequests == true {
                    self?.endBackgroundTask()
                }
            }
            
            if let error = error {
                // 检查是否需要重试
                if retryCount < self?.configuration.maxRetryAttempts ?? 0 {
                    print("网络请求失败，准备重试 (\(retryCount + 1)/\(self?.configuration.maxRetryAttempts ?? 0)): \(error.localizedDescription)")
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + (self?.configuration.retryDelay ?? 1.0)) {
                        _ = self?.performRequestWithRetry(
                            url: url,
                            method: method,
                            headers: headers,
                            body: body,
                            retryCount: retryCount + 1,
                            completion: completion
                        )
                    }
                    return
                }
                completion(.failure(.networkError(error)))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                    // HTTP错误也可以重试
                    if retryCount < self?.configuration.maxRetryAttempts ?? 0 {
                        print("HTTP错误，准备重试 (\(retryCount + 1)/\(self?.configuration.maxRetryAttempts ?? 0)): \(httpResponse.statusCode)")
                        
                        DispatchQueue.global().asyncAfter(deadline: .now() + (self?.configuration.retryDelay ?? 1.0)) {
                            _ = self?.performRequestWithRetry(
                                url: url,
                                method: method,
                                headers: headers,
                                body: body,
                                retryCount: retryCount + 1,
                                completion: completion
                            )
                        }
                        return
                    }
                    completion(.failure(.httpError(code: httpResponse.statusCode)))
                    return
                }
            }
            
            guard let data = data else {
                completion(.failure(.emptyResponse))
                return
            }
            
            completion(.success(data))
        }
        
        task.resume()
        return task
    }
    
    /// JSON请求便捷方法
    @discardableResult
    func performJSONRequest(
        url: String,
        method: HTTPMethod = .POST,
        headers: [String: String]? = nil,
        parameters: [String: Any],
        completion: @escaping (Result<Data, NetworkError>) -> Void
    ) -> URLSessionDataTask? {
        
        var requestHeaders = headers ?? [:]
        requestHeaders["Content-Type"] = "application/json"
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            completion(.failure(.requestError(NSError(domain: "JSONSerialization", code: -1))))
            return nil
        }
        
        return performRequest(
            url: url,
            method: method,
            headers: requestHeaders,
            body: jsonData,
            completion: completion
        )
    }
    
    /// 多部分表单请求便捷方法
    @discardableResult
    func performMultipartRequest(
        url: String,
        method: HTTPMethod = .POST,
        headers: [String: String]? = nil,
        formData: Data,
        boundary: String,
        completion: @escaping (Result<Data, NetworkError>) -> Void
    ) -> URLSessionDataTask? {
        
        var requestHeaders = headers ?? [:]
        requestHeaders["Content-Type"] = "multipart/form-data; boundary=\(boundary)"
        
        return performRequest(
            url: url,
            method: method,
            headers: requestHeaders,
            body: formData,
            completion: completion
        )
    }
    
    /// 取消所有请求
    func cancelAllRequests() {
        urlSession.invalidateAndCancel()
    }
    
    // MARK: - 后台任务管理
    
    private func beginBackgroundTask() {
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "NetworkRequest") { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
}

// MARK: - 多部分表单数据构建器
class MultipartFormDataBuilder {
    private var data = Data()
    private let boundary: String
    
    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }
    
    var boundaryString: String {
        return boundary
    }
    
    func addField(name: String, value: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }
    
    func addFile(name: String, filename: String, data fileData: Data, mimeType: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
    }
    
    func build() -> Data {
        var finalData = data
        finalData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return finalData
    }
}