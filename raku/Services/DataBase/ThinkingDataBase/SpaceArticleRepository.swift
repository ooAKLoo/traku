//
//  SpaceArticleRepository.swift
//  raku
//
//  Created by Assistant on 2025/9/15.
//

import Foundation
import SQLite3

/// SpaceArticle Repository - 管理空间-文章关系数据
class SpaceArticleRepository: Repository {
    typealias Model = SpaceArticle
    
    private let sqliteCore: SQLiteCore
    
    init(sqliteCore: SQLiteCore) {
        self.sqliteCore = sqliteCore
    }
    
    // MARK: - Table Management
    
    func createTable() async throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS space_articles (
                id TEXT PRIMARY KEY,
                space_id TEXT NOT NULL,
                audio_recording_id TEXT NOT NULL,
                category_id TEXT,
                created_at REAL NOT NULL,
                is_marked_important INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE,
                FOREIGN KEY (audio_recording_id) REFERENCES recordings(id) ON DELETE CASCADE,
                FOREIGN KEY (category_id) REFERENCES categories(category_id) ON DELETE SET NULL,
                UNIQUE(space_id, audio_recording_id, category_id)
            )
        """
        
        try await sqliteCore.execute(sql)
        print("✅ SpaceArticles table created successfully")
    }
    
    // MARK: - CRUD Operations
    
    func create(_ spaceArticle: SpaceArticle) async throws -> Bool {
        let sql = """
            INSERT INTO space_articles (id, space_id, audio_recording_id, category_id, created_at, is_marked_important)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        
        let params: [Any] = [
            spaceArticle.id.uuidString,
            spaceArticle.spaceId.uuidString,
            spaceArticle.audioRecordingId.uuidString,
            spaceArticle.categoryId?.uuidString ?? NSNull(),
            spaceArticle.createdAt.timeIntervalSince1970,
            spaceArticle.isMarkedImportant ? 1 : 0
        ]
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: params)
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    func read(id: UUID) async throws -> SpaceArticle? {
        let sql = "SELECT * FROM space_articles WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return nil }
            
            let dict = self.extractSpaceArticleDict(from: statement)
            return SpaceArticle.fromDict(dict)
        }
    }
    
    func update(_ spaceArticle: SpaceArticle) async throws -> Bool {
        let sql = """
            UPDATE space_articles SET
                space_id = ?,
                audio_recording_id = ?,
                category_id = ?,
                is_marked_important = ?
            WHERE id = ?
        """
        
        let params: [Any] = [
            spaceArticle.spaceId.uuidString,
            spaceArticle.audioRecordingId.uuidString,
            spaceArticle.categoryId?.uuidString ?? NSNull(),
            spaceArticle.isMarkedImportant ? 1 : 0,
            spaceArticle.id.uuidString
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
        let sql = "DELETE FROM space_articles WHERE id = ?"
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    func saveOrUpdate(_ spaceArticle: SpaceArticle) async throws -> Bool {
        // Check if spaceArticle exists
        if let _ = try await read(id: spaceArticle.id) {
            return try await update(spaceArticle)
        } else {
            return try await create(spaceArticle)
        }
    }
    
    func list(filter: FilterCriteria? = nil) async throws -> [SpaceArticle] {
        return try await listWithParams(limit: filter?.limit, offset: filter?.offset)
    }
    
    private func listWithParams(limit: Int? = nil, offset: Int? = nil) async throws -> [SpaceArticle] {
        var sql = "SELECT * FROM space_articles ORDER BY created_at DESC"
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
            
            var spaceArticles: [SpaceArticle] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractSpaceArticleDict(from: statement)
                if let spaceArticle = SpaceArticle.fromDict(dict) {
                    spaceArticles.append(spaceArticle)
                }
            }
            return spaceArticles
        }
    }
    
    func count() async throws -> Int {
        let sql = "SELECT COUNT(*) as count FROM space_articles"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return 0 }
            
            return Int(sqlite3_column_int(statement, 0))
        }
    }
    
    // MARK: - SpaceArticle-Specific Operations
    
    /// 获取指定空间下的所有文章
    func getArticlesForSpace(_ spaceId: UUID) async throws -> [SpaceArticle] {
        let sql = "SELECT * FROM space_articles WHERE space_id = ? ORDER BY created_at DESC"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [spaceId.uuidString])
            
            var spaceArticles: [SpaceArticle] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractSpaceArticleDict(from: statement)
                if let spaceArticle = SpaceArticle.fromDict(dict) {
                    spaceArticles.append(spaceArticle)
                }
            }
            return spaceArticles
        }
    }
    
    /// 获取指定类别下的所有文章
    func getArticlesForCategory(_ categoryId: UUID) async throws -> [SpaceArticle] {
        let sql = "SELECT * FROM space_articles WHERE category_id = ? ORDER BY created_at DESC"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [categoryId.uuidString])
            
            var spaceArticles: [SpaceArticle] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractSpaceArticleDict(from: statement)
                if let spaceArticle = SpaceArticle.fromDict(dict) {
                    spaceArticles.append(spaceArticle)
                }
            }
            return spaceArticles
        }
    }
    
    /// 获取指定空间下无类别的文章
    func getUncategorizedArticlesForSpace(_ spaceId: UUID) async throws -> [SpaceArticle] {
        let sql = "SELECT * FROM space_articles WHERE space_id = ? AND category_id IS NULL ORDER BY created_at DESC"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [spaceId.uuidString])
            
            var spaceArticles: [SpaceArticle] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractSpaceArticleDict(from: statement)
                if let spaceArticle = SpaceArticle.fromDict(dict) {
                    spaceArticles.append(spaceArticle)
                }
            }
            return spaceArticles
        }
    }
    
    /// 获取指定录音所在的所有空间
    func getSpacesForRecording(_ recordingId: UUID) async throws -> [SpaceArticle] {
        let sql = "SELECT * FROM space_articles WHERE audio_recording_id = ? ORDER BY created_at DESC"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [recordingId.uuidString])
            
            var spaceArticles: [SpaceArticle] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                let dict = self.extractSpaceArticleDict(from: statement)
                if let spaceArticle = SpaceArticle.fromDict(dict) {
                    spaceArticles.append(spaceArticle)
                }
            }
            return spaceArticles
        }
    }
    
    /// 添加录音到空间（可选指定类别）
    func addRecordingToSpace(recordingId: UUID, spaceId: UUID, categoryId: UUID? = nil) async throws -> Bool {
        let spaceArticle = SpaceArticle(
            spaceId: spaceId,
            audioRecordingId: recordingId,
            categoryId: categoryId
        )
        return try await create(spaceArticle)
    }
    
    /// 从空间移除录音
    func removeRecordingFromSpace(recordingId: UUID, spaceId: UUID) async throws -> Bool {
        let sql = "DELETE FROM space_articles WHERE audio_recording_id = ? AND space_id = ?"
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [recordingId.uuidString, spaceId.uuidString])
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    /// 更新录音在空间中的类别
    func updateRecordingCategory(recordingId: UUID, spaceId: UUID, categoryId: UUID?) async throws -> Bool {
        let sql = """
            UPDATE space_articles SET
                category_id = ?
            WHERE audio_recording_id = ? AND space_id = ?
        """
        
        let params: [Any] = [
            categoryId?.uuidString ?? NSNull(),
            recordingId.uuidString,
            spaceId.uuidString
        ]
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: params)
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    /// 检查录音是否已在指定空间中
    func isRecordingInSpace(recordingId: UUID, spaceId: UUID) async throws -> Bool {
        let sql = "SELECT COUNT(*) as count FROM space_articles WHERE audio_recording_id = ? AND space_id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [recordingId.uuidString, spaceId.uuidString])
            
            guard try self.sqliteCore.step(statement) == SQLITE_ROW else { return false }
            
            let count = Int(sqlite3_column_int(statement, 0))
            return count > 0
        }
    }
    
    /// 切换文章的重要标记状态
    func toggleImportantMark(for articleId: UUID) async throws -> Bool {
        let sql = """
            UPDATE space_articles SET
                is_marked_important = NOT is_marked_important
            WHERE id = ?
        """
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [articleId.uuidString])
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    /// 设置文章的重要标记状态
    func setImportantMark(for articleId: UUID, isImportant: Bool) async throws -> Bool {
        let sql = """
            UPDATE space_articles SET
                is_marked_important = ?
            WHERE id = ?
        """
        
        let params: [Any] = [
            isImportant ? 1 : 0,
            articleId.uuidString
        ]
        
        try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: params)
            _ = try self.sqliteCore.step(statement)
        }
        return true
    }
    
    /// 获取带详细信息的空间文章（包含录音信息）
    func getArticlesWithRecordingInfo(for spaceId: UUID) async throws -> [[String: Any]] {
        let sql = """
            SELECT 
                sa.*,
                r.title as recording_title,
                r.summary as recording_summary,
                r.timestamp as recording_timestamp,
                r.duration as recording_duration,
                r.content_type as recording_content_type,
                c.name as category_name
            FROM space_articles sa
            LEFT JOIN audio_recordings r ON sa.audio_recording_id = r.id
            LEFT JOIN categories c ON sa.category_id = c.category_id
            WHERE sa.space_id = ?
            ORDER BY sa.created_at DESC
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            try self.sqliteCore.bind(statement, parameters: [spaceId.uuidString])
            
            var results: [[String: Any]] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                var dict: [String: Any] = self.extractSpaceArticleDict(from: statement)
                
                // Add recording info
                if let titleCString = sqlite3_column_text(statement, 5) {
                    dict["recording_title"] = String(cString: titleCString)
                }
                if let summaryCString = sqlite3_column_text(statement, 6) {
                    dict["recording_summary"] = String(cString: summaryCString)
                }
                dict["recording_timestamp"] = sqlite3_column_double(statement, 7)
                dict["recording_duration"] = sqlite3_column_double(statement, 8)
                if let contentTypeCString = sqlite3_column_text(statement, 9) {
                    dict["recording_content_type"] = String(cString: contentTypeCString)
                }
                if let categoryNameCString = sqlite3_column_text(statement, 10) {
                    dict["category_name"] = String(cString: categoryNameCString)
                }
                
                results.append(dict)
            }
            return results
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractSpaceArticleDict(from statement: OpaquePointer?) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let idCString = sqlite3_column_text(statement, 0) {
            dict["id"] = String(cString: idCString)
        }
        if let spaceIdCString = sqlite3_column_text(statement, 1) {
            dict["space_id"] = String(cString: spaceIdCString)
        }
        if let recordingIdCString = sqlite3_column_text(statement, 2) {
            dict["audio_recording_id"] = String(cString: recordingIdCString)
        }
        if let categoryIdCString = sqlite3_column_text(statement, 3) {
            dict["category_id"] = String(cString: categoryIdCString)
        }
        dict["created_at"] = sqlite3_column_double(statement, 4)
        dict["is_marked_important"] = sqlite3_column_int(statement, 5) == 1
        
        return dict
    }
}