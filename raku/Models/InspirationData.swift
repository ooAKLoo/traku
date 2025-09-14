//
//  InspirationData.swift
//  raku
//
//  Created by Assistant on 2025/1/15.
//

import Foundation

// MARK: - 灵感数据模型
struct InspirationData: Identifiable, Codable, DatabaseModel {
    let id: String
    let originalText: String
    let polishedText: String
    let tags: [String]
    let createdAt: Date
    let audioData: Data?
    let embeddingVector: [Float]
    
    init(id: String? = nil,
         originalText: String,
         polishedText: String,
         tags: [String],
         createdAt: Date = Date(),
         audioData: Data? = nil,
         embeddingVector: [Float] = []) {
        self.id = id ?? UUID().uuidString
        self.originalText = originalText
        self.polishedText = polishedText
        self.tags = tags
        self.createdAt = createdAt
        self.audioData = audioData
        self.embeddingVector = embeddingVector
    }
    
    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case id
        case originalText = "original_text"
        case polishedText = "polished_text"
        case tags
        case createdAt = "created_at"
        case audioData = "audio_data"
        case embeddingVector = "embedding_vector"
    }
    
    // MARK: - DatabaseModel Protocol Implementation
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        dict["id"] = id
        dict["original_text"] = originalText
        dict["polished_text"] = polishedText
        dict["audio_data"] = audioData
        dict["created_at"] = createdAt.timeIntervalSince1970
        
        // 序列化 tags 和 embeddingVector 为 JSON 字符串
        if let tagsData = try? JSONEncoder().encode(tags),
           let tagsString = String(data: tagsData, encoding: .utf8) {
            dict["tags"] = tagsString
        } else {
            dict["tags"] = "[]"
        }
        
        if let vectorData = try? JSONEncoder().encode(embeddingVector),
           let vectorString = String(data: vectorData, encoding: .utf8) {
            dict["embedding_vector"] = vectorString
        } else {
            dict["embedding_vector"] = "[]"
        }
        
        return dict
    }
    
    static func fromDict(_ dict: [String: Any]) -> InspirationData? {
        guard let id = dict["id"] as? String,
              let originalText = dict["original_text"] as? String,
              let polishedText = dict["polished_text"] as? String else {
            return nil
        }
        
        let audioData = dict["audio_data"] as? Data
        
        let createdAtInterval = dict["created_at"] as? Double ?? Date().timeIntervalSince1970
        let createdAt = Date(timeIntervalSince1970: createdAtInterval)
        
        // 反序列化 tags
        var tags: [String] = []
        if let tagsString = dict["tags"] as? String,
           let tagsData = tagsString.data(using: .utf8) {
            tags = (try? JSONDecoder().decode([String].self, from: tagsData)) ?? []
        }
        
        // 反序列化 embeddingVector
        var embeddingVector: [Float] = []
        if let vectorString = dict["embedding_vector"] as? String,
           let vectorData = vectorString.data(using: .utf8) {
            embeddingVector = (try? JSONDecoder().decode([Float].self, from: vectorData)) ?? []
        }
        
        return InspirationData(
            id: id,
            originalText: originalText,
            polishedText: polishedText,
            tags: tags,
            createdAt: createdAt,
            audioData: audioData,
            embeddingVector: embeddingVector
        )
    }
}