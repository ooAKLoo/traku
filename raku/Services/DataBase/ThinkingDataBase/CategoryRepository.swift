//
//  CategoryRepository.swift
//  raku
//
//  Created by Assistant on 2025/9/15.
//

import Foundation
import SQLite3

/// Category Repository - 管理类别数据
class CategoryRepository: Repository {
    typealias Model = Category
    
    private let sqliteCore: SQLiteCore
    
    init(sqliteCore: SQLiteCore) {
        self.sqliteCore = sqliteCore
    }
    
    // MARK: - Table Management
    
    func createTable() async throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS categories (
                category_id TEXT PRIMARY KEY,
                space_id TEXT NOT NULL,
                name TEXT NOT NULL,
                FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE
            )
        """
        
        try await sqliteCore.execute(sql)
        print("✅ Categories table created successfully")
    }
    
    // MARK: - CRUD Operations
    
    func create(_ category: Category) async throws -> Bool {
        let sql = """
            INSERT INTO categories (category_id, space_id, name)
            VALUES (?, ?, ?)
        """
        
        let params: [Any] = [
            category.id.uuidString,
            category.spaceId.uuidString,
            category.name
        ]
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: params)
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    func read(id: UUID) async throws -> Category? {
        let sql = "SELECT * FROM categories WHERE category_id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return nil }
            
            let dict = self.extractCategoryDict(from: statement)
            return Category.fromDict(dict)
        }
    }
    
    func update(_ category: Category) async throws -> Bool {
        let sql = """
            UPDATE categories SET
                space_id = ?,
                name = ?
            WHERE category_id = ?
        """
        
        let params: [Any] = [
            category.spaceId.uuidString,
            category.name,
            category.id.uuidString
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
        // 先删除相关的空间-文章关系中的类别引用
        let updateSpaceArticlesSql = "UPDATE space_articles SET category_id = NULL WHERE category_id = ?"
        let deleteCategorySql = "DELETE FROM categories WHERE category_id = ?"
        
        let idString = id.uuidString
        
        try await sqliteCore.performAsync {
            try self.sqliteCore.executeInternal("BEGIN TRANSACTION")
            
            do {
                // 更新空间-文章关系
                let stmt1 = try self.sqliteCore.prepare(updateSpaceArticlesSql)
                defer { self.sqliteCore.finalize(stmt1) }
                try self.sqliteCore.bind(stmt1, parameters: [idString])
                _ = try self.sqliteCore.step(stmt1)
                
                // 删除类别
                let stmt2 = try self.sqliteCore.prepare(deleteCategorySql)
                defer { self.sqliteCore.finalize(stmt2) }
                try self.sqliteCore.bind(stmt2, parameters: [idString])
                _ = try self.sqliteCore.step(stmt2)
                
                try self.sqliteCore.executeInternal("COMMIT")
            } catch {
                try self.sqliteCore.executeInternal("ROLLBACK")
                throw error
            }
        }
        return true
    }
    
    func saveOrUpdate(_ category: Category) async throws -> Bool {
        // Check if category exists
        if let _ = try await read(id: category.id) {
            return try await update(category)
        } else {
            return try await create(category)
        }
    }
    
    func list(filter: FilterCriteria? = nil) async throws -> [Category] {
        return try await listWithParams(limit: filter?.limit, offset: filter?.offset)
    }
    
    private func listWithParams(limit: Int? = nil, offset: Int? = nil) async throws -> [Category] {
        var sql = "SELECT * FROM categories ORDER BY name ASC"
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
            
            var categories: [Category] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractCategoryDict(from: statement)
                if let category = Category.fromDict(dict) {
                    categories.append(category)
                }
            }
            return categories
        }
    }
    
    func count() async throws -> Int {
        let sql = "SELECT COUNT(*) as count FROM categories"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return 0 }
            
            return Int(sqlite3_column_int(statement, 0))
        }
    }
    
    // MARK: - Category-Specific Operations
    
    /// 获取指定空间下的所有类别
    func getCategoriesForSpace(_ spaceId: UUID) async throws -> [Category] {
        let sql = "SELECT * FROM categories WHERE space_id = ? ORDER BY name ASC"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [spaceId.uuidString])
            
            var categories: [Category] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractCategoryDict(from: statement)
                if let category = Category.fromDict(dict) {
                    categories.append(category)
                }
            }
            return categories
        }
    }
    
    /// 根据名称在指定空间内搜索类别
    func searchByNameInSpace(_ name: String, spaceId: UUID) async throws -> [Category] {
        let sql = "SELECT * FROM categories WHERE space_id = ? AND name LIKE ? ORDER BY name ASC"
        let searchPattern = "%\(name)%"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [spaceId.uuidString, searchPattern])
            
            var categories: [Category] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractCategoryDict(from: statement)
                if let category = Category.fromDict(dict) {
                    categories.append(category)
                }
            }
            return categories
        }
    }
    
    /// 获取类别下的文章数量
    func getArticleCount(for categoryId: UUID) async throws -> Int {
        let sql = "SELECT COUNT(*) as count FROM space_articles WHERE category_id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [categoryId.uuidString])
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return 0 }
            
            return Int(sqlite3_column_int(statement, 0))
        }
    }
    
    /// 检查类别名称在空间内是否唯一
    func isNameUniqueInSpace(_ name: String, spaceId: UUID, excludeId: UUID? = nil) async throws -> Bool {
        var sql = "SELECT COUNT(*) as count FROM categories WHERE space_id = ? AND name = ?"
        var params: [Any] = [spaceId.uuidString, name]
        
        if let excludeId = excludeId {
            sql += " AND category_id != ?"
            params.append(excludeId.uuidString)
        }
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: params)
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return true }
            
            let count = Int(sqlite3_column_int(statement, 0))
            return count == 0
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractCategoryDict(from statement: OpaquePointer?) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let idCString = sqlite3_column_text(statement, 0) {
            dict["category_id"] = String(cString: idCString)
        }
        if let spaceIdCString = sqlite3_column_text(statement, 1) {
            dict["space_id"] = String(cString: spaceIdCString)
        }
        if let nameCString = sqlite3_column_text(statement, 2) {
            dict["name"] = String(cString: nameCString)
        }
        
        return dict
    }
}