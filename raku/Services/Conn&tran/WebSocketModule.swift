//
//  WebSocketModule.swift
//  可复用的 WebSocket 连接模块
//
//  使用说明：
//  1. 遵循 WebSocketModuleDelegate 协议
//  2. 创建 WebSocketModule 实例
//  3. 设置代理并调用 connect() 方法
//

import Foundation
import Combine

// MARK: - WebSocket 模块协议
public protocol WebSocketModuleDelegate: AnyObject {
    /// WebSocket 连接状态改变
    func webSocketDidChangeConnectionStatus(_ module: WebSocketModule, isConnected: Bool, status: String)
    
    /// 接收到文本消息
    func webSocketDidReceiveTextMessage(_ module: WebSocketModule, message: String)
    
    /// 接收到二进制数据
    func webSocketDidReceiveData(_ module: WebSocketModule, data: Data)
    
    /// WebSocket 发生错误
    func webSocketDidEncounterError(_ module: WebSocketModule, error: Error)
}

// MARK: - WebSocket 连接配置
public struct WebSocketConfiguration {
    let host: String
    let port: Int
    let path: String
    let timeoutInterval: TimeInterval
    let reconnectInterval: TimeInterval
    let maxReconnectAttempts: Int
    
    public init(
        host: String,
        port: Int = 81,
        path: String = "/",
        timeoutInterval: TimeInterval = 10,
        reconnectInterval: TimeInterval = 3,
        maxReconnectAttempts: Int = 5
    ) {
        self.host = host
        self.port = port
        self.path = path
        self.timeoutInterval = timeoutInterval
        self.reconnectInterval = reconnectInterval
        self.maxReconnectAttempts = maxReconnectAttempts
    }
}

// MARK: - 可复用的 WebSocket 模块
public class WebSocketModule: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published public var isConnected = false
    @Published public var connectionStatus = "未连接"
    @Published public var lastError: Error?
    
    // MARK: - Private Properties
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private let configuration: WebSocketConfiguration
    private var reconnectAttempts = 0
    private var reconnectTimer: Timer?
    private var isManualDisconnect = false
    
    // MARK: - Delegate
    public weak var delegate: WebSocketModuleDelegate?
    
    // MARK: - Initialization
    public init(configuration: WebSocketConfiguration) {
        self.configuration = configuration
        super.init()
        setupURLSession()
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Public Methods
    
    /// 连接到 WebSocket 服务器
    public func connect() {
        isManualDisconnect = false
        reconnectAttempts = 0
        performConnection()
    }
    
    /// 断开 WebSocket 连接
    public func disconnect() {
        isManualDisconnect = true
        cancelReconnectTimer()
        performDisconnection()
    }
    
    /// 发送文本消息
    public func sendTextMessage(_ message: String) {
        guard isConnected else {
            delegate?.webSocketDidEncounterError(self, error: WebSocketError.notConnected)
            return
        }
        
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error, let self = self {
                DispatchQueue.main.async {
                    self.delegate?.webSocketDidEncounterError(self, error: error)
                }
            }
        }
    }
    
    /// 发送二进制数据
    public func sendData(_ data: Data) {
        guard isConnected else {
            delegate?.webSocketDidEncounterError(self, error: WebSocketError.notConnected)
            return
        }
        
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error, let self = self {
                DispatchQueue.main.async {
                    self.delegate?.webSocketDidEncounterError(self, error: error)
                }
            }
        }
    }
    
    /// 获取连接 URL
    public var connectionURL: String {
        return "ws://\(configuration.host):\(configuration.port)\(configuration.path)"
    }
    
    // MARK: - Private Methods
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeoutInterval
        urlSession = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: OperationQueue()
        )
    }
    
    private func performConnection() {
        guard let url = URL(string: connectionURL) else {
            updateConnectionStatus(false, "URL无效")
            delegate?.webSocketDidEncounterError(self, error: WebSocketError.invalidURL)
            return
        }
        
        // 先断开现有连接
        performDisconnection()
        
        // 创建新连接
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        updateConnectionStatus(false, "连接中...")
        startReceiving()
    }
    
    private func performDisconnection() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        updateConnectionStatus(false, "未连接")
    }
    
    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                DispatchQueue.main.async {
                    switch message {
                    case .data(let data):
                        self.delegate?.webSocketDidReceiveData(self, data: data)
                    case .string(let text):
                        self.delegate?.webSocketDidReceiveTextMessage(self, message: text)
                    @unknown default:
                        break
                    }
                }
                // 继续监听下一条消息
                self.startReceiving()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.handleConnectionError(error)
                }
            }
        }
    }
    
    private func updateConnectionStatus(_ isConnected: Bool, _ status: String) {
        DispatchQueue.main.async {
            self.isConnected = isConnected
            self.connectionStatus = status
            self.delegate?.webSocketDidChangeConnectionStatus(self, isConnected: isConnected, status: status)
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        updateConnectionStatus(false, "连接错误")
        delegate?.webSocketDidEncounterError(self, error: error)
        
        // 尝试重连
        if !isManualDisconnect && reconnectAttempts < configuration.maxReconnectAttempts {
            scheduleReconnect()
        }
    }
    
    private func scheduleReconnect() {
        cancelReconnectTimer()
        reconnectAttempts += 1
        
        let delay = configuration.reconnectInterval * Double(reconnectAttempts)
        updateConnectionStatus(false, "重连中... (\(reconnectAttempts)/\(configuration.maxReconnectAttempts))")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performConnection()
        }
    }
    
    private func cancelReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketModule: URLSessionWebSocketDelegate {
    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        reconnectAttempts = 0
        updateConnectionStatus(true, "已连接")
    }
    
    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        updateConnectionStatus(false, "连接关闭")
        
        // 如果不是手动断开，尝试重连
        if !isManualDisconnect {
            scheduleReconnect()
        }
    }
}

// MARK: - WebSocket 错误类型
public enum WebSocketError: Error, LocalizedError {
    case notConnected
    case invalidURL
    case connectionFailed(String)
    case sendMessageFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket 未连接"
        case .invalidURL:
            return "无效的 WebSocket URL"
        case .connectionFailed(let reason):
            return "连接失败: \(reason)"
        case .sendMessageFailed(let reason):
            return "发送消息失败: \(reason)"
        }
    }
}