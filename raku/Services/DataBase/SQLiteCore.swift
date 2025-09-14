//
//  SQLiteCore.swift
//  raku
//
//  Created by Assistant on Repository Pattern Refactor
//

import Foundation
import SQLite3

// SQLite3 destructor type constants
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// SQLite 核心操作类
class SQLiteCore: SQLiteOperations {
    
    private(set) var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.raku.database.core", qos: .userInitiated)
    
    init(dbPath: String) {
        self.dbPath = dbPath
    }
    
    deinit {
        close()
    }
    
    // MARK: - Connection Management
    
    /// 打开数据库连接
    func open() throws {
        try dbQueue.sync {
            guard db == nil else { return }
            
            let result = sqlite3_open(dbPath, &db)
            guard result == SQLITE_OK else {
                let message = String(cString: sqlite3_errmsg(db))
                db = nil
                throw DatabaseError.connectionFailed("Failed to open database: \(message)")
            }
            
            // 启用WAL模式
            try enableWALMode()
            
            print("✅ SQLiteCore: 数据库连接成功")
        }
    }
    
    /// 关闭数据库连接
    func close() {
        dbQueue.sync {
            if db != nil {
                sqlite3_close(db)
                db = nil
                print("✅ SQLiteCore: 数据库连接已关闭")
            }
        }
    }
    
    /// 启用WAL模式
    private func enableWALMode() throws {
        let walSQL = "PRAGMA journal_mode=WAL;"
        let result = sqlite3_exec(db, walSQL, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw DatabaseError.queryFailed("Failed to enable WAL mode")
        }
    }
    
    // MARK: - SQLiteOperations Protocol Implementation
    
    /// 执行 SQL 语句
    func execute(_ sql: String) throws {
        try dbQueue.sync {
            try executeInternal(sql)
        }
    }
    
    /// 内部执行方法，不使用队列同步（已在队列中时使用）
    internal func executeInternal(_ sql: String) throws {
        guard db != nil else {
            throw DatabaseError.connectionFailed("Database not connected")
        }
        
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed("SQL execution failed: \(message)")
        }
    }
    
    /// 准备 SQL 语句
    func prepare(_ sql: String) throws -> OpaquePointer? {
        guard db != nil else {
            throw DatabaseError.connectionFailed("Database not connected")
        }
        
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        
        guard result == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.queryFailed("SQL preparation failed: \(message)")
        }
        
        return statement
    }
    
    /// 绑定参数到 prepared statement
    func bind(_ statement: OpaquePointer?, parameters: [Any]) throws {
        guard let statement = statement else { return }
        
        for (index, parameter) in parameters.enumerated() {
            let position = Int32(index + 1)
            
            switch parameter {
            case let string as String:
                sqlite3_bind_text(statement, position, (string as NSString).utf8String, -1, SQLITE_TRANSIENT)
            case let int as Int:
                sqlite3_bind_int(statement, position, Int32(int))
            case let int64 as Int64:
                sqlite3_bind_int64(statement, position, int64)
            case let double as Double:
                sqlite3_bind_double(statement, position, double)
            case let data as Data:
                data.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, position, bytes.bindMemory(to: Int8.self).baseAddress, Int32(data.count), nil)
                }
            case is NSNull:
                sqlite3_bind_null(statement, position)
            default:
                sqlite3_bind_null(statement, position)
            }
        }
    }
    
    /// 执行 prepared statement
    func step(_ statement: OpaquePointer?) throws -> Int32 {
        guard let statement = statement else {
            throw DatabaseError.queryFailed("Statement is nil")
        }
        return sqlite3_step(statement)
    }
    
    /// 释放 statement
    func finalize(_ statement: OpaquePointer?) {
        sqlite3_finalize(statement)
    }
    
    // MARK: - Transaction Support
    
    /// 执行事务
    func transaction<T>(_ operation: () throws -> T) throws -> T {
        return try dbQueue.sync {
            try transactionInternal(operation)
        }
    }
    
    /// 内部事务方法，不使用队列同步（已在队列中时使用）
    internal func transactionInternal<T>(_ operation: () throws -> T) throws -> T {
        try executeInternal("BEGIN TRANSACTION")
        
        do {
            let result = try operation()
            try executeInternal("COMMIT")
            return result
        } catch {
            try executeInternal("ROLLBACK")
            throw error
        }
    }
    
    // MARK: - Utility Methods
    
    /// 获取最后插入的行ID
    func lastInsertRowID() -> Int64 {
        return sqlite3_last_insert_rowid(db)
    }
    
    /// 获取受影响的行数
    func changes() -> Int32 {
        return sqlite3_changes(db)
    }
    
    /// 检查表是否存在
    func tableExists(_ tableName: String) throws -> Bool {
        let sql = "SELECT name FROM sqlite_master WHERE type='table' AND name=?"
        let statement = try prepare(sql)
        defer { finalize(statement) }
        
        try bind(statement, parameters: [tableName])
        let result = try step(statement)
        
        return result == SQLITE_ROW
    }
    
    /// 获取表的列信息
    func getTableSchema(_ tableName: String) throws -> [(name: String, type: String, notNull: Bool, primaryKey: Bool)] {
        let sql = "PRAGMA table_info(\(tableName))"
        let statement = try prepare(sql)
        defer { finalize(statement) }
        
        var columns: [(name: String, type: String, notNull: Bool, primaryKey: Bool)] = []
        
        while try step(statement) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(statement, 1))
            let type = String(cString: sqlite3_column_text(statement, 2))
            let notNull = sqlite3_column_int(statement, 3) == 1
            let primaryKey = sqlite3_column_int(statement, 5) == 1
            
            columns.append((name: name, type: type, notNull: notNull, primaryKey: primaryKey))
        }
        
        return columns
    }
    
    // MARK: - Async Support
    
    /// 在后台队列执行数据库操作
    func performAsync<T>(_ operation: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            dbQueue.async {
                do {
                    let result = try operation()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 在同步队列执行数据库操作
    func performSync<T>(_ operation: () throws -> T) throws -> T {
        return try dbQueue.sync {
            try operation()
        }
    }
}