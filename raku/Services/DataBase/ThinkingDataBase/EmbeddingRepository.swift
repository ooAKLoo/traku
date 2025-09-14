//
//  EmbeddingRepository.swift
//  raku
//
//  Created by Assistant on Repository Pattern Refactor
//

import Foundation
import SQLite3

/// 向量嵌入数据仓库实现
class EmbeddingRepository: Repository {
    typealias Model = EmbeddingData
    
    private let sqliteCore: SQLiteCore
    private let tableName = "embeddings"
    
    init(sqliteCore: SQLiteCore) {
        self.sqliteCore = sqliteCore
    }
    
    // MARK: - Table Management
    
    /// 创建向量表
    func createTable() async throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(tableName) (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                recording_id TEXT NOT NULL,
                embedding_type TEXT NOT NULL,
                embedding_vector TEXT NOT NULL,
                created_at REAL NOT NULL DEFAULT (julianday('now')),
                FOREIGN KEY (recording_id) REFERENCES audio_recordings(id) ON DELETE CASCADE,
                UNIQUE(recording_id, embedding_type)
            );
        """
        
        let createIndexSQL = """
            CREATE INDEX IF NOT EXISTS idx_embeddings_recording_id ON \(tableName)(recording_id);
        """
        
        try await sqliteCore.performAsync {
            try self.sqliteCore.executeInternal(createTableSQL)
            try self.sqliteCore.executeInternal(createIndexSQL)
            print("✅ 向量表和索引创建成功")
        }
    }
    
    // MARK: - Repository Protocol Implementation
    
    func create(_ model: EmbeddingData) async throws -> Bool {
        let insertSQL = """
            INSERT OR REPLACE INTO \(tableName) (recording_id, embedding_type, embedding_vector, created_at)
            VALUES (?, ?, ?, ?)
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(insertSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let modelDict = model.toDict()
            let parameters: [Any] = [
                modelDict["recording_id"] as Any,
                modelDict["embedding_type"] as Any,
                modelDict["embedding_vector"] as Any,
                modelDict["created_at"] as Any
            ]
            
            try self.sqliteCore.bind(statement, parameters: parameters)
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 向量保存成功，录音ID: \(model.recordingId), 类型: \(model.embeddingType)")
                return true
            } else {
                throw DatabaseError.insertFailed("Failed to insert embedding")
            }
        }
    }
    
    func read(id: EmbeddingData.ID) async throws -> EmbeddingData? {
        let querySQL = """
            SELECT id, recording_id, embedding_type, embedding_vector, created_at
            FROM \(tableName)
            WHERE id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id])
            let result = try self.sqliteCore.step(statement)
            
            guard result == SQLITE_ROW else { return nil }
            
            return self.parseEmbedding(from: statement)
        }
    }
    
    func update(_ model: EmbeddingData) async throws -> Bool {
        guard model.id > 0 else {
            throw DatabaseError.invalidData("Valid Embedding ID is required for update")
        }
        
        let updateSQL = """
            UPDATE \(tableName) 
            SET recording_id = ?, embedding_type = ?, embedding_vector = ?
            WHERE id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(updateSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            let modelDict = model.toDict()
            let parameters: [Any] = [
                modelDict["recording_id"] as Any,
                modelDict["embedding_type"] as Any,
                modelDict["embedding_vector"] as Any,
                model.id
            ]
            
            try self.sqliteCore.bind(statement, parameters: parameters)
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 向量更新成功，ID: \(model.id)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.updateFailed("Failed to update embedding")
            }
        }
    }
    
    func delete(id: EmbeddingData.ID) async throws -> Bool {
        let deleteSQL = "DELETE FROM \(tableName) WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(deleteSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id])
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                print("✅ 向量删除成功，ID: \(id)")
                return self.sqliteCore.changes() > 0
            } else {
                throw DatabaseError.deleteFailed("Failed to delete embedding")
            }
        }
    }
    
    func saveOrUpdate(_ model: EmbeddingData) async throws -> Bool {
        // 对于 embedding，使用 INSERT OR REPLACE 策略
        return try await create(model)
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
    
    func list(filter: FilterCriteria? = nil) async throws -> [EmbeddingData] {
        var querySQL = """
            SELECT id, recording_id, embedding_type, embedding_vector, created_at
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
            
            var embeddings: [EmbeddingData] = []
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                if let embedding = self.parseEmbedding(from: statement) {
                    embeddings.append(embedding)
                }
            }
            
            return embeddings
        }
    }
    
    // MARK: - Additional Methods
    
    /// 获取特定录音的所有向量数据
    func getEmbeddings(for recordingId: String) async throws -> [String: [Float]] {
        let querySQL = """
            SELECT embedding_type, embedding_vector
            FROM \(tableName)
            WHERE recording_id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(querySQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [recordingId])
            
            var embeddings: [String: [Float]] = [:]
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                guard let typeString = sqlite3_column_text(statement, 0),
                      let vectorString = sqlite3_column_text(statement, 1) else { continue }
                
                let type = String(cString: typeString)
                let vectorStr = String(cString: vectorString)
                
                if let vectorData = vectorStr.data(using: .utf8),
                   let vector = try? JSONDecoder().decode([Float].self, from: vectorData) {
                    embeddings[type] = vector
                }
            }
            
            return embeddings
        }
    }
    
    /// 批量保存向量数据
    func saveEmbeddings(_ embeddingResult: EmbeddingResult) async throws -> Bool {
        return try await sqliteCore.performAsync {
            return try self.sqliteCore.transaction {
                // 保存标题向量
                if let titleEmbedding = embeddingResult.titleEmbedding {
                    let titleData = EmbeddingData(
                        recordingId: embeddingResult.recordingId,
                        embeddingType: "title",
                        embeddingVector: titleEmbedding
                    )
                    if !(try self.createSync(titleData)) {
                        throw DatabaseError.insertFailed("Failed to save title embedding")
                    }
                }
                
                // 保存标签向量
                for (index, tagEmbedding) in embeddingResult.tagsEmbeddings.enumerated() {
                    let tagData = EmbeddingData(
                        recordingId: embeddingResult.recordingId,
                        embeddingType: "tag_\(index)",
                        embeddingVector: tagEmbedding
                    )
                    if !(try self.createSync(tagData)) {
                        throw DatabaseError.insertFailed("Failed to save tag embedding \(index)")
                    }
                }
                
                // 保存文本向量
                if let textEmbedding = embeddingResult.polishedTextEmbedding {
                    let textData = EmbeddingData(
                        recordingId: embeddingResult.recordingId,
                        embeddingType: "polished_text",
                        embeddingVector: textEmbedding
                    )
                    if !(try self.createSync(textData)) {
                        throw DatabaseError.insertFailed("Failed to save polished text embedding")
                    }
                }
                
                print("✅ 成功保存录音 \(embeddingResult.recordingId) 的所有向量数据")
                return true
            }
        }
    }
    
    /// 删除特定录音的所有向量数据
    func deleteEmbeddings(for recordingId: String) async throws -> Bool {
        let deleteSQL = "DELETE FROM \(tableName) WHERE recording_id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(deleteSQL)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [recordingId])
            let result = try self.sqliteCore.step(statement)
            
            if result == SQLITE_DONE {
                let deletedCount = self.sqliteCore.changes()
                print("✅ 删除录音 \(recordingId) 的 \(deletedCount) 条向量记录")
                return deletedCount > 0
            } else {
                throw DatabaseError.deleteFailed("Failed to delete embeddings for recording")
            }
        }
    }
    
    /// 获取特定类型的向量数据
    func getEmbeddings(type: String) async throws -> [EmbeddingData] {
        let filter = FilterCriteria(
            whereClause: "embedding_type = ?",
            parameters: [type]
        )
        
        return try await list(filter: filter)
    }
    
    // MARK: - Helper Methods
    
    /// 同步版本的创建方法（用于事务中）
    private func createSync(_ model: EmbeddingData) throws -> Bool {
        let insertSQL = """
            INSERT OR REPLACE INTO \(tableName) (recording_id, embedding_type, embedding_vector, created_at)
            VALUES (?, ?, ?, ?)
        """
        
        let statement = try sqliteCore.prepare(insertSQL)
        defer { sqliteCore.finalize(statement) }
        
        let modelDict = model.toDict()
        let parameters: [Any] = [
            modelDict["recording_id"] as Any,
            modelDict["embedding_type"] as Any,
            modelDict["embedding_vector"] as Any,
            modelDict["created_at"] as Any
        ]
        
        try sqliteCore.bind(statement, parameters: parameters)
        let result = try sqliteCore.step(statement)
        
        return result == SQLITE_DONE
    }
    
    /// 从 SQLite statement 解析向量记录
    private func parseEmbedding(from statement: OpaquePointer?) -> EmbeddingData? {
        guard let statement = statement else { return nil }
        
        guard let recordingIdString = sqlite3_column_text(statement, 1),
              let embeddingTypeString = sqlite3_column_text(statement, 2),
              let vectorString = sqlite3_column_text(statement, 3) else {
            return nil
        }
        
        let id = sqlite3_column_int64(statement, 0)
        let recordingId = String(cString: recordingIdString)
        let embeddingType = String(cString: embeddingTypeString)
        let vectorStr = String(cString: vectorString)
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
        
        // 解析向量数据
        let vectorData = vectorStr.data(using: .utf8)
        let embeddingVector = (try? JSONDecoder().decode([Float].self, from: vectorData ?? Data())) ?? []
        
        return EmbeddingData(
            id: id,
            recordingId: recordingId,
            embeddingType: embeddingType,
            embeddingVector: embeddingVector,
            createdAt: createdAt
        )
    }
}

// MARK: - Supporting Types

/// 向量化结果结构体
struct EmbeddingResult {
    let recordingId: String
    let titleEmbedding: [Float]?
    let tagsEmbeddings: [[Float]]
    let polishedTextEmbedding: [Float]?
}