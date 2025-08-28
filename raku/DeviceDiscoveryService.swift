//
//  DeviceDiscoveryService.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//


import SwiftUI
import AVFoundation
import Network
import Combine

// MARK: - 设备发现服务
import SwiftUI
import Network
import Combine
import Foundation

// MARK: - 设备发现服务（修复版）
class DeviceDiscoveryService: ObservableObject {
    @Published var discoveredDevices: [DiscoveredDevice] = []
    
    private var browser: NWBrowser?
    private var udpListener: NWListener?
    private let queue = DispatchQueue(label: "com.app.discovery")
    private var scanTimer: Timer?
    
    struct DiscoveredDevice: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let ipAddress: String
        let port: Int
        let statusPort: Int
        var isStreaming: Bool = false
        
        var displayName: String {
            return "\(name) (\(ipAddress))"
        }
        
        static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
            return lhs.ipAddress == rhs.ipAddress && lhs.port == rhs.port
        }
    }
    
    init() {
        startDiscovery()
        // 添加一些模拟设备用于测试
        addMockDevices()
    }
    
    // 添加模拟设备数据
    private func addMockDevices() {
        let mockDevices = [
            DiscoveredDevice(
                name: "ESP32-音频设备-1",
                ipAddress: "192.168.1.100",
                port: 8888,
                statusPort: 8889,
                isStreaming: false
            ),
            DiscoveredDevice(
                name: "ESP32-会议室",
                ipAddress: "192.168.1.101", 
                port: 8888,
                statusPort: 8889,
                isStreaming: true
            ),
            DiscoveredDevice(
                name: "ESP32-办公室",
                ipAddress: "192.168.1.102",
                port: 8888,
                statusPort: 8889,
                isStreaming: false
            )
        ]
        
        DispatchQueue.main.async {
            self.discoveredDevices = mockDevices
        }
    }
    
    func startDiscovery() {
        // 1. 启动Bonjour浏览器
        startBonjourBrowser()
        
        // 2. 启动UDP监听器（接收广播）
        startUDPListener()
        
        // 3. 主动扫描网络
        startNetworkScan()
    }
    
    private func startBonjourBrowser() {
        // 创建Bonjour浏览器参数
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        // 浏览 _esp32-audio._tcp 服务
        browser = NWBrowser(for: .bonjour(type: "_esp32-audio._tcp", domain: nil), using: parameters)
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                self?.processBonjourResults(results)
            }
        }
        
        browser?.start(queue: queue)
        print("Bonjour浏览器已启动")
    }
    
    private func processBonjourResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case let .service(name: serviceName, type: serviceType, domain: domain, interface: _) = result.endpoint {
                print("发现Bonjour服务: \(serviceName) 类型: \(serviceType)")
                
                // 尝试解析服务获取IP地址
                // 注意：Bonjour服务需要进一步解析才能获取IP地址
                // 这里简化处理，实际使用时可能需要DNS-SD解析
                
                // 创建一个模拟的设备条目
                let device = DiscoveredDevice(
                    name: "ESP32-Audio (Bonjour)",
                    ipAddress: "需要解析",
                    port: 8888,
                    statusPort: 8889,
                    isStreaming: false
                )
                
                updateDiscoveredDevice(device)
            }
        }
    }
    
    private func startUDPListener() {
        // 创建UDP监听参数
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        guard let port = NWEndpoint.Port(rawValue: 8890) else {
            print("无效的UDP端口")
            return
        }
        
        // 创建并启动监听器
        do {
            udpListener = try NWListener(using: parameters, on: port)
            
            udpListener?.newConnectionHandler = { [weak self] connection in
                self?.handleUDPConnection(connection)
            }
            
            udpListener?.start(queue: queue)
            print("UDP监听器已启动在端口8890")
        } catch {
            print("UDP监听器启动失败: \(error)")
        }
    }
    
    private func handleUDPConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        // 接收UDP数据
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let data = data, !data.isEmpty {
                self?.parseUDPBroadcast(data)
            }
            
            if error == nil {
                // 继续接收下一个数据包
                self?.handleUDPConnection(connection)
            }
        }
    }
    
    private func parseUDPBroadcast(_ data: Data) {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            print("无法解析UDP数据")
            return
        }
        
        print("收到UDP广播: \(jsonString)")
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let type = json["type"] as? String,
               type == "esp32-audio-device" {
                
                let device = DiscoveredDevice(
                    name: json["name"] as? String ?? "ESP32设备",
                    ipAddress: json["ip"] as? String ?? "",
                    port: json["port"] as? Int ?? 8888,
                    statusPort: json["status_port"] as? Int ?? 8889,
                    isStreaming: json["streaming"] as? Bool ?? false
                )
                
                DispatchQueue.main.async {
                    self.updateDiscoveredDevice(device)
                }
            }
        } catch {
            print("JSON解析失败: \(error)")
        }
    }
    
    private func startNetworkScan() {
        // 定期扫描网络
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.scanLocalNetwork()
        }
        
        // 立即执行一次扫描
        scanLocalNetwork()
    }
    
    private func scanLocalNetwork() {
        guard let localIP = getLocalIPAddress() else {
            print("无法获取本地IP地址")
            return
        }
        
        print("本地IP: \(localIP)")
        
        // 解析IP地址获取网段
        let components = localIP.split(separator: ".")
        guard components.count == 4 else { return }
        
        let subnet = components[0...2].joined(separator: ".")
        
        // 扫描常见的ESP32 IP范围（限制范围以提高速度）
        let scanRanges = [
            1...10,    // 路由器通常分配的前几个地址
            30...40,   // 常见的DHCP范围
            100...110  // 另一个常见范围
        ]
        
        for range in scanRanges {
            for i in range {
                let targetIP = "\(subnet).\(i)"
                checkDeviceAt(ipAddress: targetIP)
            }
        }
    }
    
    private func checkDeviceAt(ipAddress: String) {
        // 尝试连接到设备的状态端口
        guard let url = URL(string: "http://\(ipAddress):8889/") else { return }
        
        // 创建短超时的请求
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0 // 1秒超时
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let deviceName = json["device"] as? String {
                    
                    let device = DiscoveredDevice(
                        name: deviceName,
                        ipAddress: ipAddress,
                        port: json["audio_port"] as? Int ?? 8888,
                        statusPort: 8889,
                        isStreaming: json["streaming"] as? Bool ?? false
                    )
                    
                    DispatchQueue.main.async {
                        self?.updateDiscoveredDevice(device)
                        print("发现设备通过HTTP: \(device.displayName)")
                    }
                }
            } catch {
                print("解析设备响应失败: \(error)")
            }
        }
        
        task.resume()
    }
    
    private func getLocalIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // 检查是否是IPv4地址
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                
                // 检查接口名称
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" || name == "en2" { // WiFi接口
                    
                    // 转换IP地址
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr,
                               socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname,
                               socklen_t(hostname.count),
                               nil,
                               socklen_t(0),
                               NI_NUMERICHOST)
                    
                    address = String(cString: hostname)
                    
                    // 过滤掉本地回环地址
                    if address != "127.0.0.1" {
                        break
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
    
    private func updateDiscoveredDevice(_ device: DiscoveredDevice) {
        // 检查设备是否已存在（通过IP地址判断）
        if let index = discoveredDevices.firstIndex(where: { $0.ipAddress == device.ipAddress }) {
            // 更新现有设备
            discoveredDevices[index] = device
        } else {
            // 添加新设备
            discoveredDevices.append(device)
            print("添加新设备: \(device.displayName)")
        }
    }
    
    func refreshDevices() {
        // 清空设备列表
        discoveredDevices.removeAll()
        
        // 重新开始发现
        startDiscovery()
    }
    
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        
        udpListener?.cancel()
        udpListener = nil
        
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    deinit {
        stopDiscovery()
    }
}

// MARK: - 简单的测试视图
struct DeviceDiscoveryTestView: View {
    @StateObject private var discovery = DeviceDiscoveryService()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("发现的设备 (\(discovery.discoveredDevices.count))")) {
                    if discovery.discoveredDevices.isEmpty {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("正在搜索设备...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(discovery.discoveredDevices) { device in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.headline)
                                Text("\(device.ipAddress):\(device.port)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if device.isStreaming {
                                    Text("正在传输")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("设备发现")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        discovery.refreshDevices()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            print("设备发现视图已加载")
        }
    }
}

// MARK: - 增强的音频管理器
class AudioManager: ObservableObject {
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var recordings: [AudioRecording] = []
    @Published var audioLevels: [Float] = []
    @Published var connectionStatus = "未连接"
    @Published var connectedDevice: DeviceDiscoveryService.DiscoveredDevice?
    
    private var tcpConnection: NWConnection?
    private var audioData = Data()
    private var recordingStartTime: Date?
    private let queue = DispatchQueue(label: "com.app.audio")
    private var audioPlayer: AVAudioPlayer?
    
    // 音频缓冲区
    private var audioBuffer = Data()
    private let bufferSize = 16000 * 2 // 1秒的音频数据（16kHz, 16bit）
    
    func connectToDevice(_ device: DeviceDiscoveryService.DiscoveredDevice) {
        disconnectFromDevice()
        
        connectionStatus = "正在连接到 \(device.name)..."
        
        guard let port = NWEndpoint.Port(rawValue: UInt16(device.port)) else {
            connectionStatus = "端口无效"
            return
        }
        
        let host = NWEndpoint.Host(device.ipAddress)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        
        let parameters = NWParameters.tcp
        parameters.acceptLocalOnly = false
        
        tcpConnection = NWConnection(to: endpoint, using: parameters)
        
        tcpConnection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectionState(state, device: device)
            }
        }
        
        tcpConnection?.start(queue: queue)
        
        // 开始接收数据
        receiveData()
    }
    
    private func handleConnectionState(_ state: NWConnection.State, device: DeviceDiscoveryService.DiscoveredDevice) {
        switch state {
        case .ready:
            print("已连接到设备: \(device.name)")
            isConnected = true
            connectedDevice = device
            connectionStatus = "已连接到 \(device.name)"
            
        case .failed(let error):
            print("连接失败: \(error)")
            isConnected = false
            connectedDevice = nil
            connectionStatus = "连接失败"
            
        case .cancelled:
            print("连接已取消")
            isConnected = false
            connectedDevice = nil
            connectionStatus = "未连接"
            
        case .waiting(let error):
            print("等待连接: \(error)")
            connectionStatus = "等待连接..."
            
        default:
            break
        }
    }
    
    private func receiveData() {
        tcpConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            if let error = error {
                print("接收错误: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionStatus = "连接断开"
                }
                return
            }
            
            if let data = data, !data.isEmpty {
                self?.processAudioData(data)
            }
            
            // 继续接收
            if self?.isConnected == true {
                self?.receiveData()
            }
        }
    }
    
    private func processAudioData(_ data: Data) {
        // 检查是否有数据包头
        guard data.count > 2 else { return }
        
        let packetSize = data.withUnsafeBytes { $0.load(as: UInt16.self) }.littleEndian
        
        // 验证包大小是否合理，防止算术溢出
        guard packetSize > 0 && packetSize <= 65535 else {
            print("无效的数据包大小: \(packetSize)")
            return
        }
        
        let totalExpectedSize = Int(packetSize) + 2
        guard data.count >= totalExpectedSize else {
            print("数据包不完整: 期望 \(totalExpectedSize) 字节，实际 \(data.count) 字节")
            return
        }
        
        let audioData = data.subdata(in: 2..<totalExpectedSize)
        audioBuffer.append(audioData)
        
        // 更新音频电平显示
        updateAudioLevels(from: audioData)
        
        // 如果正在录音，保存数据
        if isRecording {
            self.audioData.append(audioData)
        }
        
        // 缓冲区满了就播放（可选）
        if audioBuffer.count >= bufferSize {
            // playAudioBuffer()
            audioBuffer.removeAll()
        }
    }
    
    private func updateAudioLevels(from data: Data) {
        // 计算音频电平用于可视化
        let samples = data.withUnsafeBytes { buffer in
            buffer.bindMemory(to: Int16.self)
        }
        
        var levels: [Float] = []
        let step = max(1, samples.count / 50) // 显示50个电平条
        
        for i in stride(from: 0, to: samples.count, by: step) {
            let sample = Float(samples[i]) / Float(Int16.max)
            levels.append(abs(sample))
        }
        
        DispatchQueue.main.async {
            self.audioLevels = levels
        }
    }
    
    func startRecording() {
        guard isConnected else { return }
        
        isRecording = true
        audioData = Data()
        recordingStartTime = Date()
        
        print("开始录音")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        
        // 创建录音记录
        if let startTime = recordingStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let recording = AudioRecording(
                timestamp: startTime,
                duration: duration,
                transcription: "正在处理转写...",
                summary: "正在生成摘要...",
                tags: ["录音"],
                audioData: audioData
            )
            
            DispatchQueue.main.async {
                self.recordings.insert(recording, at: 0)
            }
            
            // 这里可以调用转写和摘要生成服务
            processRecording(recording)
        }
        
        audioLevels = []
        print("停止录音")
    }
    
    private func processRecording(_ recording: AudioRecording) {
        // TODO: 实现音频转写和摘要生成
        // 1. 将音频数据发送到转写服务
        // 2. 获取转写文本
        // 3. 生成摘要
        // 4. 更新录音记录
    }
    
    func disconnectFromDevice() {
        tcpConnection?.cancel()
        tcpConnection = nil
        isConnected = false
        connectedDevice = nil
        connectionStatus = "未连接"
    }
    
    // 加载测试数据
    func loadMockData() {
        recordings = [
            AudioRecording(
                timestamp: Date().addingTimeInterval(-7200), // 2小时前
                duration: 240,
                transcription: "本次技术讨论会议主要围绕系统架构的优化展开。团队成员提出了多个方案，包括微服务架构的改进、数据库性能优化以及前端渲染效率的提升。经过深入讨论，我们决定分阶段实施这些改进措施。",
                summary: "技术架构优化会议：确定了三个主要优化方向，预计可提升系统性能30%。",
                tags: ["技术", "架构", "优化"],
                audioData: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-3600), // 1小时前
                duration: 180,
                transcription: "今天的产品会议主要讨论了新功能的开发进度，产品经理介绍了用户反馈分析结果，设计团队展示了新UI原型，开发团队汇报了当前的技术挑战和解决方案。",
                summary: "产品会议总结：确定了Q2季度的产品路线图，重点关注用户体验改善。",
                tags: ["会议", "产品", "规划"],
                audioData: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-1800), // 30分钟前
                duration: 90,
                transcription: "客户电话会议记录：客户对我们最新版本的产品表示满意，特别赞赏了新增的数据分析功能。同时提出了一些定制化需求，希望能够在下个版本中考虑实现。",
                summary: "客户反馈积极，提出3个定制化需求，已记录并纳入需求池。",
                tags: ["客户", "反馈", "需求"],
                audioData: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-900), // 15分钟前
                duration: 60,
                transcription: "团队站会内容：前端完成了登录页面的重构，后端API接口开发进度达到80%，测试团队发现了2个中等严重程度的bug，已分配给相应开发人员修复。",
                summary: "日常站会：项目进度正常，需要关注2个bug的修复进度。",
                tags: ["站会", "进度", "bug"],
                audioData: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-300), // 5分钟前
                duration: 45,
                transcription: "个人备忘录：下周需要准备季度汇报材料，整理本季度的工作成果和下季度的工作计划。记得预约会议室，通知相关人员参会时间。",
                summary: "个人任务提醒：准备季度汇报，预约会议室。",
                tags: ["备忘", "计划", "个人"],
                audioData: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-86400), // 1天前
                duration: 300,
                transcription: "培训课程记录：今天参加了关于人工智能在软件开发中应用的培训。讲师详细介绍了AI辅助编程、自动化测试和智能代码审查等应用场景，并通过实际案例展示了AI工具的使用方法。",
                summary: "AI培训总结：学习了3种AI开发工具的使用，计划在项目中试用。",
                tags: ["培训", "AI", "学习"],
                audioData: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-172800), // 2天前
                duration: 120,
                transcription: "头脑风暴会议：团队围绕如何提升用户留存率展开讨论。提出了包括增加社交功能、优化新手引导、建立积分系统等多个创意方案。",
                summary: "创意会议：产出5个提升用户留存的方案，下周进行可行性评估。",
                tags: ["创意", "用户体验", "讨论"],
                audioData: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-259200), // 3天前
                duration: 150,
                transcription: "项目复盘会议：对刚刚上线的版本进行复盘。总结了项目中的成功经验，如敏捷开发流程的优化；也分析了遇到的问题，如需求变更频繁导致的进度延误。",
                summary: "项目复盘：总结3个成功经验和2个待改进点，形成最佳实践文档。",
                tags: ["复盘", "总结", "改进"],
                audioData: nil
            )
        ]
    }
}
