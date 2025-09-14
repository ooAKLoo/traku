//
//  RecordingDataRepository.swift
//  raku
//
//  原始录音数据仓库 - 用于管理独立的录音表
//

import Foundation
import SQLite3

/// 原始录音数据结构
struct RawRecordingData {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let audioData: Data?
    let createdAt: Date
}

/// 录音数据仓库 - 管理原始录音表
class RecordingDataRepository {
    
    private let tableName = "recordings"
    private let sqliteCore: SQLiteCore
    
    init(sqliteCore: SQLiteCore) {
        self.sqliteCore = sqliteCore
    }
    
    func createTable() async throws {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS \(tableName) (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                duration REAL NOT NULL,
                audio_data BLOB,
                created_at REAL NOT NULL DEFAULT (julianday('now'))
            );
            
            CREATE INDEX IF NOT EXISTS idx_recordings_timestamp ON \(tableName) (timestamp);
        """
        
        try sqliteCore.execute(createTableSQL)
        print("✅ 创建或验证表: \(tableName)")
    }
    
    func create(_ item: RawRecordingData) async throws -> Bool {
        let sql = """
            INSERT INTO \(tableName) (id, timestamp, duration, audio_data, created_at)
            VALUES (?, ?, ?, ?, ?)
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [
                item.id.uuidString,
                item.timestamp.timeIntervalSince1970,
                item.duration,
                item.audioData ?? NSNull(),
                item.createdAt.timeIntervalSince1970
            ])
            
            let result = try self.sqliteCore.step(statement)
            return result == SQLITE_DONE
        }
    }
    
    func read(id: UUID) async throws -> RawRecordingData? {
        let sql = "SELECT * FROM \(tableName) WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            
            if try self.sqliteCore.step(statement) == SQLITE_ROW {
                return self.parseRecordingData(from: statement)
            }
            return nil
        }
    }
    
    func update(_ item: RawRecordingData) async throws -> Bool {
        let sql = """
            UPDATE \(tableName)
            SET timestamp = ?, duration = ?, audio_data = ?
            WHERE id = ?
        """
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [
                item.timestamp.timeIntervalSince1970,
                item.duration,
                item.audioData ?? NSNull(),
                item.id.uuidString
            ])
            
            let result = try self.sqliteCore.step(statement)
            return result == SQLITE_DONE && self.sqliteCore.changes() > 0
        }
    }
    
    func delete(id: UUID) async throws -> Bool {
        let sql = "DELETE FROM \(tableName) WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [id.uuidString])
            
            let result = try self.sqliteCore.step(statement)
            return result == SQLITE_DONE && self.sqliteCore.changes() > 0
        }
    }
    
    func list() async throws -> [RawRecordingData] {
        let sql = "SELECT * FROM \(tableName) ORDER BY timestamp DESC"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            var recordings: [RawRecordingData] = []
            
            while try self.sqliteCore.step(statement) == SQLITE_ROW {
                if let recording = self.parseRecordingData(from: statement) {
                    recordings.append(recording)
                }
            }
            
            return recordings
        }
    }
    
    /// 获取录音的音频数据
    func getAudioData(for recordingId: UUID) async throws -> Data? {
        let sql = "SELECT audio_data FROM \(tableName) WHERE id = ?"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            try self.sqliteCore.bind(statement, parameters: [recordingId.uuidString])
            
            if try self.sqliteCore.step(statement) == SQLITE_ROW {
                if sqlite3_column_type(statement, 0) != SQLITE_NULL {
                    let bytes = sqlite3_column_blob(statement, 0)
                    let length = sqlite3_column_bytes(statement, 0)
                    if let bytes = bytes, length > 0 {
                        return Data(bytes: bytes, count: Int(length))
                    }
                }
            }
            return nil
        }
    }
    
    
    func count() async throws -> Int {
        let sql = "SELECT COUNT(*) FROM \(tableName)"
        
        return try await sqliteCore.performAsync {
            let statement = try self.sqliteCore.prepare(sql)
            defer { self.sqliteCore.finalize(statement) }
            
            let result = try self.sqliteCore.step(statement)
            guard result == SQLITE_ROW else {
                throw DatabaseError.queryFailed("Failed to get count")
            }
            
            return Int(sqlite3_column_int(statement, 0))
        }
    }
    
    // MARK: - Private Methods
    
    private func parseRecordingData(from statement: OpaquePointer?) -> RawRecordingData? {
        guard let statement = statement else { return nil }
        
        guard let idString = sqlite3_column_text(statement, 0),
              let id = UUID(uuidString: String(cString: idString)) else {
            return nil
        }
        
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
        let duration = sqlite3_column_double(statement, 2)
        
        var audioData: Data?
        if sqlite3_column_type(statement, 3) != SQLITE_NULL {
            let bytes = sqlite3_column_blob(statement, 3)
            let length = sqlite3_column_bytes(statement, 3)
            if let bytes = bytes, length > 0 {
                audioData = Data(bytes: bytes, count: Int(length))
            }
        }
        
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
        
        return RawRecordingData(
            id: id,
            timestamp: timestamp,
            duration: duration,
            audioData: audioData,
            createdAt: createdAt
        )
    }
}