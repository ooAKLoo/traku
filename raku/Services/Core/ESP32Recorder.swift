//
//  ESP32Recorder.swift
//  raku - ESP32硬件录音实现
//
//  重构说明：
//  - 整合原有的ESP32AudioService功能
//  - 实现AudioRecorder统一接口
//  - 专注于ESP32录音的具体实现
//

import Foundation
import Combine

// MARK: - ESP32录音器实现
class ESP32Recorder: AudioRecorder {
    
    // MARK: - AudioRecorder 协议实现
    var isAvailable: Bool {
        connectionStatus == .connected
    }
    
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    
    let sourceType: AudioSourceType = .esp32
    
    // MARK: - 事件回调
    var onRecordingStarted: (() -> Void)?
    var onRecordingFinished: ((AudioRecordingResult) -> Void)?
    var onRecordingCancelled: (() -> Void)?
    var onAmplitudeUpdate: ((Float) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - ESP32特有属性
    @Published var connectionStatus: ESP32ConnectionStatus = .disconnected
    @Published var connectedDevice: ESP32Device?
    
    private var webSocket: URLSessionWebSocketTask?
    private var recordingStartTime: Date?
    private var accumulatedAudioData = Data()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - ESP32设备信息
    struct ESP32Device {
        let name: String
        let ipAddress: String
        let port: Int
    }
    
    enum ESP32ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
        
        static func == (lhs: ESP32ConnectionStatus, rhs: ESP32ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected), (.connecting, .connecting), (.connected, .connected):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    // MARK: - 连接管理
    func connect(to device: ESP32Device) async throws {
        guard connectionStatus != .connected else { return }
        
        connectionStatus = .connecting
        connectedDevice = device
        
        let url = URL(string: "ws://\(device.ipAddress):\(device.port)/audio")!
        webSocket = URLSession.shared.webSocketTask(with: url)
        
        // 监听WebSocket消息
        startListening()
        webSocket?.resume()
        
        // 等待连接确认
        try await waitForConnection()
    }
    
    func disconnect() async {
        webSocket?.cancel()
        webSocket = nil
        connectionStatus = .disconnected
        connectedDevice = nil
        
        if isRecording {
            await cancelRecording()
        }
    }
    
    // MARK: - 录制控制实现
    
    func startRecording() async throws {
        guard !isRecording else {
            throw AudioRecordingError.alreadyRecording
        }
        
        guard isAvailable else {
            throw AudioRecordingError.sourceNotAvailable
        }
        
        // 发送开始录音命令到ESP32
        let command = ESP32Command.startRecording
        try await sendCommand(command)
        
        recordingStartTime = Date()
        accumulatedAudioData = Data()
        
        await MainActor.run {
            isRecording = true
            isPaused = false
        }
        
        onRecordingStarted?()
    }
    
    func stopRecording() async -> AudioRecordingResult? {
        guard isRecording else { return nil }
        
        // 发送停止录音命令到ESP32
        do {
            let command = ESP32Command.stopRecording
            try await sendCommand(command)
        } catch {
            onError?(error)
        }
        
        await MainActor.run {
            isRecording = false
            isPaused = false
        }
        
        // 构建录音结果
        if let startTime = recordingStartTime {
            let result = AudioRecordingResult(
                audioData: accumulatedAudioData,
                duration: Date().timeIntervalSince(startTime),
                timestamp: startTime,
                sourceType: .esp32
            )
            
            onRecordingFinished?(result)
            return result
        }
        
        return nil
    }
    
    func cancelRecording() async {
        guard isRecording else { return }
        
        // 发送取消录音命令到ESP32
        do {
            let command = ESP32Command.cancelRecording
            try await sendCommand(command)
        } catch {
            onError?(error)
        }
        
        await MainActor.run {
            isRecording = false
            isPaused = false
        }
        
        accumulatedAudioData = Data()
        onRecordingCancelled?()
    }
    
    func pauseRecording() async throws {
        guard isRecording && !isPaused else {
            throw AudioRecordingError.notRecording
        }
        
        let command = ESP32Command.pauseRecording
        try await sendCommand(command)
        
        await MainActor.run {
            isPaused = true
        }
    }
    
    func resumeRecording() async throws {
        guard isRecording && isPaused else {
            throw AudioRecordingError.notRecording
        }
        
        let command = ESP32Command.resumeRecording
        try await sendCommand(command)
        
        await MainActor.run {
            isPaused = false
        }
    }
    
    // MARK: - 私有方法
    
    private func waitForConnection() async throws {
        // 简化的连接等待逻辑
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒超时
        
        if connectionStatus != .connected {
            throw AudioRecordingError.configurationFailed("ESP32连接超时")
        }
    }
    
    private func startListening() {
        guard let webSocket = webSocket else { return }
        
        webSocket.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                self?.startListening() // 继续监听
            case .failure(let error):
                self?.onError?(AudioRecordingError.recordingFailed("WebSocket错误: \(error.localizedDescription)"))
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            // 处理音频数据
            accumulatedAudioData.append(data)
            
            // 模拟音频振幅计算（实际应该从ESP32获取）
            let amplitude = Float.random(in: 0...1)
            DispatchQueue.main.async {
                self.onAmplitudeUpdate?(amplitude)
            }
            
        case .string(let text):
            // 处理状态消息
            handleStatusMessage(text)
            
        @unknown default:
            break
        }
    }
    
    private func handleStatusMessage(_ message: String) {
        // 解析ESP32状态消息
        if message.contains("connected") {
            connectionStatus = .connected
        } else if message.contains("error") {
            connectionStatus = .error(message)
        }
    }
    
    private func sendCommand(_ command: ESP32Command) async throws {
        guard let webSocket = webSocket else {
            throw AudioRecordingError.sourceNotAvailable
        }
        
        let commandData = try JSONEncoder().encode(command)
        let message = URLSessionWebSocketTask.Message.data(commandData)
        
        try await webSocket.send(message)
    }
}

// MARK: - ESP32命令定义
private enum ESP32Command: Codable {
    case startRecording
    case stopRecording
    case pauseRecording
    case resumeRecording
    case cancelRecording
    
    var command: String {
        switch self {
        case .startRecording: return "start_recording"
        case .stopRecording: return "stop_recording"
        case .pauseRecording: return "pause_recording"
        case .resumeRecording: return "resume_recording"
        case .cancelRecording: return "cancel_recording"
        }
    }
}