//
//  AudioRecording.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import Foundation

// MARK: - 录音数据模型
struct AudioRecording: Identifiable, Equatable, Codable, DatabaseModel {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let transcription: String
    var title: String
    let summary: String
    var tags: [String]
    var audioData: Data?
    var isPlaying: Bool = false
    
    // 方便的属性：从数据库获取完整录音数据（包含音频）
    var completeRecording: AudioRecording? {
        get {
            return DatabaseManager.shared.getCompleteRecording(by: id.uuidString)
        }
    }
    
    // 音频数据ID（引用recordings表中的原始音频数据）
    var audioDataId: UUID {
        get {
            return id // 当前使用recording的ID作为音频数据的ID
        }
    }
    var enrichedContent: String?
    var polishedText: String = ""  // 润色后的文本，默认为空
    var contentType: String = "thinking"  // 内容类型：thinking 或 inspiration
    var weatherType: String?  // 天气类型，存储WeatherType的rawValue
    var weatherLocation: String?  // 天气位置
    
    // 便捷访问天气类型枚举
    var weather: WeatherType? {
        get {
            guard let weatherType = weatherType else { return nil }
            return WeatherType(rawValue: weatherType)
        }
        set {
            weatherType = newValue?.rawValue
        }
    }
    
    // MARK: - 天气相关方法
    
    /// 设置天气信息
    mutating func setWeather(_ weatherData: WeatherData) {
        self.weather = weatherData.type
        self.weatherLocation = weatherData.location
    }
    
    /// 获取天气数据（如果有的话）
    func getWeatherData() -> WeatherData? {
        guard let weather = weather else { return nil }
        return WeatherData(
            type: weather,
            location: weatherLocation ?? "未知位置",
            timestamp: timestamp
        )
    }
    
    /// 异步获取或设置天气信息
    mutating func ensureWeatherInfo() async {
        // 如果已有天气信息，直接返回
        if weatherType != nil {
            return
        }
        
        // 获取当前天气
        do {
            let weatherData = try await WeatherService.shared.getWeatherForNote(noteId: id.uuidString)
            setWeather(weatherData)
        } catch {
            // 获取失败，设置默认天气
            self.weather = .sunny
            self.weatherLocation = "未知位置"
        }
    }
    
    init(id: UUID? = nil, timestamp: Date, duration: TimeInterval, transcription: String, title: String, summary: String, tags: [String], audioData: Data?, enrichedContent: String?, polishedText: String = "", contentType: String = "thinking", weatherType: String? = nil, weatherLocation: String? = nil) {
        self.id = id ?? UUID()
        self.timestamp = timestamp
        self.duration = duration
        self.transcription = transcription
        self.title = title
        self.summary = summary
        self.tags = tags
        self.audioData = audioData
        self.enrichedContent = enrichedContent
        self.polishedText = polishedText
        self.contentType = contentType
        self.weatherType = weatherType
        self.weatherLocation = weatherLocation
    }
    
    static func == (lhs: AudioRecording, rhs: AudioRecording) -> Bool {
        return lhs.id == rhs.id &&
               lhs.transcription == rhs.transcription &&
               lhs.title == rhs.title &&
               lhs.summary == rhs.summary &&
               lhs.tags == rhs.tags &&
               lhs.enrichedContent == rhs.enrichedContent &&
               lhs.polishedText == rhs.polishedText &&
               lhs.contentType == rhs.contentType &&
               lhs.weatherType == rhs.weatherType &&
               lhs.weatherLocation == rhs.weatherLocation
    }
    
    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case id, timestamp, duration, transcription, title, summary, tags
        case audioData = "audioData"
        case enrichedContent = "enriched_content"
        case polishedText = "polished_text"
        case contentType = "content_type"
        case weatherType = "weather_type"
        case weatherLocation = "weather_location"
    }
    
    // MARK: - DatabaseModel Protocol Implementation
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        dict["id"] = id.uuidString
        dict["timestamp"] = timestamp.timeIntervalSince1970
        dict["duration"] = duration
        dict["transcription"] = transcription
        dict["title"] = title
        dict["summary"] = summary
        dict["audioData"] = audioData
        dict["enriched_content"] = enrichedContent
        dict["polished_text"] = polishedText
        dict["content_type"] = contentType
        dict["weather_type"] = weatherType
        dict["weather_location"] = weatherLocation
        
        // 序列化 tags 为 JSON 字符串
        if let tagsData = try? JSONEncoder().encode(tags),
           let tagsString = String(data: tagsData, encoding: .utf8) {
            dict["tags"] = tagsString
        } else {
            dict["tags"] = "[]"
        }
        
        return dict
    }
    
    static func fromDict(_ dict: [String: Any]) -> AudioRecording? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let timestampInterval = dict["timestamp"] as? Double,
              let duration = dict["duration"] as? Double,
              let transcription = dict["transcription"] as? String,
              let title = dict["title"] as? String,
              let summary = dict["summary"] as? String else {
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: timestampInterval)
        let audioData = dict["audioData"] as? Data
        let enrichedContent = dict["enriched_content"] as? String
        let polishedText = dict["polished_text"] as? String ?? ""
        let contentType = dict["content_type"] as? String ?? "thinking"
        let weatherType = dict["weather_type"] as? String
        let weatherLocation = dict["weather_location"] as? String
        
        // 反序列化 tags
        var tags: [String] = []
        if let tagsString = dict["tags"] as? String,
           let tagsData = tagsString.data(using: .utf8) {
            tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        }
        
        return AudioRecording(
            id: id,
            timestamp: timestamp,
            duration: duration,
            transcription: transcription,
            title: title,
            summary: summary,
            tags: tags,
            audioData: audioData,
            enrichedContent: enrichedContent,
            polishedText: polishedText,
            contentType: contentType,
            weatherType: weatherType,
            weatherLocation: weatherLocation
        )
    }
}