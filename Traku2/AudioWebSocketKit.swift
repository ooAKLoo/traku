//
//  AudioWebSocketKit.swift
//  音频 WebSocket 整合工具包
//
//  这个文件提供了一个简单易用的接口，整合了 WebSocket 连接和音频流处理功能
//  使用说明请参见文件末尾的 USAGE_EXAMPLES
//

import Foundation
import SwiftUI
import Combine

// MARK: - 整合模块协议
public protocol AudioWebSocketKitDelegate: AnyObject {
    /// 连接状态改变
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didChangeConnectionStatus isConnected: Bool, status: String)
    
    /// 录音状态改变
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didChangeRecordingStatus isRecording: Bool, duration: TimeInterval)
    
    /// 音频振幅更新
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didUpdateAmplitude amplitude: Float)
    
    /// 录音完成
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didFinishRecording data: RecordingData)
    
    /// 发生错误
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didEncounterError error: Error)
}

// MARK: - 默认实现（可选方法）
public extension AudioWebSocketKitDelegate {
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didChangeConnectionStatus isConnected: Bool, status: String) {}
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didChangeRecordingStatus isRecording: Bool, duration: TimeInterval) {}
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didUpdateAmplitude amplitude: Float) {}
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didFinishRecording data: RecordingData) {}
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didEncounterError error: Error) {}
}

// MARK: - 音频 WebSocket 整合工具包
public class AudioWebSocketKit: ObservableObject {
    // MARK: - Published Properties
    @Published public var isConnected = false
    @Published public var connectionStatus = "未连接"
    @Published public var isRecording = false
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var currentAmplitude: Float = 0
    
    // MARK: - Private Properties
    private let webSocketModule: WebSocketModule
    private let audioStreamModule: AudioStreamModule
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Delegate
    public weak var delegate: AudioWebSocketKitDelegate?
    
    // MARK: - Initialization
    public init(
        webSocketConfig: WebSocketConfiguration,
        audioConfig: AudioStreamConfiguration = .standard
    ) {
        self.webSocketModule = WebSocketModule(configuration: webSocketConfig)
        self.audioStreamModule = AudioStreamModule(configuration: audioConfig)
        
        setupBindings()
        setupDelegates()
    }
    
    // MARK: - Convenience Initializer
    public convenience init(esp32Host: String) {
        let wsConfig = WebSocketConfiguration(host: esp32Host)
        self.init(webSocketConfig: wsConfig)
    }
    
    // MARK: - Public Methods
    
    /// 连接到服务器
    public func connect() {
        webSocketModule.connect()
    }
    
    /// 断开连接
    public func disconnect() {
        stopRecording()
        webSocketModule.disconnect()
    }
    
    /// 开始录音
    public func startRecording() {
        guard isConnected else {
            delegate?.audioWebSocketKit(self, didEncounterError: AudioWebSocketKitError.notConnected)
            return
        }
        
        webSocketModule.sendTextMessage("START")
        audioStreamModule.startRecording()
    }
    
    /// 停止录音
    public func stopRecording() {
        if isConnected {
            webSocketModule.sendTextMessage("STOP")
        }
        audioStreamModule.stopRecording()
    }
    
    /// 播放录音数据
    public func playRecording(_ data: Data) {
        audioStreamModule.playAudioData(data)
    }
    
    /// 停止播放
    public func stopPlaying() {
        audioStreamModule.stopPlaying()
    }
    
    /// 创建 WAV 文件
    public func createWAVFile(from audioData: Data) -> Data {
        return audioStreamModule.createWAVFile(from: audioData)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // WebSocket 状态绑定
        webSocketModule.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
        
        webSocketModule.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionStatus, on: self)
            .store(in: &cancellables)
        
        // 音频状态绑定
        audioStreamModule.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        audioStreamModule.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: \.recordingDuration, on: self)
            .store(in: &cancellables)
        
        audioStreamModule.$currentAmplitude
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentAmplitude, on: self)
            .store(in: &cancellables)
    }
    
    private func setupDelegates() {
        webSocketModule.delegate = self
        audioStreamModule.delegate = self
    }
}

// MARK: - WebSocketModuleDelegate
extension AudioWebSocketKit: WebSocketModuleDelegate {
    public func webSocketDidChangeConnectionStatus(_ module: WebSocketModule, isConnected: Bool, status: String) {
        delegate?.audioWebSocketKit(self, didChangeConnectionStatus: isConnected, status: status)
    }
    
    public func webSocketDidReceiveTextMessage(_ module: WebSocketModule, message: String) {
        // 处理文本消息（如果需要）
    }
    
    public func webSocketDidReceiveData(_ module: WebSocketModule, data: Data) {
        // 将接收到的音频数据传递给音频模块处理
        audioStreamModule.processReceivedAudioData(data)
    }
    
    public func webSocketDidEncounterError(_ module: WebSocketModule, error: Error) {
        delegate?.audioWebSocketKit(self, didEncounterError: error)
    }
}

// MARK: - AudioStreamModuleDelegate
extension AudioWebSocketKit: AudioStreamModuleDelegate {
    public func audioStreamDidStartRecording(_ module: AudioStreamModule) {
        // 录音开始状态已通过 @Published 属性自动更新
    }
    
    public func audioStreamDidStopRecording(_ module: AudioStreamModule, audioData: Data, duration: TimeInterval) {
        let recordingData = RecordingData(
            data: audioData,
            duration: duration,
            configuration: AudioStreamConfiguration.standard, // 可以改为动态获取
            timestamp: Date()
        )
        delegate?.audioWebSocketKit(self, didFinishRecording: recordingData)
    }
    
    public func audioStreamDidUpdateAmplitude(_ module: AudioStreamModule, amplitude: Float) {
        delegate?.audioWebSocketKit(self, didUpdateAmplitude: amplitude)
    }
    
    public func audioStreamDidStartPlaying(_ module: AudioStreamModule) {
        // 播放状态处理（如果需要）
    }
    
    public func audioStreamDidStopPlaying(_ module: AudioStreamModule) {
        // 播放结束处理（如果需要）
    }
    
    public func audioStreamDidEncounterError(_ module: AudioStreamModule, error: Error) {
        delegate?.audioWebSocketKit(self, didEncounterError: error)
    }
}

// MARK: - 错误类型
public enum AudioWebSocketKitError: Error, LocalizedError {
    case notConnected
    case recordingInProgress
    case playbackInProgress
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "未连接到服务器"
        case .recordingInProgress:
            return "录音正在进行中"
        case .playbackInProgress:
            return "音频正在播放中"
        }
    }
}

// MARK: - SwiftUI 视图组件
public struct AudioWebSocketKitStatusView: View {
    @ObservedObject var kit: AudioWebSocketKit
    
    public init(kit: AudioWebSocketKit) {
        self.kit = kit
    }
    
    public var body: some View {
        HStack {
            Circle()
                .fill(kit.isConnected ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            
            Text(kit.connectionStatus)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if kit.isRecording {
                Text(formatTime(kit.recordingDuration))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - 使用示例
/*
 USAGE_EXAMPLES:
 
 1. 基本使用：
 
 ```swift
 class MyViewController: UIViewController, AudioWebSocketKitDelegate {
     private let audioKit = AudioWebSocketKit(esp32Host: "192.168.1.100")
     
     override func viewDidLoad() {
         super.viewDidLoad()
         audioKit.delegate = self
     }
     
     func connectToESP32() {
         audioKit.connect()
     }
     
     func startRecording() {
         audioKit.startRecording()
     }
     
     // 实现代理方法
     func audioWebSocketKit(_ kit: AudioWebSocketKit, didFinishRecording data: RecordingData) {
         print("录音完成，时长：\(data.formattedDuration)")
         // 保存录音或进行其他处理
     }
 }
 ```
 
 2. SwiftUI 使用：
 
 ```swift
 struct ContentView: View {
     @StateObject private var audioKit = AudioWebSocketKit(esp32Host: "192.168.1.100")
     
     var body: some View {
         VStack {
             AudioWebSocketKitStatusView(kit: audioKit)
             
             Button(audioKit.isRecording ? "停止录音" : "开始录音") {
                 if audioKit.isRecording {
                     audioKit.stopRecording()
                 } else {
                     audioKit.startRecording()
                 }
             }
         }
         .onAppear {
             audioKit.connect()
         }
     }
 }
 ```
 
 3. 高级配置：
 
 ```swift
 let wsConfig = WebSocketConfiguration(
     host: "192.168.1.100",
     port: 81,
     path: "/audio",
     timeoutInterval: 15,
     reconnectInterval: 5,
     maxReconnectAttempts: 3
 )
 
 let audioConfig = AudioStreamConfiguration(
     sampleRate: 44100,
     channels: 2,
     bitsPerSample: 16,
     enableRealTimeMonitoring: true
 )
 
 let audioKit = AudioWebSocketKit(
     webSocketConfig: wsConfig,
     audioConfig: audioConfig
 )
 ```
 */