//
//  VolcEngineSpeechService.swift
//  语音识别服务 - 使用 SenseVoice API
//

import Foundation
import Combine

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

// MARK: - SenseVoice语音识别服务
class VolcEngineSpeechService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecognizing = false
    @Published var lastResult: SpeechRecognitionResult?
    @Published var allResults: [SpeechRecognitionResult] = []
    
    // MARK: - Private Properties
    private let configuration: SenseVoiceConfiguration
    private let networkService: NetworkService
    private var currentTask: URLSessionDataTask?
    
    
    // MARK: - Delegate
    weak var delegate: VolcEngineSpeechServiceDelegate?
    
    // MARK: - Initialization
    init(configuration: SenseVoiceConfiguration = .default) {
        self.configuration = configuration
        
        let networkConfig = NetworkConfiguration(
            timeout: configuration.timeout
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
        
        recognizeAudioWithSenseVoice(audioData)
    }
    
    /// 处理录音音频数据
    func processRecordingAudio(_ audioData: Data, duration: TimeInterval) {
        // 将原始PCM数据转换为WAV格式
        let wavData = createWAVFile(from: audioData)
        
        // 开始语音识别
        startRecognition()
        sendAudioData(wavData)
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
    
    /// 使用SenseVoice API识别音频文件
    private func recognizeAudioWithSenseVoice(_ audioData: Data) {
        // 构建multipart表单数据
        let formBuilder = MultipartFormDataBuilder()
        formBuilder.addFile(name: "file", filename: "audio.wav", data: audioData, mimeType: "audio/wav")
        formBuilder.addField(name: "language", value: "auto")
        formBuilder.addField(name: "use_itn", value: "true")
        
        let formData = formBuilder.build()
        let boundary = formBuilder.boundaryString
        
        let fullURL = "\(configuration.serverURL)\(configuration.endpoint)"
        
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
                    self.delegate?.speechService(self, didCompleteWithError: SenseVoiceError.audioProcessingError)
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
            print("❌ JSON解析错误: \(error.localizedDescription)")
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
    
    // MARK: - 错误转换
    private func convertNetworkError(_ networkError: NetworkError) -> SenseVoiceError {
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
