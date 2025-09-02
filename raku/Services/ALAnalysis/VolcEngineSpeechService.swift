//
//  VolcEngineSpeechService.swift
//  raku
//
//  SenseVoice语音识别服务
//  用于将音频数据转换为文本
//

import Foundation
import Combine

// MARK: - SenseVoice配置
struct SenseVoiceConfiguration {
    let serverURL: String
    let endpoint: String
    let timeout: TimeInterval
    
    // 默认配置 - 指向你的SenseVoice服务器
    static let `default` = SenseVoiceConfiguration(
        serverURL: "http://192.168.1.100:8000",  // 替换为你的服务器地址
        endpoint: "/transcribe/normal",
        timeout: 30.0
    )
}

// MARK: - 语音识别结果
struct SpeechRecognitionResult {
    let text: String
    let confidence: Float
    let isFinal: Bool
    let timestamp: Date
    let language: String?
    let emotion: String?
    
    init(text: String, confidence: Float = 0.0, isFinal: Bool = false, language: String? = nil, emotion: String? = nil) {
        self.text = text
        self.confidence = confidence
        self.isFinal = isFinal
        self.timestamp = Date()
        self.language = language
        self.emotion = emotion
    }
}

// MARK: - 语音识别协议
protocol VolcEngineSpeechServiceDelegate: AnyObject {
    func speechService(_ service: VolcEngineSpeechService, didReceiveResult result: SpeechRecognitionResult)
    func speechService(_ service: VolcEngineSpeechService, didCompleteWithError error: Error?)
    func speechService(_ service: VolcEngineSpeechService, didReceiveLLMAnalysis result: LLMAnalysisResult)
    func speechServiceDidStartRecognition(_ service: VolcEngineSpeechService)
    func speechServiceDidStopRecognition(_ service: VolcEngineSpeechService)
}

// MARK: - SenseVoice语音识别服务
class VolcEngineSpeechService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecognizing = false
    @Published var lastResult: SpeechRecognitionResult?
    @Published var allResults: [SpeechRecognitionResult] = []
    
    // MARK: - Private Properties
    private let configuration: SenseVoiceConfiguration
    private var urlSession: URLSession
    private let queue = DispatchQueue(label: "com.raku.sensevoice.speech", qos: .userInitiated)
    private var currentTask: URLSessionDataTask?
    
    // MARK: - LLM集成
    private let llmService = DoubaoLLMService()
    
    // MARK: - Delegate
    weak var delegate: VolcEngineSpeechServiceDelegate?
    
    // MARK: - Initialization
    init(configuration: SenseVoiceConfiguration = .default) {
        self.configuration = configuration
        
        // 配置URLSession
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.urlSession = URLSession(configuration: sessionConfig)
        
        super.init()
        
        // 设置LLM服务代理
        llmService.delegate = self
    }
    
    deinit {
        stopRecognition()
    }
    
    // MARK: - Public Methods
    
    /// 开始语音识别（准备接收音频）
    func startRecognition() {
        DispatchQueue.main.async {
            self.isRecognizing = true
            self.delegate?.speechServiceDidStartRecognition(self)
        }
    }
    
    /// 停止语音识别
    func stopRecognition() {
        currentTask?.cancel()
        currentTask = nil
        
        DispatchQueue.main.async {
            self.isRecognizing = false
            self.delegate?.speechServiceDidStopRecognition(self)
        }
    }
    
    /// 发送音频数据进行识别（使用SenseVoice HTTP API）
    func sendAudioData(_ audioData: Data) {
        guard !audioData.isEmpty else {
            print("音频数据为空")
            return
        }
        
        queue.async { [weak self] in
            self?.recognizeAudioWithSenseVoice(audioData)
        }
    }
    
    /// 使用SenseVoice API识别音频文件
    private func recognizeAudioWithSenseVoice(_ audioData: Data) {
        // 构建URL
        guard let url = URL(string: "\(configuration.serverURL)\(configuration.endpoint)") else {
            print("无效的URL配置")
            DispatchQueue.main.async {
                self.delegate?.speechService(self, didCompleteWithError: SenseVoiceError.invalidURL)
            }
            return
        }
        
        // 创建multipart/form-data请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        var body = Data()
        
        // 添加音频文件
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // 添加语言参数
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("auto\r\n".data(using: .utf8)!)  // 自动检测语言
        
        // 添加ITN参数（逆文本正规化）
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"use_itn\"\r\n\r\n".data(using: .utf8)!)
        body.append("true\r\n".data(using: .utf8)!)
        
        // 结束boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("正在发送音频到SenseVoice服务器: \(url.absoluteString)")
        print("音频大小: \(audioData.count) bytes")
        
        // 发送请求
        currentTask = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 检查网络错误
            if let error = error {
                print("网络请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.delegate?.speechService(self, didCompleteWithError: SenseVoiceError.networkError(error))
                }
                return
            }
            
            // 检查HTTP响应状态
            if let httpResponse = response as? HTTPURLResponse {
                print("HTTP状态码: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    let errorMessage = "HTTP错误: \(httpResponse.statusCode)"
                    print(errorMessage)
                    
                    // 尝试读取错误详情
                    if let data = data,
                       let errorBody = String(data: data, encoding: .utf8) {
                        print("错误详情: \(errorBody)")
                    }
                    
                    DispatchQueue.main.async {
                        let error = SenseVoiceError.apiError(
                            code: httpResponse.statusCode,
                            message: errorMessage
                        )
                        self.delegate?.speechService(self, didCompleteWithError: error)
                    }
                    return
                }
            }
            
            // 处理响应数据
            guard let data = data else {
                print("响应数据为空")
                DispatchQueue.main.async {
                    self.delegate?.speechService(self, didCompleteWithError: SenseVoiceError.audioProcessingError)
                }
                return
            }
            
            self.handleSenseVoiceResponse(data)
        }
        
        currentTask?.resume()
    }
    
    /// 处理SenseVoice响应
    private func handleSenseVoiceResponse(_ data: Data) {
        do {
            // 解析JSON响应
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let response = json as? [String: Any] else {
                print("响应格式不正确")
                DispatchQueue.main.async {
                    self.delegate?.speechService(self, didCompleteWithError: SenseVoiceError.audioProcessingError)
                }
                return
            }
            
            print("SenseVoice响应: \(response)")
            
            // 提取识别文本
            if let text = response["text"] as? String {
                // 创建识别结果
                let result = SpeechRecognitionResult(
                    text: text,
                    confidence: 1.0,  // SenseVoice可能不返回置信度
                    isFinal: true,
                    language: response["language"] as? String,
                    emotion: response["emotion"] as? String
                )
                
                print("识别成功: \(text)")
                
                DispatchQueue.main.async {
                    self.lastResult = result
                    self.allResults.append(result)
                    self.delegate?.speechService(self, didReceiveResult: result)
                    self.delegate?.speechService(self, didCompleteWithError: nil)
                    
                    // 自动调用LLM进行文本分析
                    self.llmService.analyzeText(text)
                }
            } else {
                print("响应中没有找到识别文本")
                
                // 检查是否有错误信息
                if let detail = response["detail"] as? String {
                    print("错误详情: \(detail)")
                    DispatchQueue.main.async {
                        let error = SenseVoiceError.apiError(code: -1, message: detail)
                        self.delegate?.speechService(self, didCompleteWithError: error)
                    }
                } else {
                    DispatchQueue.main.async {
                        let error = SenseVoiceError.apiError(code: -1, message: "未找到识别结果")
                        self.delegate?.speechService(self, didCompleteWithError: error)
                    }
                }
            }
            
        } catch {
            print("解析响应JSON失败: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("原始响应: \(responseString)")
            }
            
            DispatchQueue.main.async {
                self.delegate?.speechService(self, didCompleteWithError: SenseVoiceError.audioProcessingError)
            }
        }
    }
    
    /// 清空识别结果
    func clearResults() {
        DispatchQueue.main.async {
            self.allResults.removeAll()
            self.lastResult = nil
        }
    }
    
    /// 获取完整的识别文本
    var fullRecognitionText: String {
        return allResults.map { $0.text }.joined(separator: " ")
    }
    
    /// 获取最新的完整识别结果
    var latestFinalResult: SpeechRecognitionResult? {
        return allResults.last
    }
    
    /// 检查是否有识别结果
    var hasResults: Bool {
        return !allResults.isEmpty
    }
}

// MARK: - DoubaoLLMServiceDelegate
extension VolcEngineSpeechService: DoubaoLLMServiceDelegate {
    func llmService(_ service: DoubaoLLMService, didCompleteAnalysis result: LLMAnalysisResult) {
        print("LLM分析完成: \(result.summary)")
        delegate?.speechService(self, didReceiveLLMAnalysis: result)
    }
    
    func llmService(_ service: DoubaoLLMService, didFailWithError error: Error) {
        print("LLM分析失败: \(error.localizedDescription)")
    }
}

// MARK: - 错误类型
enum SenseVoiceError: Error, LocalizedError {
    case invalidURL
    case invalidConfiguration
    case networkError(Error)
    case apiError(code: Int, message: String)
    case audioProcessingError
    case authenticationError
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的服务器URL"
        case .invalidConfiguration:
            return "配置无效"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "API错误 \(code): \(message)"
        case .audioProcessingError:
            return "音频处理错误"
        case .authenticationError:
            return "认证失败"
        case .timeout:
            return "请求超时"
        }
    }
}
