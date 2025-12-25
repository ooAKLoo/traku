//
//  RecordingRepository.swift
//  raku
//
//  Created by Assistant on Repository Pattern Refactor
//

import Foundation
import SQLite3

/// 录音数据仓库实现
class RecordingRepository: Repository {
    typealias Model = AudioRecording
    
    private let sqliteCore: SQLiteCore
    private let tableName = "audio_recordings"
    
    init(sqliteCore: SQLiteCore) {
        self.sqliteCore = sqliteCore
    }
    
    // MARK: - Table Management
    
    /// 创建统一的录音表（合并 embeddings 和 inspirations 表功能）
    func createTable() async throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(tableName) (
                id TEXT PRIMARY KEY,
                recording_id TEXT,
                timestamp REAL NOT NULL,
                duration REAL NOT NULL,
                transcription TEXT NOT NULL,
                title TEXT,
                summary TEXT NOT NULL,
                tags TEXT NOT NULL,
                enriched_content TEXT,
                polished_text TEXT,
                content_type TEXT NOT NULL DEFAULT 'thinking',
                original_text TEXT,
                embedding_vector TEXT,
                weather_type TEXT,
                weather_location TEXT,
                created_at REAL NOT NULL DEFAULT (julianday('now')),
                FOREIGN KEY (recording_id) REFERENCES recordings(id)
            );
            
            CREATE INDEX IF NOT EXISTS idx_audio_recordings_recording_id ON \(tableName) (recording_id);
            CREATE INDEX IF NOT EXISTS idx_audio_recordings_content_type ON \(tableName) (content_type);
            CREATE INDEX IF NOT EXISTS idx_audio_recordings_created_at ON \(tableName) (created_at);
        """
        
        try await sqliteCore.performAsync {
            try self.sqliteCore.executeInternal(createTableSQL)
            print("✅ 录音表创建成功")
        }
        
        // 兼容性：添加可能缺失的列
        await addMissingColumns()
        // 数据库结构迁移：处理旧数据库的audio_data列
        await migrateOldSchema()
    }
    
    /// 添加缺失的列（兼容旧数据库）
    private func addMissingColumns() async {
        let columnsToAdd = [
            "ALTER TABLE \(tableName) ADD COLUMN title TEXT;",
            "ALTER TABLE \(tableName) ADD COLUMN polished_text TEXT;",
            "ALTER TABLE \(tableName) ADD COLUMN recording_id TEXT;",
            "ALTER TABLE \(tableName) ADD COLUMN content_type TEXT NOT NULL DEFAULT 'thinking';",
            "ALTER TABLE \(tableName) ADD COLUMN original_text TEXT;",
            "ALTER TABLE \(tableName) ADD COLUMN embedding_vector TEXT;",
            "ALTER TABLE \(tableName) ADD COLUMN weather_type TEXT;",
            "ALTER TABLE \(tableName) ADD COLUMN weather_location TEXT;",
            "ALTER TABLE \(tableName) ADD COLUMN deleted_at REAL;"  // 软删除时间戳
        ]
        
        for sql in columnsToAdd {
            do {
                try await sqliteCore.performAsync {
                    try self.sqliteCore.executeInternal(sql)
                }
                // 列添加成功
                if sql.contains("deleted_at") {
                    print("✅ deleted_at 列添加成功")
                }
            } catch {
                // 忽略错误（列可能已存在）
                if sql.contains("deleted_at") {
                    print("⚠️ deleted_at 列添加失败或已存在: \(error.localizedDescription)")
                }
            }
        }
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
                    print("🔄 检测到旧数据库结构，开始迁移（移除audio_data列）...")
                    try self.migrateTableWithoutAudioData()
                }
            }
        } catch {
            print("❌ 数据库迁移检查失败: \(error)")
        }
    }
    
    /// 迁移表结构，移除audio_data列
    private func migrateTableWithoutAudioData() throws {
        // 创建新表结构
        let tempTableSQL = """
            CREATE TABLE IF NOT EXISTS \(tableName)_new (
                id TEXT PRIMARY KEY,
                recording_id TEXT,
                timestamp REAL NOT NULL,
                duration REAL NOT NULL,
                transcription TEXT NOT NULL,
                title TEXT,
                summary TEXT NOT NULL,
                tags TEXT NOT NULL,
                enriched_content TEXT,
                polished_text TEXT,
                content_type TEXT NOT NULL DEFAULT 'thinking',
                original_text TEXT,
                embedding_vector TEXT,
                weather_type TEXT,
                weather_location TEXT,
                created_at REAL NOT NULL DEFAULT (julianday('now')),
                FOREIGN KEY (recording_id) REFERENCES recordings(id)
            );
        """
        
        // 复制数据（排除audio_data列，添加新字段）
        let copyDataSQL = """
            INSERT INTO \(tableName)_new (id, recording_id, timestamp, duration, transcription, title, summary, tags, enriched_content, polished_text, content_type, original_text, embedding_vector, weather_type, weather_location, created_at)
            SELECT id, 
                   CASE WHEN recording_id IS NOT NULL THEN recording_id ELSE id END as recording_id,
                   timestamp, duration, transcription, title, summary, tags, enriched_content, polished_text,
                   'thinking' as content_type,
                   transcription as original_text,
                   NULL as embedding_vector,
                   NULL as weather_type,
                   NULL as weather_location,
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
        let createIndexSQL = [
            "CREATE INDEX IF NOT EXISTS idx_audio_recordings_recording_id ON \(tableName) (recording_id);",
            "CREATE INDEX IF NOT EXISTS idx_audio_recordings_content_type ON \(tableName) (content_type);",
            "CREATE INDEX IF NOT EXISTS idx_audio_recordings_created_at ON \(tableName) (created_at);"
        ]
        for indexSQL in createIndexSQL {
            try sqliteCore.executeInternal(indexSQL)
        }
        
        print("✅ 数据库结构迁移完成，已移除audio_data列")
    }
    
    // MARK: - Repository Protocol Implementation
    
    func create(_ model: AudioRecording) async throws -> Bool {
        let insertSQL = """
            INSERT INTO \(tableName) (id, recording_id, timestamp, duration, transcription, title, summary, tags, enriched_content, polished_text, content_type, original_text, embedding_vector, weather_type, weather_location, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(insertSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let modelDict = model.toDict()
            let contentType = modelDict["content_type"] as? String ?? "thinking"
            
            let parameters: [Any] = [
                modelDict["id"] as Any,
                modelDict["id"] as Any,  // recording_id 暂时与 id 相同
                modelDict["timestamp"] as Any,
                modelDict["duration"] as Any,
                modelDict["transcription"] as Any,
                modelDict["title"] as Any,
                modelDict["summary"] as Any,
                modelDict["tags"] as Any,
                modelDict["enriched_content"] ?? NSNull(),
                modelDict["polished_text"] ?? NSNull(),
                contentType,  // 从模型获取content_type
                modelDict["transcription"] as Any,  // original_text 默认使用转录文本
                NSNull(),  // embedding_vector 初始为空
                modelDict["weather_type"] ?? NSNull(),
                modelDict["weather_location"] ?? NSNull(),
                Date().timeIntervalSince1970
            ]
            
            try self.sqliteCore.bind(statement, parameters: parameters)
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 录音保存成功，ID: \(model.id.uuidString)")
                return true
            } else {
                throw DatabaseError.insertFailed("Failed to insert recording")
            }
        }
    }
    
    func read(id: UUID) async throws -> AudioRecording? {
        let querySQL = """
            SELECT id, recording_id, timestamp, duration, transcription, title, summary, tags, 
                   enriched_content, polished_text, content_type, original_text, embedding_vector, weather_type, weather_location
            FROM \(tableName)
            WHERE id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            let result = try self.sqliteCore.step(statement)
            
            guard result == SQLITE_ROW else { return nil }
            
            return self.parseRecording(from: statement)
        }
    }
    
    func update(_ model: AudioRecording) async throws -> Bool {
        let updateSQL = """
            UPDATE \(tableName) 
            SET recording_id = ?, timestamp = ?, duration = ?, transcription = ?, title = ?, summary = ?, 
                tags = ?, enriched_content = ?, polished_text = ?, content_type = ?, original_text = ?, embedding_vector = ?, weather_type = ?, weather_location = ?
            WHERE id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(updateSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let modelDict = model.toDict()
            let contentType = modelDict["content_type"] as? String ?? "thinking"

            let parameters: [Any] = [
                modelDict["id"] as Any,  // recording_id 暂时与 id 相同
                modelDict["timestamp"] as Any,
                modelDict["duration"] as Any,
                modelDict["transcription"] as Any,
                modelDict["title"] as Any,
                modelDict["summary"] as Any,
                modelDict["tags"] as Any,
                modelDict["enriched_content"] ?? NSNull(),
                modelDict["polished_text"] ?? NSNull(),
                contentType,  // 从模型获取content_type
                modelDict["transcription"] as Any,  // original_text 默认使用转录文本
                NSNull(),  // embedding_vector
                modelDict["weather_type"] ?? NSNull(),
                modelDict["weather_location"] ?? NSNull(),
                modelDict["id"] as Any
            ]
            
            try self.sqliteCore.bind(statement, parameters: parameters)
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 录音更新成功，ID: \(model.id.uuidString)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.updateFailed("Failed to update recording")
            }
        }
    }
    
    func delete(id: UUID) async throws -> Bool {
        let deleteSQL = "DELETE FROM \(tableName) WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(deleteSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 录音删除成功，ID: \(id.uuidString)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.deleteFailed("Failed to delete recording")
            }
        }
    }
    
    func saveOrUpdate(_ model: AudioRecording) async throws -> Bool {
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
    
    /// 协议要求的 list 方法 - 默认不包含已删除记录
    func list(filter: FilterCriteria? = nil) async throws -> [AudioRecording] {
        return try await listRecordings(filter: filter, includeDeleted: false)
    }
    
    /// 检查 deleted_at 列是否存在
    private func hasDeletedAtColumn() async -> Bool {
        let pragmaSQL = "PRAGMA table_info(\(tableName))"
        do {
            return try await sqliteCore.performAsync {
                let statement = try self.sqliteCore.prepare(pragmaSQL)
                defer { self.sqliteCore.finalize(statement) }
                
                while try self.sqliteCore.step(statement) == SQLITE_ROW {
                    if let name = sqlite3_column_text(statement, 1) {
                        let columnName = String(cString: name)
                        if columnName == "deleted_at" {
                            return true
                        }
                    }
                }
                return false
            }
        } catch {
            return false
        }
    }
    
    /// 内部方法：支持包含/不包含已删除记录
    func listRecordings(filter: FilterCriteria? = nil, includeDeleted: Bool = false) async throws -> [AudioRecording] {
        // 检查 deleted_at 列是否存在（兼容数据库迁移尚未完成的情况）
        let hasDeletedAt = await hasDeletedAtColumn()
        
        var selectColumns = """
            id, recording_id, timestamp, duration, transcription, title, summary, tags, 
            enriched_content, polished_text, content_type, original_text, embedding_vector, weather_type, weather_location
        """
        
        if hasDeletedAt {
            selectColumns += ", deleted_at"
        }
        
        var querySQL = "SELECT \(selectColumns) FROM \(tableName)"
        
        var parameters: [Any] = []
        
        if let filter = filter {
            var whereConditions: [String] = []
            
            // 默认过滤已删除记录（仅当 deleted_at 列存在时）
            if !includeDeleted && hasDeletedAt {
                whereConditions.append("deleted_at IS NULL")
            }
            
            if let whereClause = filter.whereClause {
                whereConditions.append(whereClause)
                parameters.append(contentsOf: filter.parameters ?? [])
            }
            
            if !whereConditions.isEmpty {
                querySQL += " WHERE " + whereConditions.joined(separator: " AND ")
            }
            
            if let orderBy = filter.orderBy {
                querySQL += " ORDER BY \(orderBy)"
                if !filter.ascending {
                    querySQL += " DESC"
                }
            } else {
                querySQL += " ORDER BY timestamp DESC"
            }
            
            if let limit = filter.limit {
                querySQL += " LIMIT \(limit)"
                if let offset = filter.offset {
                    querySQL += " OFFSET \(offset)"
                }
            }
        } else {
            // 默认过滤已删除记录（仅当 deleted_at 列存在时）
            if !includeDeleted && hasDeletedAt {
                querySQL += " WHERE deleted_at IS NULL"
            }
            querySQL += " ORDER BY timestamp DESC"
        }
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }
            
            if !parameters.isEmpty {
                try self.sqliteCore.bind(statement, parameters: parameters)
            }
            
            var recordings: [AudioRecording] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                if let recording = self.parseRecording(from: statement, hasDeletedAt: hasDeletedAt) {
                    recordings.append(recording)
                }
            }
            
            print("✅ 成功加载 \(recordings.count) 条录音记录")
            return recordings
        }
    }
    
    // MARK: - Additional Methods
    
    // MARK: - Content Type Methods
    
    /// 根据内容类型获取记录
    func getRecordingsByContentType(_ contentType: String) async throws -> [AudioRecording] {
        let filter = FilterCriteria(
            whereClause: "content_type = ?",
            parameters: [contentType]
        )
        return try await list(filter: filter)
    }

    /// 获取思考类型的记录
    func getThinkingRecordings() async throws -> [AudioRecording] {
        return try await getRecordingsByContentType("thinking")
    }

    /// 获取灵感类型的记录
    func getInspirationRecordings() async throws -> [AudioRecording] {
        return try await getRecordingsByContentType("inspiration")
    }

    /// 获取灵感使用统计信息（优化版本）
    func getInspirationUsageStats() async throws -> (used: Int, unused: Int) {
        let sql = """
            SELECT
                COUNT(sa.audio_recording_id) as used,
                COUNT(*) - COUNT(sa.audio_recording_id) as unused
            FROM \(tableName) ar
            LEFT JOIN space_articles sa ON ar.id = sa.audio_recording_id
            WHERE ar.content_type = 'inspiration'
        """

        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }

            guard try self.sqliteCore.step(statement) == SQLITE_ROW else {
                return (used: 0, unused: 0)
            }

            let used = Int(sqlite3_column_int(statement, 0))
            let unused = Int(sqlite3_column_int(statement, 1))

            return (used: used, unused: unused)
        }
    }
    
    /// 更新记录的内容类型
    func updateContentType(id: UUID, contentType: String) async throws -> Bool {
        let updateSQL = "UPDATE \(tableName) SET content_type = ? WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(updateSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [contentType, id.uuidString])
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 内容类型更新成功，ID: \(id.uuidString), 类型: \(contentType)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.updateFailed("Failed to update content type")
            }
        }
    }
    
    // MARK: - Embedding Vector Methods
    
    /// 查找未处理向量化的录音ID列表
    func getRecordingsWithoutEmbeddings() async throws -> [String] {
        let querySQL = """
            SELECT id 
            FROM \(tableName)
            WHERE (embedding_vector IS NULL OR embedding_vector = '')
               AND (title IS NOT NULL AND title != '' OR tags IS NOT NULL)
            ORDER BY created_at DESC
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }
            
            var recordingIds: [String] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                if let idString = sqlite3_column_text(statement, 0) {
                    recordingIds.append(String(cString: idString))
                }
            }
            
            return recordingIds
        }
    }
    
    /// 更新记录的向量嵌入
    func updateEmbeddingVector(id: UUID, embeddingVector: [Float]) async throws -> Bool {
        let vectorData = try JSONEncoder().encode(embeddingVector)
        let vectorString = String(data: vectorData, encoding: .utf8) ?? ""

        let updateSQL = "UPDATE \(tableName) SET embedding_vector = ? WHERE id = ?"

        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(updateSQL)
            defer { self.sqliteCore.finalize(statement) }

            try self.sqliteCore.bind(statement, parameters: [vectorString, id.uuidString])
            let result = try self.sqliteCore.step(statement)

            if result == SQLITE_DONE {
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.updateFailed("Failed to update embedding vector")
            }
        }
    }
    
    /// 获取指定记录的向量嵌入
    func getEmbeddingVector(id: UUID) async throws -> [Float]? {
        let querySQL = "SELECT embedding_vector FROM \(tableName) WHERE id = ?"

        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }

            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            let result = try self.sqliteCore.step(statement)

            guard result == SQLITE_ROW else { return nil }

            if let vectorString = sqlite3_column_text(statement, 0) {
                let vectorStr = String(cString: vectorString)
                if let vectorData = vectorStr.data(using: .utf8),
                   let vector = try? JSONDecoder().decode([Float].self, from: vectorData) {
                    return vector
                }
            }

            return nil
        }
    }
    
    /// 批量更新多个记录的向量嵌入
    func batchUpdateEmbeddingVectors(_ updates: [(id: UUID, vector: [Float])]) async throws -> Bool {
        return try await sqliteCore.performAsync {
            return try self.sqliteCore.transactionInternal {
                for update in updates {
                    let vectorData = try JSONEncoder().encode(update.vector)
                    let vectorString = String(data: vectorData, encoding: .utf8) ?? ""
                    
                    let updateSQL = "UPDATE \(self.tableName) SET embedding_vector = ? WHERE id = ?"
                    let statement = try self.sqliteCore.prepare(updateSQL)
                    defer { self.sqliteCore.finalize(statement) }
                    
                    try self.sqliteCore.bind(statement, parameters: [vectorString, update.id.uuidString])
                    let result = try self.sqliteCore.step(statement)
                    
                    if result != SQLITE_DONE {
                        throw DatabaseError.updateFailed("Failed to update embedding vector for ID: \(update.id.uuidString)")
                    }
                }
                
                print("✅ 批量更新 \(updates.count) 个向量嵌入成功")
                return true
            }
        }
    }
    
    /// 清理无效记录（空ID、空转录等）
    func cleanupInvalidRecords() async throws {
        print("🧹 开始清理数据库中的无效记录...")
        
        let deleteInvalidSQL = """
            DELETE FROM \(tableName) 
            WHERE id IS NULL OR id = '' OR LENGTH(TRIM(id)) = 0
        """
        
        try await sqliteCore.performAsync {
            try self.sqliteCore.executeInternal(deleteInvalidSQL)
            let deletedCount = self.sqliteCore.changes()
            if deletedCount > 0 {
                print("✅ 成功清理 \(deletedCount) 条无效记录")
            } else {
                print("✅ 数据库中没有无效记录，无需清理")
            }
        }
    }
    
    // MARK: - Search Methods
    
    /// 根据标签搜索记录（支持指定内容类型）
    func searchByTags(_ tags: [String], contentType: String? = nil) async throws -> [AudioRecording] {
        var whereConditions = [String]()
        var parameters: [Any] = []
        
        // 标签条件
        if !tags.isEmpty {
            let tagConditions = tags.map { _ in "tags LIKE ?" }.joined(separator: " OR ")
            whereConditions.append("(\(tagConditions))")
            parameters.append(contentsOf: tags.map { "%\($0)%" })
        }
        
        // 内容类型条件
        if let contentType = contentType {
            whereConditions.append("content_type = ?")
            parameters.append(contentType)
        }
        
        let whereClause = whereConditions.isEmpty ? nil : whereConditions.joined(separator: " AND ")
        
        let filter = FilterCriteria(
            whereClause: whereClause,
            parameters: parameters
        )
        
        return try await list(filter: filter)
    }
    
    /// 根据文本内容搜索记录（支持指定内容类型）
    func searchByText(_ searchText: String, contentType: String? = nil) async throws -> [AudioRecording] {
        var whereConditions = ["(transcription LIKE ? OR title LIKE ? OR summary LIKE ? OR original_text LIKE ?)"]
        var parameters: [Any] = ["%\(searchText)%", "%\(searchText)%", "%\(searchText)%", "%\(searchText)%"]
        
        // 内容类型条件
        if let contentType = contentType {
            whereConditions.append("content_type = ?")
            parameters.append(contentType)
        }
        
        let whereClause = whereConditions.joined(separator: " AND ")
        
        let filter = FilterCriteria(
            whereClause: whereClause,
            parameters: parameters
        )
        
        return try await list(filter: filter)
    }
    
    /// 获取最近的记录（支持指定内容类型）
    func getRecent(limit: Int = 20, contentType: String? = nil) async throws -> [AudioRecording] {
        var filter = FilterCriteria(
            limit: limit,
            orderBy: "created_at",
            ascending: false
        )
        
        if let contentType = contentType {
            filter.whereClause = "content_type = ?"
            filter.parameters = [contentType]
        }
        
        return try await list(filter: filter)
    }
    
    // MARK: - Helper Methods
    
    /// 从 SQLite statement 解析统一的录音记录（支持思考和灵感类型）
    private func parseRecording(from statement: OpaquePointer?, hasDeletedAt: Bool = true) -> AudioRecording? {
        guard let statement = statement else { return nil }
        
        guard let idString = sqlite3_column_text(statement, 0),
              let transcription = sqlite3_column_text(statement, 4),
              let summary = sqlite3_column_text(statement, 6),
              let tagsString = sqlite3_column_text(statement, 7),
              let uuid = UUID(uuidString: String(cString: idString)) else {
            return nil
        }
        
        let idStr = String(cString: idString)
        
        // recording_id 在索引1位置，但目前不需要读取
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        let duration = sqlite3_column_double(statement, 3)
        let transcriptionStr = String(cString: transcription)
        
        var titleStr = ""
        if let titleText = sqlite3_column_text(statement, 5) {
            titleStr = String(cString: titleText)
        } else {
            // 如果 title 为空，从 summary 中提取
            titleStr = extractTitleFromSummary(String(cString: summary))
        }
        
        let summaryStr = String(cString: summary)
        
        let tagsData = String(cString: tagsString).data(using: .utf8)
        let tags = (try? JSONDecoder().decode([String].self, from: tagsData ?? Data())) ?? []
        
        // audio_data 已经从表中移除，这里不再读取
        var audioData: Data? = nil
        
        var enrichedContent: String?
        if let enrichedText = sqlite3_column_text(statement, 8) {
            enrichedContent = String(cString: enrichedText)
        }
        
        var polishedText = ""
        if let polishedTextData = sqlite3_column_text(statement, 9) {
            polishedText = String(cString: polishedTextData)
        }
        
        // 新增的字段解析
        var contentType = "thinking"  // 默认为思考类型
        if let contentTypeText = sqlite3_column_text(statement, 10) {
            contentType = String(cString: contentTypeText)
        }
        
        var originalText: String?
        if let originalTextData = sqlite3_column_text(statement, 11) {
            originalText = String(cString: originalTextData)
        }
        
        var embeddingVector: [Float]?
        if let vectorString = sqlite3_column_text(statement, 12) {
            let vectorStr = String(cString: vectorString)
            if let vectorData = vectorStr.data(using: .utf8) {
                embeddingVector = try? JSONDecoder().decode([Float].self, from: vectorData)
            }
        }
        
        // 天气信息字段解析
        var weatherType: String?
        if let weatherTypeText = sqlite3_column_text(statement, 13) {
            weatherType = String(cString: weatherTypeText)
        }
        
        var weatherLocation: String?
        if let weatherLocationText = sqlite3_column_text(statement, 14) {
            weatherLocation = String(cString: weatherLocationText)
        }
        
        // 删除时间字段解析（仅当列存在时）
        var deletedAt: Date?
        if hasDeletedAt {
            let deletedAtValue = sqlite3_column_double(statement, 15)
            if deletedAtValue > 0 {
                deletedAt = Date(timeIntervalSince1970: deletedAtValue)
            }
        }
        
        return AudioRecording(
            id: uuid,
            timestamp: timestamp,
            duration: duration,
            transcription: transcriptionStr,
            title: titleStr,
            summary: summaryStr,
            tags: tags,
            audioData: audioData,
            enrichedContent: enrichedContent,
            polishedText: polishedText,
            contentType: contentType,
            weatherType: weatherType,
            weatherLocation: weatherLocation,
            deletedAt: deletedAt
        )
    }
    
    /// 从 summary 中提取 title
    private func extractTitleFromSummary(_ summary: String) -> String {
        // 如果 summary 包含 "：" 或 "-"，提取前面的部分作为 title
        if let colonRange = summary.range(of: "：") {
            let title = String(summary[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return title
            }
        }
        
        if let dashRange = summary.range(of: " - ") {
            let title = String(summary[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                return title
            }
        }
        
        // 如果找不到分隔符，使用前30个字符作为 title
        if summary.count > 30 {
            return String(summary.prefix(30)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 如果 summary 很短，直接使用作为 title
        return summary.isEmpty ? "未命名录音" : summary
    }
    
    // MARK: - Tag Operations
    
    /// 获取所有不重复的标签
    func getAllUniqueTags() async throws -> [String] {
        let sql = "SELECT DISTINCT tags FROM \(tableName) WHERE tags != '' AND tags IS NOT NULL"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            var allTags: Set<String> = []
            
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                if let tagsString = sqlite3_column_text(statement, 0) {
                    let tags = String(cString: tagsString)
                    // 解析JSON格式的tags
                    if let data = tags.data(using: .utf8),
                       let tagArray = try? JSONSerialization.jsonObject(with: data) as? [String] {
                        for tag in tagArray {
                            let trimmedTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedTag.isEmpty {
                                allTags.insert(trimmedTag)
                            }
                        }
                    }
                }
            }
            
            return Array(allTags).sorted()
        }
    }
    
    // MARK: - Soft Delete Operations
    
    /// 软删除录音（设置 deleted_at 时间戳）
    func softDelete(id: UUID) async throws -> Bool {
        let updateSQL = "UPDATE \(tableName) SET deleted_at = ? WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(updateSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [Date().timeIntervalSince1970, id.uuidString])
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("🗑️ 录音软删除成功，ID: \(id.uuidString)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.updateFailed("Failed to soft delete recording")
            }
        }
    }
    
    /// 恢复已删除的录音（清除 deleted_at）
    func restore(id: UUID) async throws -> Bool {
        let updateSQL = "UPDATE \(tableName) SET deleted_at = NULL WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(updateSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("♻️ 录音恢复成功，ID: \(id.uuidString)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.updateFailed("Failed to restore recording")
            }
        }
    }
    
    /// 获取所有已删除的录音（回收站）
    func listDeleted() async throws -> [AudioRecording] {
        let querySQL = """
            SELECT id, recording_id, timestamp, duration, transcription, title, summary, tags, 
                   enriched_content, polished_text, content_type, original_text, embedding_vector, weather_type, weather_location, deleted_at
            FROM \(tableName)
            WHERE deleted_at IS NOT NULL
            ORDER BY deleted_at DESC
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }
            
            var recordings: [AudioRecording] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                if let recording = self.parseRecording(from: statement) {
                    recordings.append(recording)
                }
            }
            
            print("🗑️ 回收站加载 \(recordings.count) 条已删除录音")
            return recordings
        }
    }
    
    /// 清理超过指定天数的已删除记录（永久删除）
    func cleanupExpiredDeletedRecords(olderThanDays: Int = 7) async throws -> Int {
        let expirationDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date())!
        let deleteSQL = "DELETE FROM \(tableName) WHERE deleted_at IS NOT NULL AND deleted_at < ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(deleteSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [expirationDate.timeIntervalSince1970])
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                let deletedCount = Int(self.sqliteCore.changes())
                if deletedCount > 0 {
                    print("🧹 已永久删除 \(deletedCount) 条过期录音（超过 \(olderThanDays) 天）")
                }
                return deletedCount
            } else {
                throw DatabaseError.deleteFailed("Failed to cleanup expired records")
            }
        }
    }
    
    /// 永久删除所有已软删除的记录（清空回收站）
    func permanentlyDeleteAllSoftDeleted() async throws -> Int {
        let deleteSQL = "DELETE FROM \(tableName) WHERE deleted_at IS NOT NULL"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(deleteSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                let deletedCount = Int(self.sqliteCore.changes())
                print("🗑️ 回收站已清空，永久删除 \(deletedCount) 条录音")
                return deletedCount
            } else {
                throw DatabaseError.deleteFailed("Failed to empty trash")
            }
        }
    }
    
    /// 获取回收站中的录音数量
    func getDeletedCount() async throws -> Int {
        let countSQL = "SELECT COUNT(*) FROM \(tableName) WHERE deleted_at IS NOT NULL"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(countSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let result = try self.sqliteCore.step(statement)
            guard result == SQLITE_ROW else {
                throw DatabaseError.queryFailed("Failed to get deleted count")
            }
            
            return Int(sqlite3_column_int(statement, 0))
        }
    }
}