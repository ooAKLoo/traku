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
    internal let inspirationRepository: InspirationRepository
    internal let embeddingRepository: EmbeddingRepository
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
        self.inspirationRepository = InspirationRepository(sqliteCore: sqliteCore)
        self.embeddingRepository = EmbeddingRepository(sqliteCore: sqliteCore)
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
            try await inspirationRepository.createTable()
            try await embeddingRepository.createTable()
            
            // 初始统计
            let recordingDataCount = try await recordingDataRepository.count()
            let recordingCount = try await recordingRepository.count()
            let inspirationCount = try await inspirationRepository.count()
            let embeddingCount = try await embeddingRepository.count()
            
            print("📊 数据库初始化完成:")
            print("  - 原始录音数据: \(recordingDataCount)")
            print("  - 录音分析记录: \(recordingCount)")
            print("  - 灵感记录: \(inspirationCount)")
            print("  - 向量记录: \(embeddingCount)")
            
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
            // 同时删除相关的向量数据
            let _ = try await self.embeddingRepository.deleteEmbeddings(for: id.uuidString)
            return try await self.recordingRepository.delete(id: id)
        }
    }
    
    /// 获取录音记录总数
    func getRecordingCount() -> Int {
        return performSync {
            try await self.recordingRepository.count()
        }
    }
    
    // MARK: - Inspiration Operations
    
    /// 保存灵感数据
    func saveInspiration(id: String, audioData: Data?, originalText: String, polishedText: String, tags: [String], embeddingVector: [Float]) -> Bool {
        let inspiration = InspirationData(
            id: id,
            originalText: originalText,
            polishedText: polishedText,
            tags: tags,
            audioData: audioData,
            embeddingVector: embeddingVector
        )
        
        return performSync {
            try await self.inspirationRepository.create(inspiration)
        }
    }
    
    /// 加载所有灵感数据
    func loadInspirations() -> [InspirationData] {
        return performSync {
            try await self.inspirationRepository.list()
        }
    }
    
    /// 获取灵感数量
    func getInspirationCount() -> Int {
        return performSync {
            try await self.inspirationRepository.count()
        }
    }
    
    // MARK: - Embedding Operations
    
    /// 保存向量化结果
    func saveEmbeddings(_ embeddingResult: VolcEngineEmbeddingService.EmbeddingResult) {
        Task {
            do {
                let result = EmbeddingResult(
                    recordingId: embeddingResult.recordingId,
                    titleEmbedding: embeddingResult.titleEmbedding,
                    tagsEmbeddings: embeddingResult.tagsEmbeddings,
                    polishedTextEmbedding: embeddingResult.polishedTextEmbedding
                )
                
                let _ = try await embeddingRepository.saveEmbeddings(result)
            } catch {
                print("❌ 保存向量数据失败: \(error)")
            }
        }
    }
    
    /// 获取录音的向量数据
    func getEmbeddings(for recordingId: String) -> [String: [Float]] {
        return performSync {
            try await self.embeddingRepository.getEmbeddings(for: recordingId)
        }
    }
    
    /// 获取未处理向量化的录音ID列表
    func getRecordingsWithoutEmbeddings() -> [String] {
        return performSync {
            try await self.recordingRepository.getRecordingsWithoutEmbeddings()
        }
    }
    
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
            } else if T.self == Array<InspirationData>.self {
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
        let inspirationCount = getInspirationCount()
        
        debugInfo += "=== Statistics ===\n"
        debugInfo += "Total Recordings: \(recordingCount)\n"
        debugInfo += "Total Inspirations: \(inspirationCount)\n\n"
        
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