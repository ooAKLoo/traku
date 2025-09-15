//
//  SpaceArticle.swift
//  raku
//
//  Created by Assistant on 2025/9/15.
//

import Foundation

// MARK: - 空间-文章关系数据模型
struct SpaceArticle: Identifiable, Equatable, Codable, DatabaseModel {
    let id: UUID
    let spaceId: UUID
    let audioRecordingId: UUID
    let categoryId: UUID?  // 可选，如果不指定类别则为 nil
    let createdAt: Date
    var isMarkedImportant: Bool  // 用户标记重要
    
    init(id: UUID? = nil, spaceId: UUID, audioRecordingId: UUID, categoryId: UUID? = nil, createdAt: Date? = nil, isMarkedImportant: Bool = false) {
        self.id = id ?? UUID()
        self.spaceId = spaceId
        self.audioRecordingId = audioRecordingId
        self.categoryId = categoryId
        self.createdAt = createdAt ?? Date()
        self.isMarkedImportant = isMarkedImportant
    }
    
    static func == (lhs: SpaceArticle, rhs: SpaceArticle) -> Bool {
        return lhs.id == rhs.id &&
               lhs.spaceId == rhs.spaceId &&
               lhs.audioRecordingId == rhs.audioRecordingId &&
               lhs.categoryId == rhs.categoryId &&
               lhs.isMarkedImportant == rhs.isMarkedImportant
    }
    
    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case id
        case spaceId = "space_id"
        case audioRecordingId = "audio_recording_id"
        case categoryId = "category_id"
        case createdAt = "created_at"
        case isMarkedImportant = "is_marked_important"
    }
    
    // MARK: - DatabaseModel Protocol Implementation
    func toDict() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "space_id": spaceId.uuidString,
            "audio_recording_id": audioRecordingId.uuidString,
            "created_at": createdAt.timeIntervalSince1970,
            "is_marked_important": isMarkedImportant
        ]
        
        if let categoryId = categoryId {
            dict["category_id"] = categoryId.uuidString
        }
        
        return dict
    }
    
    static func fromDict(_ dict: [String: Any]) -> SpaceArticle? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let spaceIdString = dict["space_id"] as? String,
              let spaceId = UUID(uuidString: spaceIdString),
              let audioRecordingIdString = dict["audio_recording_id"] as? String,
              let audioRecordingId = UUID(uuidString: audioRecordingIdString) else {
            return nil
        }
        
        let categoryId: UUID? = {
            if let categoryIdString = dict["category_id"] as? String {
                return UUID(uuidString: categoryIdString)
            }
            return nil
        }()
        
        let createdAtInterval = dict["created_at"] as? Double ?? Date().timeIntervalSince1970
        let isMarkedImportant = dict["is_marked_important"] as? Bool ?? false
        
        return SpaceArticle(
            id: id,
            spaceId: spaceId,
            audioRecordingId: audioRecordingId,
            categoryId: categoryId,
            createdAt: Date(timeIntervalSince1970: createdAtInterval),
            isMarkedImportant: isMarkedImportant
        )
    }
}