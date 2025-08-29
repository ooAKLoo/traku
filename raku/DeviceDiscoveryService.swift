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

