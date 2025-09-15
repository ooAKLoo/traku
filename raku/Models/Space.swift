//
//  Space.swift
//  raku
//
//  Created by Assistant on 2025/9/15.
//

import Foundation

// MARK: - 空间数据模型
struct Space: Identifiable, Equatable, Codable, DatabaseModel {
    let id: UUID
    let name: String
    let description: String
    let createdAt: Date
    let updatedAt: Date
    
    init(id: UUID? = nil, name: String, description: String = "", createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id ?? UUID()
        self.name = name
        self.description = description
        self.createdAt = createdAt ?? Date()
        self.updatedAt = updatedAt ?? Date()
    }
    
    static func == (lhs: Space, rhs: Space) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.description == rhs.description
    }
    
    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - DatabaseModel Protocol Implementation
    func toDict() -> [String: Any] {
        return [
            "id": id.uuidString,
            "name": name,
            "description": description,
            "created_at": createdAt.timeIntervalSince1970,
            "updated_at": updatedAt.timeIntervalSince1970
        ]
    }
    
    static func fromDict(_ dict: [String: Any]) -> Space? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = dict["name"] as? String else {
            return nil
        }
        
        let description = dict["description"] as? String ?? ""
        let createdAtInterval = dict["created_at"] as? Double ?? Date().timeIntervalSince1970
        let updatedAtInterval = dict["updated_at"] as? Double ?? Date().timeIntervalSince1970
        
        return Space(
            id: id,
            name: name,
            description: description,
            createdAt: Date(timeIntervalSince1970: createdAtInterval),
            updatedAt: Date(timeIntervalSince1970: updatedAtInterval)
        )
    }
}