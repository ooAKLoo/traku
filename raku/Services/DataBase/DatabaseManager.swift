//
//  DatabaseManager.swift
//  raku
//
//  Refactored with Repository Pattern by Assistant
//

import Foundation

/// 数据库管理器 - 统一路由层
class DatabaseManager {
    
    // MARK: - Properties
    
    static let shared = DatabaseManager()
    
    internal let sqliteCore: SQLiteCore
    internal let recordingRepository: RecordingRepository
    internal let recordingDataRepository: RecordingDataRepository
    
    // MARK: - Initialization
    
    private init() {
        // 初始化数据库核心
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("RakuDatabase.sqlite")
        
        self.sqliteCore = SQLiteCore(dbPath: fileURL.path)
        
        // 初始化各个仓库
        self.recordingRepository = RecordingRepository(sqliteCore: sqliteCore)
        self.recordingDataRepository = RecordingDataRepository(sqliteCore: sqliteCore)
        
        // 初始化数据库
        Task {
            await initializeDatabase()
        }
    }
    
    deinit {
        sqliteCore.close()
    }
    
    // MARK: - Database Initialization
    
    /// 初始化数据库
    private func initializeDatabase() async {
        do {
            try sqliteCore.open()
            
            // 创建所有表
            try await recordingDataRepository.createTable()  // 先创建录音数据表
            try await recordingRepository.createTable()
            
            // 初始统计
            let recordingDataCount = try await recordingDataRepository.count()
            let recordingCount = try await recordingRepository.count()
            let thinkingCount = try await recordingRepository.getThinkingRecordings().count
            let inspirationCount = try await recordingRepository.getInspirationRecordings().count
            
            print("📊 数据库初始化完成:")
            print("  - 原始录音数据: \(recordingDataCount)")
            print("  - 录音记录总数: \(recordingCount)")
            print("  - 思考类型记录: \(thinkingCount)")
            print("  - 灵感类型记录: \(inspirationCount)")
            
            // 清理无效记录
            if recordingCount > 0 {
                try await recordingRepository.cleanupInvalidRecords()
            }
            
        } catch {
            print("❌ 数据库初始化失败: \(error)")
        }
    }
    
    // MARK: - Recording Data Operations (原始录音表)
    
    /// 保存原始录音数据
    func saveRecordingData(_ recordingData: RawRecordingData) -> Bool {
        return performSync {
            try await self.recordingDataRepository.create(recordingData)
        }
    }
    
    /// 获取录音的音频数据
    func getAudioData(for recordingId: UUID) -> Data? {
        return performSyncOptional {
            try await self.recordingDataRepository.getAudioData(for: recordingId)
        }
    }
    
    /// 获取完整的录音记录（包含音频数据）
    func getCompleteRecording(by id: String) -> AudioRecording? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        
        return performSyncOptional {
            // 先获取录音分析数据
            var recording = try await self.recordingRepository.read(id: uuid)
            if recording != nil {
                // 然后获取音频数据
                let audioData = try await self.recordingDataRepository.getAudioData(for: uuid)
                recording?.audioData = audioData
            }
            
            return recording
        }
    }
    
    
    // MARK: - Recording Operations (分析结果表)
    
    /// 保存录音记录
    func saveRecording(_ recording: AudioRecording) -> Bool {
        return performSync {
            try await self.recordingRepository.create(recording)
        }
    }
    
    /// 保存或更新录音记录
    func saveOrUpdateRecording(_ recording: AudioRecording) -> Bool {
        return performSync {
            try await self.recordingRepository.saveOrUpdate(recording)
        }
    }
    
    /// 更新录音记录
    func updateRecording(_ recording: AudioRecording) -> Bool {
        return performSync {
            try await self.recordingRepository.update(recording)
        }
    }
    
    /// 加载所有录音记录
    func loadRecordings() -> [AudioRecording] {
        return performSync {
            return try await self.recordingRepository.list()
        }
    }
    
    /// 根据ID获取录音记录
    func getRecording(by id: String) -> AudioRecording? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        
        return performSyncOptional {
            try await self.recordingRepository.read(id: uuid)
        }
    }
    
    /// 删除录音记录
    func deleteRecording(id: UUID) -> Bool {
        return performSync {
            return try await self.recordingRepository.delete(id: id)
        }
    }
    
    /// 获取录音记录总数
    func getRecordingCount() -> Int {
        return performSync {
            try await self.recordingRepository.count()
        }
    }
    
    // MARK: - Content Type Operations
    
    /// 获取思考类型的记录
    func getThinkingRecordings() -> [AudioRecording] {
        return performSync {
            try await self.recordingRepository.getThinkingRecordings()
        }
    }
    
    /// 获取灵感类型的记录
    func getInspirationRecordings() -> [AudioRecording] {
        return performSync {
            try await self.recordingRepository.getInspirationRecordings()
        }
    }
    
    /// 更新记录的内容类型
    func updateContentType(id: UUID, contentType: String) -> Bool {
        return performSync {
            try await self.recordingRepository.updateContentType(id: id, contentType: contentType)
        }
    }
    
    /// 获取灵感数量（兼容性方法）
    func getInspirationCount() -> Int {
        return performSync {
            print("dataprocess--- DatabaseManager.getInspirationCount(): 开始查询")
            let inspirations = try await self.recordingRepository.getInspirationRecordings()
            print("dataprocess--- DatabaseManager.getInspirationCount(): 返回 \(inspirations.count) 条灵感记录")
            return inspirations.count
        }
    }
    
    // MARK: - Embedding Operations
    
    /// 更新记录的向量嵌入
    func updateEmbeddingVector(id: UUID, embeddingVector: [Float]) -> Bool {
        return performSync {
            try await self.recordingRepository.updateEmbeddingVector(id: id, embeddingVector: embeddingVector)
        }
    }
    
    /// 获取记录的向量嵌入
    func getEmbeddingVector(id: UUID) -> [Float]? {
        return performSyncOptional {
            try await self.recordingRepository.getEmbeddingVector(id: id)
        }
    }
    
    /// 获取未处理向量化的录音ID列表
    func getRecordingsWithoutEmbeddings() -> [String] {
        return performSync {
            try await self.recordingRepository.getRecordingsWithoutEmbeddings()
        }
    }
    
    /// 保存向量化结果
    func saveEmbeddings(_ embeddingResult: VolcEngineEmbeddingService.EmbeddingResult) {
        Task {
            do {
                guard let recordingId = UUID(uuidString: embeddingResult.recordingId) else {
                    print("❌ 无效的录音ID: \(embeddingResult.recordingId)")
                    return
                }
                
                // 直接使用统一向量
                if !embeddingResult.embedding.isEmpty {
                    let success = try await self.recordingRepository.updateEmbeddingVector(
                        id: recordingId,
                        embeddingVector: embeddingResult.embedding
                    )
                    if success {
                        print("✅ 成功保存录音 \(embeddingResult.recordingId) 的向量数据 (维度: \(embeddingResult.embedding.count))")
                    }
                } else {
                    print("⚠️ 向量数据为空，跳过保存")
                }
                
            } catch {
                print("❌ 保存向量数据失败: \(error)")
            }
        }
    }
    
    // 移除复杂的向量合并逻辑
    
    // MARK: - Utility Methods
    
    /// 同步执行异步操作的辅助方法
    private func performSync<T>(_ operation: @escaping () async throws -> T) -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>!
        
        Task {
            do {
                let value = try await operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            print("❌ 数据库操作失败: \(error)")
            // 返回默认值
            if T.self == Bool.self {
                return false as! T
            } else if T.self == Int.self {
                return 0 as! T
            } else if T.self == Array<AudioRecording>.self {
                return [] as! T
            } else if T.self == Array<String>.self {
                return [] as! T
            } else if T.self == [String: [Float]].self {
                return [:] as! T
            } else {
                fatalError("未处理的返回类型: \(T.self)")
            }
        }
    }
    
    /// 同步执行异步操作的辅助方法（可选返回值）
    private func performSyncOptional<T>(_ operation: @escaping () async throws -> T?) -> T? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T?, Error>!
        
        Task {
            do {
                let value = try await operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        switch result! {
        case .success(let value):
            return value
        case .failure(let error):
            print("❌ 数据库操作失败: \(error)")
            return nil
        }
    }
}

// MARK: - Legacy Compatibility Methods

extension DatabaseManager {
    
    /// 导出数据库调试信息（兼容性方法）
    func exportDatabaseDebugInfo() -> String {
        let debugFileName = "RakuDatabase_Debug_\(Date().timeIntervalSince1970).txt"
        var debugInfo = "=== Raku Database Debug Info ===\n"
        debugInfo += "Generated at: \(Date())\n\n"
        
        // 获取统计信息
        let recordingCount = getRecordingCount()
        let thinkingCount = getThinkingRecordings().count
        let inspirationCount = getInspirationRecordings().count
        
        debugInfo += "=== Statistics ===\n"
        debugInfo += "Total Recordings: \(recordingCount)\n"
        debugInfo += "Thinking Records: \(thinkingCount)\n"
        debugInfo += "Inspiration Records: \(inspirationCount)\n\n"
        
        // 获取录音记录
        debugInfo += "=== Recent Recordings ===\n"
        let recordings = loadRecordings()
        for (index, recording) in recordings.prefix(10).enumerated() {
            debugInfo += "\\nRecord #\\(index + 1):\n"
            debugInfo += "  ID: \\(recording.id.uuidString)\n"
            debugInfo += "  Title: \\(recording.title)\n"
            debugInfo += "  Timestamp: \\(recording.timestamp)\n"
            debugInfo += "  Duration: \\(recording.duration) seconds\n"
            debugInfo += "  Transcription: \\(recording.transcription.prefix(100))...\n"
            debugInfo += "  Tags: \\(recording.tags)\n"
        }
        
        // 保存到文件
        let debugFileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(debugFileName)
        
        do {
            try debugInfo.write(to: debugFileURL, atomically: true, encoding: .utf8)
            print("📝 调试信息已保存到: \(debugFileName)")
        } catch {
            print("❌ 保存调试信息失败: \(error)")
        }
        
        return debugFileName
    }
}