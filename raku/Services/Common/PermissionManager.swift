//
//  PermissionManager.swift
//  权限管理器 - 在应用启动时主动申请所需权限
//

import Foundation
import AVFoundation
import Network
import UIKit
import CoreLocation

/// 权限管理器 - 统一处理应用所需的各种权限
class PermissionManager: NSObject, ObservableObject {
    
    static let shared = PermissionManager()
    
    @Published var microphonePermissionStatus: AVAudioSession.RecordPermission = .undetermined
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var networkPermissionStatus: NetworkPermissionStatus = .unknown
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private let locationManager = CLLocationManager()
    
    enum NetworkPermissionStatus {
        case unknown
        case available
        case unavailable
        case restricted
    }
    
    private override init() {
        super.init()
        locationManager.delegate = self
        checkCurrentPermissions()
    }
    
    // MARK: - Public Methods
    
    /// 在应用启动时请求所有必要权限
    func requestAllPermissions() {
        print("🔐 PermissionManager: 开始申请应用所需权限...")
        
        // 请求麦克风权限
        requestMicrophonePermission { [weak self] granted in
            print("🎤 麦克风权限申请结果: \(granted ? "已授权" : "被拒绝")")
            DispatchQueue.main.async {
                self?.microphonePermissionStatus = AVAudioSession.sharedInstance().recordPermission
            }
        }
        
        // 请求位置权限
        requestLocationPermission()
        
        // 检查网络权限
        checkNetworkPermission()
    }
    
    /// 检查当前权限状态
    func checkCurrentPermissions() {
        // 检查麦克风权限
        microphonePermissionStatus = AVAudioSession.sharedInstance().recordPermission
        
        // 检查位置权限
        locationPermissionStatus = locationManager.authorizationStatus
        
        // 检查网络权限
        checkNetworkPermission()
    }
    
    /// 请求麦克风权限
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let currentStatus = AVAudioSession.sharedInstance().recordPermission
        
        switch currentStatus {
        case .granted:
            print("✅ 麦克风权限已授权")
            completion(true)
            
        case .denied:
            print("❌ 麦克风权限被拒绝")
            completion(false)
            
        case .undetermined:
            print("🔔 主动请求麦克风权限")
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    print(granted ? "✅ 用户授权麦克风权限" : "❌ 用户拒绝麦克风权限")
                    completion(granted)
                }
            }
            
        @unknown default:
            print("⚠️ 未知的麦克风权限状态")
            completion(false)
        }
    }
    
    /// 请求位置权限
    func requestLocationPermission() {
        let currentStatus = locationManager.authorizationStatus
        
        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ 位置权限已授权")
            
        case .denied, .restricted:
            print("❌ 位置权限被拒绝或受限")
            
        case .notDetermined:
            print("🔔 主动请求位置权限")
            locationManager.requestWhenInUseAuthorization()
            
        @unknown default:
            print("⚠️ 未知的位置权限状态")
        }
    }
    
    /// 检查网络权限
    private func checkNetworkPermission() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                switch path.status {
                case .satisfied:
                    self?.networkPermissionStatus = .available
                    print("🌐 网络连接可用")
                    
                case .unsatisfied:
                    self?.networkPermissionStatus = .unavailable
                    print("❌ 网络连接不可用")
                    
                case .requiresConnection:
                    self?.networkPermissionStatus = .restricted
                    print("⚠️ 网络连接受限")
                    
                @unknown default:
                    self?.networkPermissionStatus = .unknown
                    print("⚠️ 未知的网络状态")
                }
            }
        }
        
        networkMonitor.start(queue: monitorQueue)
    }
    
    /// 获取权限状态描述
    func getPermissionStatusDescription() -> String {
        var status = "权限状态:\n"
        
        // 麦克风权限
        switch microphonePermissionStatus {
        case .granted:
            status += "🎤 麦克风: 已授权\n"
        case .denied:
            status += "❌ 麦克风: 被拒绝\n"
        case .undetermined:
            status += "🔔 麦克风: 未确定\n"
        @unknown default:
            status += "⚠️ 麦克风: 未知状态\n"
        }
        
        // 位置权限
        switch locationPermissionStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            status += "📍 位置: 已授权\n"
        case .denied, .restricted:
            status += "❌ 位置: 被拒绝\n"
        case .notDetermined:
            status += "🔔 位置: 未确定\n"
        @unknown default:
            status += "⚠️ 位置: 未知状态\n"
        }
        
        // 网络权限
        switch networkPermissionStatus {
        case .available:
            status += "🌐 网络: 可用"
        case .unavailable:
            status += "❌ 网络: 不可用"
        case .restricted:
            status += "⚠️ 网络: 受限"
        case .unknown:
            status += "❓ 网络: 未知"
        }
        
        return status
    }
    
    /// 引导用户到设置页面
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    /// 检查是否所有必要权限都已获得
    var hasAllRequiredPermissions: Bool {
        return microphonePermissionStatus == .granted && 
               hasLocationPermission &&
               networkPermissionStatus == .available
    }
    
    /// 检查是否有位置权限
    var hasLocationPermission: Bool {
        return locationPermissionStatus == .authorizedWhenInUse || 
               locationPermissionStatus == .authorizedAlways
    }
    
    /// 检查是否可以开始录音
    var canStartRecording: Bool {
        return microphonePermissionStatus == .granted
    }
    
    /// 检查是否可以进行网络请求
    var canMakeNetworkRequests: Bool {
        return networkPermissionStatus == .available
    }
    
    deinit {
        networkMonitor.cancel()
    }
}

// MARK: - Permission Status Extensions

extension PermissionManager {
    
    /// 显示权限请求说明
    func showPermissionRationale() -> String {
        return """
        为了提供完整的功能体验，此应用需要以下权限：
        
        🎤 麦克风权限
        - 用于录制您的语音内容
        - 进行语音识别和AI分析
        
        📍 位置权限
        - 用于获取天气信息
        - 为您的录音添加位置和天气上下文
        
        🌐 网络权限  
        - 用于语音识别服务
        - 进行AI内容分析
        - 获取天气信息
        - 同步和备份数据
        
        您可以随时在设置中更改这些权限。
        """
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.locationPermissionStatus = status
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ 位置权限已授权: \(status)")
        case .denied:
            print("❌ 位置权限被用户拒绝")
        case .restricted:
            print("❌ 位置权限受限")
        case .notDetermined:
            print("🔔 位置权限未确定")
        @unknown default:
            print("⚠️ 未知的位置权限状态: \(status)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 位置服务错误: \(error.localizedDescription)")
    }
}