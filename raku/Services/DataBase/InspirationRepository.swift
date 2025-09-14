//
//  InspirationRepository.swift
//  raku
//
//  Created by Assistant on Repository Pattern Refactor
//

import Foundation
import SQLite3

/// 灵感数据仓库实现
class InspirationRepository: Repository {
    typealias Model = InspirationData
    
    private let sqliteCore: SQLiteCore
    private let tableName = "inspirations"
    
    init(sqliteCore: SQLiteCore) {
        self.sqliteCore = sqliteCore
    }
    
    // MARK: - Table Management
    
    /// 创建灵感表
    func createTable() async throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(tableName) (
                id TEXT PRIMARY KEY,
                recording_id TEXT,
                original_text TEXT NOT NULL,
                polished_text TEXT NOT NULL,
                tags TEXT NOT NULL,
                embedding_vector TEXT NOT NULL,
                created_at REAL NOT NULL DEFAULT (julianday('now')),
                FOREIGN KEY (recording_id) REFERENCES recordings(id)
            );
            
            CREATE INDEX IF NOT EXISTS idx_inspirations_recording_id ON \(tableName) (recording_id);
        """
        
        let createIndexSQL = """
            CREATE INDEX IF NOT EXISTS idx_inspirations_created_at ON \(tableName)(created_at);
        """
        
        try await sqliteCore.performAsync {
            try self.sqliteCore.executeInternal(createTableSQL)
            try self.sqliteCore.executeInternal(createIndexSQL)
            print("✅ 灵感表和索引创建成功")
        }
        
        // 数据库结构迁移：处理旧数据库的audio_data列
        await migrateOldSchema()
    }
    
    /// 迁移旧数据库结构（移除audio_data列）
    private func migrateOldSchema() async {
        do {
            // 检查是否存在audio_data列
            let checkColumnSQL = "PRAGMA table_info(\(tableName))"
            
            try await sqliteCore.performAsync {
                let statement = try self.sqliteCore.prepare(checkColumnSQL)
                defer { self.sqliteCore.finalize(statement) }
                
                var hasAudioDataColumn = false
                while try self.sqliteCore.step(statement) == SQLITE_ROW {
                    if let columnName = sqlite3_column_text(statement, 1) {
                        let name = String(cString: columnName)
                        if name == "audio_data" {
                            hasAudioDataColumn = true
                            break
                        }
                    }
                }
                
                if hasAudioDataColumn {
                    print("🔄 检测到旧灵感表结构，开始迁移（移除audio_data列）...")
                    try self.migrateTableWithoutAudioData()
                }
            }
        } catch {
            print("❌ 灵感表数据库迁移检查失败: \(error)")
        }
    }
    
    /// 迁移表结构，移除audio_data列
    private func migrateTableWithoutAudioData() throws {
        // 创建新表结构
        let tempTableSQL = """
            CREATE TABLE IF NOT EXISTS \(tableName)_new (
                id TEXT PRIMARY KEY,
                recording_id TEXT,
                original_text TEXT NOT NULL,
                polished_text TEXT NOT NULL,
                tags TEXT NOT NULL,
                embedding_vector TEXT NOT NULL,
                created_at REAL NOT NULL DEFAULT (julianday('now')),
                FOREIGN KEY (recording_id) REFERENCES recordings(id)
            );
        """
        
        // 复制数据（排除audio_data列）
        let copyDataSQL = """
            INSERT INTO \(tableName)_new (id, recording_id, original_text, polished_text, tags, embedding_vector, created_at)
            SELECT id, 
                   CASE WHEN recording_id IS NOT NULL THEN recording_id ELSE id END as recording_id,
                   original_text, polished_text, tags, embedding_vector, 
                   CASE WHEN created_at IS NOT NULL THEN created_at ELSE julianday('now') END as created_at
            FROM \(tableName)
        """
        
        // 删除旧表并重命名新表
        let dropOldTableSQL = "DROP TABLE \(tableName)"
        let renameTableSQL = "ALTER TABLE \(tableName)_new RENAME TO \(tableName)"
        
        try sqliteCore.executeInternal(tempTableSQL)
        try sqliteCore.executeInternal(copyDataSQL)
        try sqliteCore.executeInternal(dropOldTableSQL)
        try sqliteCore.executeInternal(renameTableSQL)
        
        // 重建索引
        let createIndex1SQL = "CREATE INDEX IF NOT EXISTS idx_inspirations_recording_id ON \(tableName) (recording_id);"
        let createIndex2SQL = "CREATE INDEX IF NOT EXISTS idx_inspirations_created_at ON \(tableName)(created_at);"
        try sqliteCore.executeInternal(createIndex1SQL)
        try sqliteCore.executeInternal(createIndex2SQL)
        
        print("✅ 灵感表数据库结构迁移完成，已移除audio_data列")
    }
    
    // MARK: - Repository Protocol Implementation
    
    func create(_ model: InspirationData) async throws -> Bool {
        let insertSQL = """
            INSERT INTO \(tableName) (id, recording_id, original_text, polished_text, tags, embedding_vector, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(insertSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let modelDict = model.toDict()
            let parameters: [Any] = [
                modelDict["id"] as Any,
                modelDict["id"] as Any,  // recording_id 暂时与 id 相同
                modelDict["original_text"] as Any,
                modelDict["polished_text"] as Any,
                modelDict["tags"] as Any,
                modelDict["embedding_vector"] as Any,
                modelDict["created_at"] as Any
            ]
            
            try self.sqliteCore.bind(statement, parameters: parameters)
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 灵感保存成功，ID: \(model.id)")
                return true
            } else {
                throw DatabaseError.insertFailed("Failed to insert inspiration")
            }
        }
    }
    
    func read(id: String) async throws -> InspirationData? {
        let querySQL = """
            SELECT id, recording_id, original_text, polished_text, tags, embedding_vector, created_at
            FROM \(tableName)
            WHERE id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id])
            let result = try self.sqliteCore.step(statement)
            
            guard result == SQLITE_ROW else { return nil }
            
            return self.parseInspiration(from: statement)
        }
    }
    
    func update(_ model: InspirationData) async throws -> Bool {
        let updateSQL = """
            UPDATE \(tableName) 
            SET recording_id = ?, original_text = ?, polished_text = ?, tags = ?, embedding_vector = ?
            WHERE id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(updateSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let modelDict = model.toDict()
            let parameters: [Any] = [
                modelDict["id"] as Any,  // recording_id 暂时与 id 相同
                modelDict["original_text"] as Any,
                modelDict["polished_text"] as Any,
                modelDict["tags"] as Any,
                modelDict["embedding_vector"] as Any,
                modelDict["id"] as Any
            ]
            
            try self.sqliteCore.bind(statement, parameters: parameters)
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 灵感更新成功，ID: \(model.id)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.updateFailed("Failed to update inspiration")
            }
        }
    }
    
    func delete(id: String) async throws -> Bool {
        let deleteSQL = "DELETE FROM \(tableName) WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(deleteSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id])
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 灵感删除成功，ID: \(id)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.deleteFailed("Failed to delete inspiration")
            }
        }
    }
    
    func saveOrUpdate(_ model: InspirationData) async throws -> Bool {
        let existingRecord = try await read(id: model.id)
        
        if existingRecord != nil {
            return try await update(model)
        } else {
            return try await create(model)
        }
    }
    
    func count() async throws -> Int {
        let countSQL = "SELECT COUNT(*) FROM \(tableName)"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(countSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let result = try self.sqliteCore.step(statement)
            guard result == SQLITE_ROW else {
                throw DatabaseError.queryFailed("Failed to get count")
            }
            
            return Int(sqlite3_column_int(statement, 0))
        }
    }
    
    func list(filter: FilterCriteria? = nil) async throws -> [InspirationData] {
        var querySQL = """
            SELECT id, recording_id, original_text, polished_text, tags, embedding_vector, created_at
            FROM \(tableName)
        """
        
        var parameters: [Any] = []
        
        if let filter = filter {
            if let whereClause = filter.whereClause {
                querySQL += " WHERE \(whereClause)"
                parameters.append(contentsOf: filter.parameters ?? [])
            }
            
            if let orderBy = filter.orderBy {
                querySQL += " ORDER BY \(orderBy)"
                if !filter.ascending {
                    querySQL += " DESC"
                }
            } else {
                querySQL += " ORDER BY created_at DESC"
            }
            
            if let limit = filter.limit {
                querySQL += " LIMIT \(limit)"
                if let offset = filter.offset {
                    querySQL += " OFFSET \(offset)"
                }
            }
        } else {
            querySQL += " ORDER BY created_at DESC"
        }
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }
            
            if !parameters.isEmpty {
                try self.sqliteCore.bind(statement, parameters: parameters)
            }
            
            var inspirations: [InspirationData] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                if let inspiration = self.parseInspiration(from: statement) {
                    inspirations.append(inspiration)
                }
            }
            
            print("✅ 成功加载 \(inspirations.count) 条灵感记录")
            return inspirations
        }
    }
    
    // MARK: - Additional Methods
    
    /// 根据标签搜索灵感
    func searchByTags(_ tags: [String]) async throws -> [InspirationData] {
        let tagConditions = tags.map { _ in "tags LIKE ?" }.joined(separator: " OR ")
        let whereClause = "(\(tagConditions))"
        let parameters = tags.map { "%\($0)%" }
        
        let filter = FilterCriteria(
            whereClause: whereClause,
            parameters: parameters
        )
        
        return try await list(filter: filter)
    }
    
    /// 根据文本内容搜索灵感
    func searchByText(_ searchText: String) async throws -> [InspirationData] {
        let whereClause = "original_text LIKE ? OR polished_text LIKE ?"
        let parameters = ["%\(searchText)%", "%\(searchText)%"]
        
        let filter = FilterCriteria(
            whereClause: whereClause,
            parameters: parameters
        )
        
        return try await list(filter: filter)
    }
    
    /// 获取最近的灵感记录
    func getRecent(limit: Int = 20) async throws -> [InspirationData] {
        let filter = FilterCriteria(
            limit: limit,
            orderBy: "created_at",
            ascending: false
        )
        
        return try await list(filter: filter)
    }
    
    // MARK: - Helper Methods
    
    /// 从 SQLite statement 解析灵感记录
    private func parseInspiration(from statement: OpaquePointer?) -> InspirationData? {
        guard let statement = statement else { return nil }
        
        guard let idString = sqlite3_column_text(statement, 0),
              let originalText = sqlite3_column_text(statement, 2),
              let polishedText = sqlite3_column_text(statement, 3),
              let tagsString = sqlite3_column_text(statement, 4),
              let vectorString = sqlite3_column_text(statement, 5) else {
            return nil
        }
        
        let id = String(cString: idString)
        // recording_id 在索引1位置，但目前不需要读取
        let original = String(cString: originalText)
        let polished = String(cString: polishedText)
        let tagsStr = String(cString: tagsString)
        let vectorStr = String(cString: vectorString)
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))
        
        // audio_data 已经从表中移除，不再读取
        var audioData: Data? = nil
        
        // 解析标签
        let tagsData = tagsStr.data(using: .utf8)
        let tags = (try? JSONDecoder().decode([String].self, from: tagsData ?? Data())) ?? []
        
        // 解析向量
        let vectorData = vectorStr.data(using: .utf8)
        let embeddingVector = (try? JSONDecoder().decode([Float].self, from: vectorData ?? Data())) ?? []
        
        return InspirationData(
            id: id,
            originalText: original,
            polishedText: polished,
            tags: tags,
            createdAt: createdAt,
            audioData: audioData,
            embeddingVector: embeddingVector
        )
    }
}