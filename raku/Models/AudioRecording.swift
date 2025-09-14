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
    let audioData: Data?
    var isPlaying: Bool = false
    var enrichedContent: String?
    var polishedText: String = ""  // 润色后的文本，默认为空
    
    init(id: UUID? = nil, timestamp: Date, duration: TimeInterval, transcription: String, title: String, summary: String, tags: [String], audioData: Data?, enrichedContent: String?, polishedText: String = "") {
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
    }
    
    static func == (lhs: AudioRecording, rhs: AudioRecording) -> Bool {
        return lhs.id == rhs.id &&
               lhs.transcription == rhs.transcription &&
               lhs.title == rhs.title &&
               lhs.summary == rhs.summary &&
               lhs.tags == rhs.tags &&
               lhs.enrichedContent == rhs.enrichedContent &&
               lhs.polishedText == rhs.polishedText
    }
    
    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case id, timestamp, duration, transcription, title, summary, tags
        case audioData = "audio_data"
        case enrichedContent = "enriched_content"
        case polishedText = "polished_text"
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
        dict["audio_data"] = audioData
        dict["enriched_content"] = enrichedContent
        dict["polished_text"] = polishedText
        
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
        let audioData = dict["audio_data"] as? Data
        let enrichedContent = dict["enriched_content"] as? String
        let polishedText = dict["polished_text"] as? String ?? ""
        
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
            polishedText: polishedText
        )
    }
}