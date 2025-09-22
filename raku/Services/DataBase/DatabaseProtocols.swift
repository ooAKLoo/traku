//
//  DatabaseProtocols.swift
//  raku
//
//  Created by Assistant on Repository Pattern Refactor
//

import Foundation
import SQLite3

// MARK: - 数据库模型协议
protocol DatabaseModel {
    associatedtype ID
    var id: ID { get }
    
    /// 将模型转换为字典，用于数据库操作
    func toDict() -> [String: Any]
    
    /// 从字典创建模型实例
    static func fromDict(_ dict: [String: Any]) -> Self?
}

// MARK: - Repository 基础协议
protocol Repository {
    associatedtype Model: DatabaseModel
    
    /// 创建新记录
    func create(_ model: Model) async throws -> Bool
    
    /// 根据ID读取记录
    func read(id: Model.ID) async throws -> Model?
    
    /// 更新记录
    func update(_ model: Model) async throws -> Bool
    
    /// 删除记录
    func delete(id: Model.ID) async throws -> Bool
    
    /// 保存或更新记录（如果存在则更新，否则创建）
    func saveOrUpdate(_ model: Model) async throws -> Bool
    
    /// 获取记录总数
    func count() async throws -> Int
    
    /// 列出所有记录
    func list(filter: FilterCriteria?) async throws -> [Model]
}

// MARK: - 查询过滤条件
struct FilterCriteria {
    var limit: Int?
    var offset: Int?
    var orderBy: String?
    var ascending: Bool
    var whereClause: String?
    var parameters: [Any]?
    
    init(limit: Int? = nil, 
         offset: Int? = nil, 
         orderBy: String? = nil, 
         ascending: Bool = true,
         whereClause: String? = nil,
         parameters: [Any]? = nil) {
        self.limit = limit
        self.offset = offset
        self.orderBy = orderBy
        self.ascending = ascending
        self.whereClause = whereClause
        self.parameters = parameters
    }
}

// MARK: - 数据库错误类型
enum DatabaseError: Error {
    case connectionFailed(String)
    case queryFailed(String)
    case insertFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case dataNotFound
    case invalidData(String)
    case transactionFailed(String)
    case preparationFailed(String)
}

// MARK: - SQLite 操作协议
protocol SQLiteOperations {
    var db: OpaquePointer? { get }
    
    /// 执行 SQL 语句
    func execute(_ sql: String) throws
    
    /// 准备 SQL 语句
    func prepare(_ sql: String) throws -> OpaquePointer?
    
    /// 绑定参数到 prepared statement
    func bind(_ statement: OpaquePointer?, parameters: [Any]) throws
    
    /// 执行 prepared statement
    func step(_ statement: OpaquePointer?) throws -> Int32
    
    /// 释放 statement
    func finalize(_ statement: OpaquePointer?)
}