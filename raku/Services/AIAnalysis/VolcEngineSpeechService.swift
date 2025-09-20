//
//  VolcEngineSpeechService.swift
//  语音识别服务 - 支持 SenseVoice 和豆包语音识别 API
//

import Foundation
import Combine

// MARK: - ASR模型类型
enum ASRModelType {
    case senseVoice
    case doubao
}

// MARK: - SenseVoice配置
struct SenseVoiceConfiguration {
    let serverURL: String
    let endpoint: String
    let timeout: TimeInterval
    
    // 默认配置
    static let `default` = SenseVoiceConfiguration(
        serverURL: "http://115.190.136.178:8001",
        endpoint: "/transcribe/normal",
        timeout: 130.0
    )
}

// MARK: - 豆包语音识别配置
struct DoubaoSpeechConfiguration {
    let apiEndpoint: String
    let timeout: TimeInterval
    
    // 默认配置
    static let `default` = DoubaoSpeechConfiguration(
        apiEndpoint: "https://openspeech.bytedance.com/api/v3/auc/bigmodel/recognize/flash",
        timeout: 130.0
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
    func speechServiceDidStartRecognition(_ service: VolcEngineSpeechService)
    func speechServiceDidStopRecognition(_ service: VolcEngineSpeechService)
}

// MARK: - 语音识别服务（支持多种ASR模型）
class VolcEngineSpeechService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecognizing = false
    @Published var lastResult: SpeechRecognitionResult?
    @Published var allResults: [SpeechRecognitionResult] = []
    // 使用配置的默认模型
    private let currentModel: ASRModelType = ASRConfiguration.defaultModel
    
    // MARK: - Private Properties
    private let senseVoiceConfig: SenseVoiceConfiguration
    private let doubaoConfig: DoubaoSpeechConfiguration
    private let networkService: NetworkService
    private var currentTask: URLSessionDataTask?
    
    
    // MARK: - Delegate
    weak var delegate: VolcEngineSpeechServiceDelegate?
    
    // MARK: - Initialization
    init(senseVoiceConfig: SenseVoiceConfiguration = .default, 
         doubaoConfig: DoubaoSpeechConfiguration = .default) {
        self.senseVoiceConfig = senseVoiceConfig
        self.doubaoConfig = doubaoConfig
        
        // 使用统一的网络配置（headers会在请求时根据不同模型设置）
        let networkConfig = NetworkConfiguration(
            timeout: max(senseVoiceConfig.timeout, doubaoConfig.timeout)
        )
        self.networkService = NetworkService(configuration: networkConfig)
        
        super.init()
    }
    
    
    deinit {
        stopRecognition()
    }
    
    // MARK: - Public Methods
    
    /// 开始语音识别
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
    
    /// 发送音频数据进行识别
    func sendAudioData(_ audioData: Data) {
        guard !audioData.isEmpty else {
            print("音频数据为空")
            return
        }
        
        // 根据配置的模型选择识别方法
        switch currentModel {
        case .doubao:
            print("🎯 使用豆包模型进行语音识别")
            recognizeAudioWithDoubao(audioData)
        case .senseVoice:
            print("🎯 使用SenseVoice模型进行语音识别")
            recognizeAudioWithSenseVoice(audioData)
        }
    }
    
    /// 处理录音音频数据
    func processRecordingAudio(_ audioData: Data, duration: TimeInterval) {
        print("🎤 处理音频数据，大小: \(audioData.count) bytes, 时长: \(duration)秒")
        
        // 检查是否已经是WAV格式
        let isWAVFormat = audioData.count > 4 && 
                         audioData.prefix(4) == Data([0x52, 0x49, 0x46, 0x46]) // "RIFF"
        
        let finalAudioData: Data
        if isWAVFormat {
            // 已经是WAV格式，直接使用
            finalAudioData = audioData
            print("🎤 检测到WAV格式音频")
        } else {
            // 原始PCM数据，需要添加WAV头
            finalAudioData = createWAVFile(from: audioData)
            print("🎤 将PCM数据转换为WAV格式")
        }
        
        // 开始语音识别
        startRecognition()
        sendAudioData(finalAudioData)
    }
    
    /// 创建WAV文件头
    private func createWAVFile(from audioData: Data) -> Data {
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(audioData.count)
        let fileSize = dataSize + 36
        
        var header = Data()
        
        // RIFF chunk
        header.append("RIFF".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)
        
        // Format chunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // audio format (PCM)
        header.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // Data chunk
        header.append("data".data(using: .ascii)!)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        return header + audioData
    }
    
    /// 使用豆包语音识别 API识别音频文件
    private func recognizeAudioWithDoubao(_ audioData: Data) {
        // 将音频数据转换为Base64
        let base64Audio = audioData.base64EncodedString()
        
        // 准备请求头
        let headers: [String: String] = [
            "X-Api-App-Key": "8206093786",  // 从Python代码获取的APP ID
            "X-Api-Access-Key": "Yq1AuAcWxBELZP-MSUcyctGRcFU17HvX",  // 从Python代码获取的Access Token
            "X-Api-Resource-Id": "volc.bigasr.auc_turbo",
            "X-Api-Request-Id": UUID().uuidString,
            "X-Api-Sequence": "-1",
            "Content-Type": "application/json"
        ]
        
        // 准备请求体
        let requestBody: [String: Any] = [
            "user": [
                "uid": "8206093786"
            ],
            "audio": [
                "data": base64Audio
            ],
            "request": [
                "model_name": "bigmodel",
                "enable_itn": true,  // 启用数字转换
                "enable_punc": true,  // 启用标点
                "enable_ddc": true   // 启用顺滑
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            print("❌ 无法序列化请求体")
            DispatchQueue.main.async {
                self.delegate?.speechService(self, didCompleteWithError: DoubaoSpeechError.invalidConfiguration)
            }
            return
        }
        
        // 更新网络服务的headers
        let networkConfig = NetworkConfiguration(
            timeout: doubaoConfig.timeout,
            defaultHeaders: headers
        )
        let tempNetworkService = NetworkService(configuration: networkConfig)
        
        // 发送JSON请求
        currentTask = tempNetworkService.performJSONRequest(
            url: doubaoConfig.apiEndpoint,
            method: .POST,
            parameters: requestBody
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                self.handleDoubaoResponse(data)
            case .failure(let error):
                print("网络请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    let speechError = self.convertNetworkError(error)
                    self.delegate?.speechService(self, didCompleteWithError: speechError)
                }
            }
        }
    }
    
    /// 使用SenseVoice API识别音频文件
    private func recognizeAudioWithSenseVoice(_ audioData: Data) {
        // 构建multipart表单数据
        let formBuilder = MultipartFormDataBuilder()
        formBuilder.addFile(name: "file", filename: "audio.wav", data: audioData, mimeType: "audio/wav")
        formBuilder.addField(name: "language", value: "auto")
        formBuilder.addField(name: "use_itn", value: "true")
        
        let formData = formBuilder.build()
        let boundary = formBuilder.boundaryString
        
        let fullURL = "\(senseVoiceConfig.serverURL)\(senseVoiceConfig.endpoint)"
        
        // 发送请求
        currentTask = networkService.performMultipartRequest(
            url: fullURL,
            method: .POST,
            formData: formData,
            boundary: boundary
        ) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                self.handleSenseVoiceResponse(data)
            case .failure(let error):
                print("网络请求失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    let speechError = self.convertNetworkError(error)
                    self.delegate?.speechService(self, didCompleteWithError: speechError)
                }
            }
        }
    }
    
    /// 处理SenseVoice响应
    private func handleSenseVoiceResponse(_ data: Data) {
        do {
            // 先打印原始响应数据用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 SenseVoice原始响应: \(responseString)")
            }
            
            // 解析JSON响应
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let response = json as? [String: Any] else {
                print("❌ 响应格式不正确")
                DispatchQueue.main.async {
                    self.delegate?.speechService(self, didCompleteWithError: DoubaoSpeechError.audioProcessingError)
                }
                return
            }
            
            print("📋 解析后的JSON响应: \(response)")
            
            // 提取识别文本
            if let text = response["text"] as? String {
                print("✅ SenseVoice识别成功，文本: \(text)")
                
                // 创建识别结果
                let result = SpeechRecognitionResult(
                    text: text,
                    confidence: 1.0,  // SenseVoice可能不返回置信度
                    isFinal: true,
                    language: response["language"] as? String,
                    emotion: response["emotion"] as? String
                )
                
                DispatchQueue.main.async {
                    print("🔄 在主线程更新UI和通知代理")
                    self.lastResult = result
                    self.allResults.append(result)
                    
                    // 先通知结果，再通知完成
                    print("📢 通知代理：识别结果已获得")
                    self.delegate?.speechService(self, didReceiveResult: result)
                    
                    print("📢 通知代理：识别完成")
                    self.delegate?.speechService(self, didCompleteWithError: nil)
                }
            } else {
                // 检查是否有错误信息
                if let detail = response["detail"] as? String {
                    DispatchQueue.main.async {
                        let error = DoubaoSpeechError.apiError(code: -1, message: detail)
                        self.delegate?.speechService(self, didCompleteWithError: error)
                    }
                } else {
                    DispatchQueue.main.async {
                        let error = DoubaoSpeechError.apiError(code: -1, message: "未找到识别结果")
                        self.delegate?.speechService(self, didCompleteWithError: error)
                    }
                }
            }
            
        } catch {
            print("❌ JSON解析错误: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.delegate?.speechService(self, didCompleteWithError: DoubaoSpeechError.audioProcessingError)
            }
        }
    }
    
    /// 处理豆包语音识别响应
    private func handleDoubaoResponse(_ data: Data) {
        do {
            // 先打印原始响应数据用于调试
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 豆包语音识别原始响应: \(responseString)")
            }
            
            // 解析JSON响应（基于Python代码的响应格式）
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let response = json as? [String: Any] else {
                print("❌ 响应格式不正确")
                DispatchQueue.main.async {
                    self.delegate?.speechService(self, didCompleteWithError: DoubaoSpeechError.audioProcessingError)
                }
                return
            }
            
            print("📋 解析后的JSON响应: \(response)")
            
            // 根据Python代码，响应格式为: response.json().get('result', {}).get('text', '')
            if let result = response["result"] as? [String: Any],
               let text = result["text"] as? String {
                
                print("✅ 豆包语音识别成功，文本: \(text)")
                
                // 创建识别结果
                let recognitionResult = SpeechRecognitionResult(
                    text: text,
                    confidence: 1.0,
                    isFinal: true,
                    language: "zh",
                    emotion: nil
                )
                
                DispatchQueue.main.async {
                    print("🔄 在主线程更新UI和通知代理")
                    self.lastResult = recognitionResult
                    self.allResults.append(recognitionResult)
                    
                    // 先通知结果，再通知完成
                    print("📢 通知代理：识别结果已获得")
                    self.delegate?.speechService(self, didReceiveResult: recognitionResult)
                    
                    print("📢 通知代理：识别完成")
                    self.delegate?.speechService(self, didCompleteWithError: nil)
                }
            } else {
                // 检查是否有错误信息
                if let message = response["message"] as? String {
                    DispatchQueue.main.async {
                        let error = DoubaoSpeechError.apiError(code: response["code"] as? Int ?? -1, message: message)
                        self.delegate?.speechService(self, didCompleteWithError: error)
                    }
                } else {
                    DispatchQueue.main.async {
                        let error = DoubaoSpeechError.apiError(code: -1, message: "未找到识别结果")
                        self.delegate?.speechService(self, didCompleteWithError: error)
                    }
                }
            }
            
        } catch {
            print("❌ JSON解析错误: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.delegate?.speechService(self, didCompleteWithError: DoubaoSpeechError.audioProcessingError)
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
    
    // MARK: - 错误转换
    private func convertNetworkError(_ networkError: NetworkError) -> DoubaoSpeechError {
        switch networkError {
        case .invalidURL:
            return .invalidURL
        case .requestError(let error):
            return .networkError(error)
        case .networkError(let error):
            return .networkError(error)
        case .httpError(let code):
            return .apiError(code: code, message: "HTTP错误")
        case .emptyResponse:
            return .audioProcessingError
        case .timeout:
            return .timeout
        }
    }
}

// MARK: - 错误类型
enum DoubaoSpeechError: Error, LocalizedError {
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
            return "无效的API URL"
        case .invalidConfiguration:
            return "配置无效"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .apiError(let code, let message):
            return "豆包API错误 \(code): \(message)"
        case .audioProcessingError:
            return "音频处理错误"
        case .authenticationError:
            return "认证失败"
        case .timeout:
            return "请求超时"
        }
    }
}
