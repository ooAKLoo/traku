//
//  SystemInfoService.swift
//  raku
//
//  系统信息服务 - 提供位置、语言、地理位置判断等系统信息
//  位置服务：仅在应用启动时获取一次，节省电量
//

import Foundation
import CoreLocation
import UIKit

// MARK: - 系统信息数据模型

/// 位置信息
struct LocationInfo {
    let latitude: Double
    let longitude: Double
    let country: String?
    let countryCode: String?
    let city: String?
    let address: String?
    let timestamp: Date
    
    init(coordinate: CLLocationCoordinate2D, placemark: CLPlacemark? = nil) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.country = placemark?.country
        self.countryCode = placemark?.isoCountryCode  // 使用正确的属性名
        self.city = placemark?.locality
        self.address = placemark?.name
        self.timestamp = Date()
    }
}

/// 语言信息
struct LanguageInfo {
    let currentLanguage: String          // 当前应用语言
    let systemLanguage: String           // 系统首选语言
    let systemLanguages: [String]        // 系统所有语言偏好
    let localeIdentifier: String         // 区域标识符
    let countryCode: String?            // 国家代码
    let displayName: String             // 语言显示名称
    
    init() {
        self.systemLanguages = Locale.preferredLanguages
        self.systemLanguage = systemLanguages.first ?? "en"
        self.currentLanguage = Locale.current.languageCode ?? "en"
        self.localeIdentifier = Locale.current.identifier
        self.countryCode = Locale.current.regionCode
        
        let locale = Locale.current
        self.displayName = locale.localizedString(forLanguageCode: currentLanguage) ?? currentLanguage
    }
}

/// 地理位置状态
enum LocationAuthorizationStatus {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    case authorizedAlways
    case unknown
    
    init(from status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .authorizedWhenInUse:
            self = .authorizedWhenInUse
        case .authorizedAlways:
            self = .authorizedAlways
        @unknown default:
            self = .unknown
        }
    }
}

// MARK: - 系统信息服务协议

protocol SystemInfoServiceDelegate: AnyObject {
    func systemInfoService(_ service: SystemInfoService, didUpdateLocation location: LocationInfo)
    func systemInfoService(_ service: SystemInfoService, didFailToGetLocationWithError error: Error)
    func systemInfoService(_ service: SystemInfoService, didChangeAuthorizationStatus status: LocationAuthorizationStatus)
}

// MARK: - 系统信息服务

class SystemInfoService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = SystemInfoService()
    
    // MARK: - Published Properties
    @Published var currentLocation: LocationInfo?
    @Published var languageInfo: LanguageInfo
    @Published var authorizationStatus: LocationAuthorizationStatus = .notDetermined
    @Published var isInMainlandChina: Bool = false
    
    // MARK: - Private Properties
    private let locationManager: CLLocationManager
    private let geocoder: CLGeocoder
    private var hasRequestedLocationOnce: Bool = false  // 标记是否已经请求过位置
    
    // MARK: - Delegate
    weak var delegate: SystemInfoServiceDelegate?
    
    // MARK: - Initialization
    private override init() {
        self.locationManager = CLLocationManager()
        self.geocoder = CLGeocoder()
        self.languageInfo = LanguageInfo()
        
        super.init()
        
        setupLocationManager()
        updateLocationAuthorizationStatus()
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Methods
    
    /// 请求位置权限
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // 引导用户到设置页面
            openLocationSettings()
        case .authorizedWhenInUse, .authorizedAlways:
            requestLocationOnce()
        case .unknown:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    /// 获取位置（仅在应用启动时执行一次）
    func requestLocationOnce() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        // 如果已经获取过位置，直接返回
        if hasRequestedLocationOnce && currentLocation != nil {
            return
        }
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestLocation()  // 一次性请求，不持续更新
            hasRequestedLocationOnce = true
        }
    }
    
    /// 停止获取位置
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    /// 强制重新获取位置（忽略缓存）
    func forceUpdateLocation() {
        hasRequestedLocationOnce = false
        currentLocation = nil
        requestLocationOnce()
    }
    
    /// 判断是否在中国大陆
    func checkIfInMainlandChina() -> Bool {
        // 基于系统区域设置判断
        if let countryCode = Locale.current.regionCode {
            return countryCode == "CN"
        }
        
        // 基于位置判断
        if let location = currentLocation {
            return isCoordinateInMainlandChina(latitude: location.latitude, longitude: location.longitude)
        }
        
        return false
    }
    
    /// 获取当前语言信息
    func getCurrentLanguageInfo() -> LanguageInfo {
        return LanguageInfo()
    }
    
    /// 获取系统信息摘要
    func getSystemInfoSummary() -> [String: Any] {
        var summary: [String: Any] = [:]
        
        // 语言信息
        summary["language"] = languageInfo.currentLanguage
        summary["systemLanguage"] = languageInfo.systemLanguage
        summary["locale"] = languageInfo.localeIdentifier
        summary["countryCode"] = languageInfo.countryCode
        
        // 位置信息
        if let location = currentLocation {
            summary["location"] = [
                "latitude": location.latitude,
                "longitude": location.longitude,
                "country": location.country,
                "countryCode": location.countryCode,
                "city": location.city
            ]
        }
        
        // 地理判断
        summary["isInMainlandChina"] = checkIfInMainlandChina()
        summary["locationStatus"] = authorizationStatusString()
        
        // 设备信息
        summary["deviceModel"] = UIDevice.current.model
        summary["systemVersion"] = UIDevice.current.systemVersion
        summary["appLanguage"] = Bundle.main.preferredLocalizations.first
        
        return summary
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters  // 降低精度，节省电量
    }
    
    private func updateLocationAuthorizationStatus() {
        let status = LocationAuthorizationStatus(from: locationManager.authorizationStatus)
        
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        delegate?.systemInfoService(self, didChangeAuthorizationStatus: status)
    }
    
    private func processLocation(_ location: CLLocation) {
        // 反地理编码获取地址信息
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            let locationInfo = LocationInfo(
                coordinate: location.coordinate,
                placemark: placemarks?.first
            )
            
            DispatchQueue.main.async {
                self.currentLocation = locationInfo
                self.isInMainlandChina = self.checkIfInMainlandChina()
            }
            
            self.delegate?.systemInfoService(self, didUpdateLocation: locationInfo)
        }
    }
    
    /// 判断坐标是否在中国大陆范围内
    private func isCoordinateInMainlandChina(latitude: Double, longitude: Double) -> Bool {
        // 中国大陆边界坐标范围（粗略）
        let minLatitude = 18.0    // 南海诸岛
        let maxLatitude = 53.5    // 黑龙江北部
        let minLongitude = 73.5   // 新疆西部
        let maxLongitude = 135.0  // 黑龙江东部
        
        return latitude >= minLatitude && 
               latitude <= maxLatitude && 
               longitude >= minLongitude && 
               longitude <= maxLongitude
    }
    
    private func authorizationStatusString() -> String {
        switch authorizationStatus {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        case .authorizedAlways:
            return "authorizedAlways"
        case .unknown:
            return "unknown"
        }
    }
    
    private func openLocationSettings() {
        DispatchQueue.main.async {
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }
    }
    
    @objc private func languageDidChange() {
        DispatchQueue.main.async {
            self.languageInfo = LanguageInfo()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension SystemInfoService: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 过滤无效位置
        if location.horizontalAccuracy < 0 || location.horizontalAccuracy > 100 {
            return
        }
        
        processLocation(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置获取失败: \(error.localizedDescription)")
        delegate?.systemInfoService(self, didFailToGetLocationWithError: error)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        updateLocationAuthorizationStatus()
        
        // 如果获得授权，自动获取一次位置
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            requestLocationOnce()
        }
    }
}

// MARK: - 便利扩展

extension SystemInfoService {
    
    /// 是否支持中文
    var isChineseLanguageEnvironment: Bool {
        return languageInfo.currentLanguage.hasPrefix("zh") || 
               languageInfo.systemLanguage.hasPrefix("zh")
    }
    
    /// 获取当前国家代码
    var currentCountryCode: String? {
        return currentLocation?.countryCode ?? languageInfo.countryCode
    }
    
    /// 是否有位置权限
    var hasLocationPermission: Bool {
        return authorizationStatus == .authorizedWhenInUse || 
               authorizationStatus == .authorizedAlways
    }
    
    /// 格式化的位置描述
    var locationDescription: String? {
        guard let location = currentLocation else { return nil }
        
        var components: [String] = []
        
        if let city = location.city {
            components.append(city)
        }
        
        if let country = location.country {
            components.append(country)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}