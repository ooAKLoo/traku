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
    
    /// 创建录音表
    func createTable() async throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(tableName) (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                duration REAL NOT NULL,
                transcription TEXT NOT NULL,
                title TEXT,
                summary TEXT NOT NULL,
                tags TEXT NOT NULL,
                audio_data BLOB,
                enriched_content TEXT,
                polished_text TEXT,
                created_at REAL NOT NULL DEFAULT (julianday('now'))
            );
        """
        
        try await sqliteCore.performAsync {
            try self.sqliteCore.executeInternal(createTableSQL)
            print("✅ 录音表创建成功")
        }
        
        // 兼容性：添加可能缺失的列
        await addMissingColumns()
    }
    
    /// 添加缺失的列（兼容旧数据库）
    private func addMissingColumns() async {
        let columnsToAdd = [
            "ALTER TABLE \(tableName) ADD COLUMN title TEXT;",
            "ALTER TABLE \(tableName) ADD COLUMN polished_text TEXT;"
        ]
        
        for sql in columnsToAdd {
            do {
                try await sqliteCore.performAsync {
                    try self.sqliteCore.executeInternal(sql)
                }
            } catch {
                // 忽略错误（列可能已存在）
            }
        }
    }
    
    // MARK: - Repository Protocol Implementation
    
    func create(_ model: AudioRecording) async throws -> Bool {
        let insertSQL = """
            INSERT INTO \(tableName) (id, timestamp, duration, transcription, title, summary, tags, audio_data, enriched_content, polished_text, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(insertSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let modelDict = model.toDict()
            let parameters: [Any] = [
                modelDict["id"] as Any,
                modelDict["timestamp"] as Any,
                modelDict["duration"] as Any,
                modelDict["transcription"] as Any,
                modelDict["title"] as Any,
                modelDict["summary"] as Any,
                modelDict["tags"] as Any,
                modelDict["audio_data"] ?? NSNull(),
                modelDict["enriched_content"] ?? NSNull(),
                modelDict["polished_text"] ?? NSNull(),
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
            SELECT id, timestamp, duration, transcription, title, summary, tags, 
                   audio_data, enriched_content, polished_text
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
            SET timestamp = ?, duration = ?, transcription = ?, title = ?, summary = ?, 
                tags = ?, audio_data = ?, enriched_content = ?, polished_text = ?
            WHERE id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(updateSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let modelDict = model.toDict()
            let parameters: [Any] = [
                modelDict["timestamp"] as Any,
                modelDict["duration"] as Any,
                modelDict["transcription"] as Any,
                modelDict["title"] as Any,
                modelDict["summary"] as Any,
                modelDict["tags"] as Any,
                modelDict["audio_data"] ?? NSNull(),
                modelDict["enriched_content"] ?? NSNull(),
                modelDict["polished_text"] ?? NSNull(),
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
    
    func list(filter: FilterCriteria? = nil) async throws -> [AudioRecording] {
        var querySQL = """
            SELECT id, timestamp, duration, transcription, title, summary, tags, 
                   audio_data, enriched_content, polished_text
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
                querySQL += " ORDER BY timestamp DESC"
            }
            
            if let limit = filter.limit {
                querySQL += " LIMIT \(limit)"
                if let offset = filter.offset {
                    querySQL += " OFFSET \(offset)"
                }
            }
        } else {
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
                if let recording = self.parseRecording(from: statement) {
                    recordings.append(recording)
                }
            }
            
            print("✅ 成功加载 \(recordings.count) 条录音记录")
            return recordings
        }
    }
    
    // MARK: - Additional Methods
    
    /// 查找未处理向量化的录音ID列表
    func getRecordingsWithoutEmbeddings() async throws -> [String] {
        let querySQL = """
            SELECT DISTINCT r.id 
            FROM \(tableName) r
            LEFT JOIN embeddings e ON (r.id = e.recording_id AND e.embedding_type = 'title')
            WHERE e.recording_id IS NULL
               AND (r.title IS NOT NULL AND r.title != '' OR r.tags IS NOT NULL)
            ORDER BY r.created_at DESC
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
    
    // MARK: - Helper Methods
    
    /// 从 SQLite statement 解析录音记录
    private func parseRecording(from statement: OpaquePointer?) -> AudioRecording? {
        guard let statement = statement else { return nil }
        
        guard let idString = sqlite3_column_text(statement, 0),
              let transcription = sqlite3_column_text(statement, 3),
              let summary = sqlite3_column_text(statement, 5),
              let tagsString = sqlite3_column_text(statement, 6),
              let uuid = UUID(uuidString: String(cString: idString)) else {
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        let duration = sqlite3_column_double(statement, 2)
        let transcriptionStr = String(cString: transcription)
        
        var titleStr = ""
        if let titleText = sqlite3_column_text(statement, 4) {
            titleStr = String(cString: titleText)
        } else {
            // 如果 title 为空，从 summary 中提取
            titleStr = extractTitleFromSummary(String(cString: summary))
        }
        
        let summaryStr = String(cString: summary)
        
        let tagsData = String(cString: tagsString).data(using: .utf8)
        let tags = (try? JSONDecoder().decode([String].self, from: tagsData ?? Data())) ?? []
        
        var audioData: Data?
        if let audioBlob = sqlite3_column_blob(statement, 7) {
            let audioSize = sqlite3_column_bytes(statement, 7)
            audioData = Data(bytes: audioBlob, count: Int(audioSize))
        }
        
        var enrichedContent: String?
        if let enrichedText = sqlite3_column_text(statement, 8) {
            enrichedContent = String(cString: enrichedText)
        }
        
        var polishedText = ""
        if let polishedTextData = sqlite3_column_text(statement, 9) {
            polishedText = String(cString: polishedTextData)
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
            polishedText: polishedText
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
}