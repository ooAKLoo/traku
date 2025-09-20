//
//  RecordingWeatherManager.swift
//  raku
//
//  Created by Claude on 2025/9/19.
//  录音天气管理器 - 负责在录音创建时自动获取和设置天气信息
//

import Foundation

// MARK: - 录音天气管理器
class RecordingWeatherManager {
    static let shared = RecordingWeatherManager()
    
    private let weatherService: WeatherService
    private let databaseManager: DatabaseManager
    
    private init() {
        self.weatherService = WeatherService.shared
        self.databaseManager = DatabaseManager.shared
    }
    
    // MARK: - 为录音设置天气信息
    
    /// 为新录音自动获取并设置天气信息
    @MainActor
    func setWeatherForNewRecording(_ recording: inout AudioRecording) async {
        // 如果录音已经有天气信息，跳过
        if recording.weatherType != nil {
            return
        }
        
        do {
            // 获取当前天气
            let weatherData = try await weatherService.getCurrentWeather()
            recording.setWeather(weatherData)
            
            // 缓存天气数据
            weatherService.cacheWeatherData(weatherData, for: recording.id.uuidString)
            
            print("✅ 已为录音设置天气: \(weatherData.type.displayName) @ \(weatherData.location)")
        } catch {
            // 获取失败，设置默认天气
            recording.weather = .sunny
            recording.weatherLocation = "位置未知"
            print("❌ [RecordingWeatherManager] 天气获取失败，使用默认天气: \(error.localizedDescription)")
        }
    }
    
    /// 为现有录音批量更新天气信息
    func updateWeatherForExistingRecordings() async {
        do {
            // 获取所有没有天气信息的录音
            let recordings = try await databaseManager.recordingRepository.list()
            let recordingsWithoutWeather = recordings.filter { $0.weatherType == nil }
            
            print("🌤️ 发现 \(recordingsWithoutWeather.count) 条录音需要更新天气信息")
            
            for var recording in recordingsWithoutWeather {
                // 为每条录音设置天气
                await setWeatherForNewRecording(&recording)
                
                // 更新数据库
                try await databaseManager.recordingRepository.update(recording)
                
                // 避免过于频繁的API调用
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
            
            print("✅ 完成天气信息批量更新")
        } catch {
            print("❌ 批量更新天气信息失败: \(error.localizedDescription)")
        }
    }
    
    /// 刷新指定录音的天气信息
    func refreshWeatherForRecording(_ recordingId: UUID) async -> Bool {
        do {
            guard var recording = try await databaseManager.recordingRepository.read(id: recordingId) else {
                print("❌ 录音不存在: \(recordingId)")
                return false
            }
            
            // 获取当前天气
            let weatherData = try await weatherService.getCurrentWeather()
            recording.setWeather(weatherData)
            
            // 更新数据库
            let success = try await databaseManager.recordingRepository.update(recording)
            
            if success {
                // 更新缓存
                weatherService.cacheWeatherData(weatherData, for: recordingId.uuidString)
                print("✅ 已刷新录音天气信息: \(weatherData.type.displayName)")
            }
            
            return success
        } catch {
            print("❌ 刷新录音天气信息失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 获取录音的天气信息（优先使用缓存）
    func getWeatherForRecording(_ recordingId: UUID) async -> WeatherData? {
        // 先尝试从数据库获取
        do {
            if let recording = try await databaseManager.recordingRepository.read(id: recordingId),
               let weatherData = recording.getWeatherData() {
                return weatherData
            }
        } catch {
            print("❌ 从数据库获取天气信息失败: \(error.localizedDescription)")
        }
        
        // 从缓存获取
        if let cachedWeather = weatherService.getCachedWeatherData(for: recordingId.uuidString) {
            return cachedWeather
        }
        
        // 都没有，获取当前天气
        do {
            let weatherData = try await weatherService.getCurrentWeather()
            weatherService.cacheWeatherData(weatherData, for: recordingId.uuidString)
            return weatherData
        } catch {
            print("❌ 获取当前天气失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 天气统计
    
    /// 获取录音天气统计信息
    func getWeatherStatistics() async -> [WeatherType: Int] {
        do {
            let recordings = try await databaseManager.recordingRepository.list()
            var statistics: [WeatherType: Int] = [:]
            
            for recording in recordings {
                if let weather = recording.weather {
                    statistics[weather, default: 0] += 1
                }
            }
            
            return statistics
        } catch {
            print("❌ 获取天气统计失败: \(error.localizedDescription)")
            return [:]
        }
    }
    
    /// 获取指定时间段的天气趋势
    func getWeatherTrend(from startDate: Date, to endDate: Date) async -> [(Date, WeatherType)] {
        do {
            let recordings = try await databaseManager.recordingRepository.list()
            
            return recordings
                .filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
                .compactMap { recording in
                    guard let weather = recording.weather else { return nil }
                    return (recording.timestamp, weather)
                }
                .sorted { $0.0 < $1.0 }
        } catch {
            print("❌ 获取天气趋势失败: \(error.localizedDescription)")
            return []
        }
    }
}