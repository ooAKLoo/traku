//
//  EmbeddingData.swift
//  raku
//
//  Created by Assistant on Repository Pattern Refactor
//

import Foundation

// MARK: - 向量嵌入数据模型
struct EmbeddingData: Identifiable, Codable, DatabaseModel {
    typealias ID = Int64
    var id: Int64
    let recordingId: String
    let embeddingType: String
    let embeddingVector: [Float]
    let createdAt: Date
    
    init(id: Int64 = 0,
         recordingId: String,
         embeddingType: String,
         embeddingVector: [Float],
         createdAt: Date = Date()) {
        self.id = id
        self.recordingId = recordingId
        self.embeddingType = embeddingType
        self.embeddingVector = embeddingVector
        self.createdAt = createdAt
    }
    
    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case id
        case recordingId = "recording_id"
        case embeddingType = "embedding_type"
        case embeddingVector = "embedding_vector"
        case createdAt = "created_at"
    }
    
    // MARK: - DatabaseModel Protocol Implementation
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if id > 0 {
            dict["id"] = id
        }
        dict["recording_id"] = recordingId
        dict["embedding_type"] = embeddingType
        dict["created_at"] = createdAt.timeIntervalSince1970
        
        // 序列化 embeddingVector 为 JSON 字符串
        if let vectorData = try? JSONEncoder().encode(embeddingVector),
           let vectorString = String(data: vectorData, encoding: .utf8) {
            dict["embedding_vector"] = vectorString
        } else {
            dict["embedding_vector"] = "[]"
        }
        
        return dict
    }
    
    static func fromDict(_ dict: [String: Any]) -> EmbeddingData? {
        guard let recordingId = dict["recording_id"] as? String,
              let embeddingType = dict["embedding_type"] as? String else {
            return nil
        }
        
        let id = dict["id"] as? Int64 ?? 0
        let createdAtInterval = dict["created_at"] as? Double ?? Date().timeIntervalSince1970
        let createdAt = Date(timeIntervalSince1970: createdAtInterval)
        
        // 反序列化 embeddingVector
        var embeddingVector: [Float] = []
        if let vectorString = dict["embedding_vector"] as? String,
           let vectorData = vectorString.data(using: .utf8) {
            embeddingVector = (try? JSONDecoder().decode([Float].self, from: vectorData)) ?? []
        }
        
        return EmbeddingData(
            id: id,
            recordingId: recordingId,
            embeddingType: embeddingType,
            embeddingVector: embeddingVector,
            createdAt: createdAt
        )
    }
}