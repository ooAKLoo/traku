//
//  NetworkService.swift
//  raku
//
//  Created by 杨东举 on 2025/9/13.
//  网络服务统一管理层 - 纯粹的网络层，不感知业务逻辑
//

import Foundation

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
    
    init(timeout: TimeInterval = 30.0, defaultHeaders: [String: String]? = nil) {
        self.timeout = timeout
        self.defaultHeaders = defaultHeaders
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
class NetworkService {
    private let configuration: NetworkConfiguration
    private let urlSession: URLSession
    private let queue: DispatchQueue
    
    init(configuration: NetworkConfiguration = NetworkConfiguration()) {
        self.configuration = configuration
        self.queue = DispatchQueue(label: "com.raku.network", qos: .userInitiated)
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        
        if let defaultHeaders = configuration.defaultHeaders {
            sessionConfig.httpAdditionalHeaders = defaultHeaders
        }
        
        self.urlSession = URLSession(configuration: sessionConfig)
    }
    
    /// 执行网络请求
    @discardableResult
    func performRequest(
        url: String,
        method: HTTPMethod = .GET,
        headers: [String: String]? = nil,
        body: Data? = nil,
        completion: @escaping (Result<Data, NetworkError>) -> Void
    ) -> URLSessionDataTask? {
        
        guard let requestURL = URL(string: url) else {
            completion(.failure(.invalidURL))
            return nil
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
        
        let task = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
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