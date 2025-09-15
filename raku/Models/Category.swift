//
//  Category.swift
//  raku
//
//  Created by Assistant on 2025/9/15.
//

import Foundation

// MARK: - 类别数据模型
struct Category: Identifiable, Equatable, Codable, DatabaseModel {
    let id: UUID
    let spaceId: UUID
    let name: String
    
    init(id: UUID? = nil, spaceId: UUID, name: String) {
        self.id = id ?? UUID()
        self.spaceId = spaceId
        self.name = name
    }
    
    static func == (lhs: Category, rhs: Category) -> Bool {
        return lhs.id == rhs.id &&
               lhs.spaceId == rhs.spaceId &&
               lhs.name == rhs.name
    }
    
    // MARK: - Codable Support
    enum CodingKeys: String, CodingKey {
        case id = "category_id"
        case spaceId = "space_id"
        case name
    }
    
    // MARK: - DatabaseModel Protocol Implementation
    func toDict() -> [String: Any] {
        return [
            "category_id": id.uuidString,
            "space_id": spaceId.uuidString,
            "name": name
        ]
    }
    
    static func fromDict(_ dict: [String: Any]) -> Category? {
        guard let idString = dict["category_id"] as? String,
              let id = UUID(uuidString: idString),
              let spaceIdString = dict["space_id"] as? String,
              let spaceId = UUID(uuidString: spaceIdString),
              let name = dict["name"] as? String else {
            return nil
        }
        
        return Category(id: id, spaceId: spaceId, name: name)
    }
}