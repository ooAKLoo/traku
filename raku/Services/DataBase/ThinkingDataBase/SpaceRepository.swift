//
//  SpaceRepository.swift
//  raku
//
//  Created by Assistant on 2025/9/15.
//

import Foundation
import SQLite3

/// Space Repository - 管理空间数据
class SpaceRepository: Repository {
    typealias Model = Space
    
    private let sqliteCore: SQLiteCore
    
    init(sqliteCore: SQLiteCore) {
        self.sqliteCore = sqliteCore
    }
    
    // MARK: - Table Management
    
    func createTable() async throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS spaces (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT DEFAULT '',
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
        """
        
        try await sqliteCore.execute(sql)
        print("✅ Spaces table created successfully")
    }
    
    // MARK: - CRUD Operations
    
    func create(_ space: Space) async throws -> Bool {
        let sql = """
            INSERT INTO spaces (id, name, description, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?)
        """
        
        let params: [Any] = [
            space.id.uuidString,
            space.name,
            space.description,
            space.createdAt.timeIntervalSince1970,
            space.updatedAt.timeIntervalSince1970
        ]
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: params)
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    func read(id: UUID) async throws -> Space? {
        let sql = "SELECT * FROM spaces WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return nil }
            
            let dict = self.extractSpaceDict(from: statement)
            return Space.fromDict(dict)
        }
    }
    
    func update(_ space: Space) async throws -> Bool {
        let updatedSpace = Space(
            id: space.id,
            name: space.name,
            description: space.description,
            createdAt: space.createdAt,
            updatedAt: Date()
        )
        
        let sql = """
            UPDATE spaces SET
                name = ?,
                description = ?,
                updated_at = ?
            WHERE id = ?
        """
        
        let params: [Any] = [
            updatedSpace.name,
            updatedSpace.description,
            updatedSpace.updatedAt.timeIntervalSince1970,
            updatedSpace.id.uuidString
        ]
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: params)
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    func delete(id: UUID) async throws -> Bool {
        // 先删除相关的类别和空间-文章关系
        let deleteCategoriesSql = "DELETE FROM categories WHERE space_id = ?"
        let deleteSpaceArticlesSql = "DELETE FROM space_articles WHERE space_id = ?"
        let deleteSpaceSql = "DELETE FROM spaces WHERE id = ?"
        
        let idString = id.uuidString
        
        try await sqliteCore.performAsync {
            // 使用事务确保数据一致性
            try self.sqliteCore.executeInternal("BEGIN TRANSACTION")
            
            do {
                // 删除类别
                let stmt1 = try self.sqliteCore.prepare(deleteCategoriesSql)
                defer { self.sqliteCore.finalize(stmt1) }
                try self.sqliteCore.bind(stmt1, parameters: [idString])
                _ = try self.sqliteCore.step(stmt1)
                
                // 删除空间-文章关系
                let stmt2 = try self.sqliteCore.prepare(deleteSpaceArticlesSql)
                defer { self.sqliteCore.finalize(stmt2) }
                try self.sqliteCore.bind(stmt2, parameters: [idString])
                _ = try self.sqliteCore.step(stmt2)
                
                // 删除空间
                let stmt3 = try self.sqliteCore.prepare(deleteSpaceSql)
                defer { self.sqliteCore.finalize(stmt3) }
                try self.sqliteCore.bind(stmt3, parameters: [idString])
                _ = try self.sqliteCore.step(stmt3)
                
                try self.sqliteCore.executeInternal("COMMIT")
            } catch {
                try self.sqliteCore.executeInternal("ROLLBACK")
                throw error
            }
        }
        return true
    }
    
    func saveOrUpdate(_ space: Space) async throws -> Bool {
        // Check if space exists
        if let _ = try await read(id: space.id) {
            return try await update(space)
        } else {
            return try await create(space)
        }
    }
    
    func list(filter: FilterCriteria? = nil) async throws -> [Space] {
        return try await listWithParams(limit: filter?.limit, offset: filter?.offset)
    }
    
    private func listWithParams(limit: Int? = nil, offset: Int? = nil) async throws -> [Space] {
        var sql = "SELECT * FROM spaces ORDER BY updated_at DESC"
        var params: [Any] = []
        
        if let limit = limit {
            sql += " LIMIT ?"
            params.append(limit)
            
            if let offset = offset {
                sql += " OFFSET ?"
                params.append(offset)
            }
        }
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            if !params.isEmpty {
                try self.sqliteCore.bind(statement, parameters: params)
            }
            
            var spaces: [Space] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractSpaceDict(from: statement)
                if let space = Space.fromDict(dict) {
                    spaces.append(space)
                }
            }
            return spaces
        }
    }
    
    func count() async throws -> Int {
        let sql = "SELECT COUNT(*) as count FROM spaces"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return 0 }
            
            return Int(sqlite3_column_int(statement, 0))
        }
    }
    
    // MARK: - Space-Specific Operations
    
    /// 根据名称搜索空间
    func searchByName(_ name: String) async throws -> [Space] {
        let sql = "SELECT * FROM spaces WHERE name LIKE ? ORDER BY updated_at DESC"
        let searchPattern = "%\(name)%"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [searchPattern])
            
            var spaces: [Space] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractSpaceDict(from: statement)
                if let space = Space.fromDict(dict) {
                    spaces.append(space)
                }
            }
            return spaces
        }
    }
    
    /// 获取空间下的文章数量
    func getArticleCount(for spaceId: UUID) async throws -> Int {
        let sql = "SELECT COUNT(*) as count FROM space_articles WHERE space_id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [spaceId.uuidString])
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return 0 }
            
            return Int(sqlite3_column_int(statement, 0))
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractSpaceDict(from statement: OpaquePointer?) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let idCString = sqlite3_column_text(statement, 0) {
            dict["id"] = String(cString: idCString)
        }
        if let nameCString = sqlite3_column_text(statement, 1) {
            dict["name"] = String(cString: nameCString)
        }
        if let descCString = sqlite3_column_text(statement, 2) {
            dict["description"] = String(cString: descCString)
        }
        dict["created_at"] = sqlite3_column_double(statement, 3)
        dict["updated_at"] = sqlite3_column_double(statement, 4)
        
        return dict
    }
}