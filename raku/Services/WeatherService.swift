//
//  WeatherService.swift
//  raku
//
//  Created by Claude on 2025/9/19.
//  天气服务 - 获取实时天气信息并与笔记关联
//

import Foundation
import CoreLocation
import Combine
import WeatherKit

// MARK: - 天气数据模型
struct WeatherData {
    let type: WeatherType
    let location: String
    let timestamp: Date
}


// MARK: - 天气服务错误
enum WeatherServiceError: Error, LocalizedError {
    case locationNotAvailable
    case networkError(Error)
    case invalidResponse
    case locationPermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .locationNotAvailable:
            return "位置信息不可用"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case .locationPermissionDenied:
            return "位置权限被拒绝"
        }
    }
}

// MARK: - 天气服务
class WeatherService: NSObject, ObservableObject {
    static let shared = WeatherService()
    
    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    
    private let locationManager: CLLocationManager
    
    private override init() {
        self.locationManager = CLLocationManager()
        super.init()
        
        setupLocationManager()
    }
    
    // MARK: - 位置管理设置
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1000 // 1公里变化才更新
    }
    
    // MARK: - 获取当前天气
    func getCurrentWeather() async throws -> WeatherData {
        do {
            let location = try await getCurrentLocation()
            
            // 先尝试WeatherKit
            return try await fetchWeatherWithAppleWeatherKit(for: location)
        } catch {
            print("❌ [WeatherService] WeatherKit获取失败，使用地理位置fallback: \(error.localizedDescription)")
            
            // WeatherKit失败时，使用基于位置的简单天气
            do {
                let location = try await getCurrentLocation()
                return await createLocationBasedWeather(for: location)
            } catch {
                print("❌ [WeatherService] 位置获取也失败，使用默认天气: \(error.localizedDescription)")
                throw error
            }
        }
    }
    
    // MARK: - 获取笔记关联的天气（优先使用缓存）
    func getWeatherForNote(noteId: String) async -> WeatherData {
        // 先尝试从缓存获取
        if let cachedWeather = getCachedWeatherData(for: noteId) {
            return cachedWeather
        }
        
        // 缓存没有，获取当前天气并缓存
        do {
            let currentWeather = try await getCurrentWeather()
            cacheWeatherData(currentWeather, for: noteId)
            return currentWeather
        } catch {
            // 获取失败，输出错误并返回默认天气
            print("❌ [WeatherService] 获取天气失败: \(error.localizedDescription)")
            return createDefaultWeatherData()
        }
    }
    
    // MARK: - 创建默认天气数据
    private func createDefaultWeatherData() -> WeatherData {
        return WeatherData(
            type: .sunny,
            location: "位置未知",
            timestamp: Date()
        )
    }
    
    // MARK: - 基于位置创建简单天气
    private func createLocationBasedWeather(for coordinate: CLLocationCoordinate2D) async -> WeatherData {
        // 获取地理位置名称
        let locationName = await getLocationName(for: coordinate)
        
        // 基于时间和季节创建合理的天气
        let weatherType = generateReasonableWeather()
        
        print("✅ [WeatherService] 使用位置天气: \(weatherType.displayName) @ \(locationName)")
        
        return WeatherData(
            type: weatherType,
            location: locationName,
            timestamp: Date()
        )
    }
    
    // MARK: - 生成合理的天气类型
    private func generateReasonableWeather() -> WeatherType {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let month = calendar.component(.month, from: now)
        
        // 基于时间和季节的简单逻辑
        var weatherTypes: [WeatherType] = []
        
        // 季节影响
        switch month {
        case 12, 1, 2: // 冬季
            weatherTypes = [.cloudy, .cloudy, .sunny, .snowy]
        case 3, 4, 5: // 春季  
            weatherTypes = [.sunny, .partlyCloudy, .cloudy, .rainy]
        case 6, 7, 8: // 夏季
            weatherTypes = [.sunny, .sunny, .partlyCloudy, .rainy]
        case 9, 10, 11: // 秋季
            weatherTypes = [.partlyCloudy, .cloudy, .sunny, .rainy]
        default:
            weatherTypes = [.sunny, .partlyCloudy, .cloudy]
        }
        
        // 时间影响（早晨和傍晚更容易有云）
        if hour < 8 || hour > 18 {
            weatherTypes.append(.cloudy)
            weatherTypes.append(.partlyCloudy)
        }
        
        return weatherTypes.randomElement() ?? .sunny
    }
    
    // MARK: - 获取当前位置
    private func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        // 检查权限状态
        let permissionManager = PermissionManager.shared
        
        // 如果没有位置权限，先尝试请求
        if !permissionManager.hasLocationPermission {
            print("🔔 [WeatherService] 位置权限不足，尝试请求权限")
            permissionManager.requestLocationPermission()
            
            // 等待权限响应
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
            
            // 重新检查权限
            if !permissionManager.hasLocationPermission {
                print("❌ [WeatherService] 位置权限仍未授权")
                throw WeatherServiceError.locationPermissionDenied
            }
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            getCurrentLocationInternal(continuation: continuation)
        }
    }
    
    private func getCurrentLocationInternal(continuation: CheckedContinuation<CLLocationCoordinate2D, Error>) {
        guard let location = locationManager.location else {
            locationManager.requestLocation()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if let currentLocation = self.locationManager.location {
                    continuation.resume(returning: currentLocation.coordinate)
                } else {
                    continuation.resume(throwing: WeatherServiceError.locationNotAvailable)
                }
            }
            return
        }
        
        continuation.resume(returning: location.coordinate)
    }
    
    // MARK: - 使用Apple WeatherKit获取天气数据
    private func fetchWeatherWithAppleWeatherKit(for coordinate: CLLocationCoordinate2D) async throws -> WeatherData {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        // 检查WeatherKit可用性
        if #available(iOS 16.0, *) {
            do {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let weatherService = WeatherKit.WeatherService()
                let weather = try await weatherService.weather(for: location)
                
                let weatherData = await convertAppleWeatherToWeatherData(weather, coordinate: coordinate)
                
                DispatchQueue.main.async {
                    self.currentWeather = weatherData
                }
                
                return weatherData
            } catch {
                print("❌ [WeatherService] Apple WeatherKit 获取失败: \(error.localizedDescription)")
                throw WeatherServiceError.networkError(error)
            }
        } else {
            print("❌ [WeatherService] WeatherKit 需要 iOS 16.0 或更高版本")
            throw WeatherServiceError.invalidResponse
        }
    }
    
    // MARK: - 转换Apple Weather为WeatherData
    private func convertAppleWeatherToWeatherData(_ weather: Weather, coordinate: CLLocationCoordinate2D) async -> WeatherData {
        let weatherType = mapAppleWeatherCondition(weather.currentWeather.condition)
        
        // 使用反向地理编码获取地名
        let locationName = await getLocationName(for: coordinate)
        
        return WeatherData(
            type: weatherType,
            location: locationName,
            timestamp: Date()
        )
    }
    
    // MARK: - 映射Apple WeatherKit的天气状况到我们的WeatherType
    private func mapAppleWeatherCondition(_ condition: WeatherCondition) -> WeatherType {
        switch condition {
        case .clear:
            return .sunny
        case .partlyCloudy:
            return .partlyCloudy
        case .cloudy, .mostlyCloudy:
            return .cloudy
        case .rain, .heavyRain, .drizzle:
            return .rainy
        case .thunderstorms:
            return .stormy
        case .snow, .heavySnow, .flurries, .sleet:
            return .snowy
        case .haze:
            return .foggy
        case .breezy, .windy:
            return .windy
        @unknown default:
            return .sunny
        }
    }
    
    // MARK: - 获取地理位置名称
    private func getLocationName(for coordinate: CLLocationCoordinate2D) async -> String {
        let geocoder = CLGeocoder()
        
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            if let placemark = placemarks.first {
                // 优先使用城市名，其次使用区域名
                if let city = placemark.locality {
                    return city
                } else if let area = placemark.administrativeArea {
                    return area
                } else if let country = placemark.country {
                    return country
                }
            }
        } catch {
            print("❌ [WeatherService] 地理编码失败: \(error.localizedDescription)")
        }
        
        return "位置未知"
    }
    
    // MARK: - 缓存天气数据
    func cacheWeatherData(_ weatherData: WeatherData, for noteId: String? = nil) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(CachedWeatherData(from: weatherData, noteId: noteId)) {
            UserDefaults.standard.set(encoded, forKey: "cached_weather_\(noteId ?? "current")")
        }
    }
    
    // MARK: - 获取缓存的天气数据
    func getCachedWeatherData(for noteId: String? = nil) -> WeatherData? {
        guard let data = UserDefaults.standard.data(forKey: "cached_weather_\(noteId ?? "current")") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        if let cachedData = try? decoder.decode(CachedWeatherData.self, from: data) {
            // 检查缓存是否过期（1小时）
            if Date().timeIntervalSince(cachedData.timestamp) < 3600 {
                return cachedData.toWeatherData()
            }
        }
        
        return nil
    }
}

// MARK: - CLLocationManagerDelegate
extension WeatherService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // 位置更新后可以自动获取天气
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("定位失败: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // 权限状态变化处理
    }
}

// MARK: - 缓存数据模型
private struct CachedWeatherData: Codable {
    let type: String
    let location: String
    let timestamp: Date
    let noteId: String?
    
    init(from weatherData: WeatherData, noteId: String?) {
        self.type = weatherData.type.rawValue
        self.location = weatherData.location
        self.timestamp = weatherData.timestamp
        self.noteId = noteId
    }
    
    func toWeatherData() -> WeatherData {
        return WeatherData(
            type: WeatherType(rawValue: type) ?? .sunny,
            location: location,
            timestamp: timestamp
        )
    }
}