import Foundation
import SQLite3

// SQLite3 destructor type constants
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

class DatabaseManager {
    private var db: OpaquePointer?
    private let dbPath: String
    private let dbQueue = DispatchQueue(label: "com.raku.database", qos: .userInitiated)
    
    static let shared = DatabaseManager()
    
    private init() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("RakuDatabase.sqlite")
        
        dbPath = fileURL.path
        openDatabase()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func openDatabase() {
        dbQueue.sync {
            print("🔍 DatabaseManager: 尝试打开数据库，路径: \(dbPath)")
            if sqlite3_open(dbPath, &db) == SQLITE_OK {
                print("✅ 数据库连接成功")
                createTablesInternal()
                
                // 立即检查数据库中的记录数量
                let initialCount = getRecordingCountInternal()
                print("📊 数据库初始化完成，当前记录数: \(initialCount)")
                
                if initialCount > 0 {
                    print("🔍 数据库中存在 \(initialCount) 条记录，打印前几条用于调试:")
                    printAllRecordingIDsInternal()
                    // 同步清理脏数据，避免多线程问题
                    cleanupInvalidRecords()
                }
                
                // 启用WAL模式，使数据库文件能被其他进程读取
                enableWALMode()
            } else {
                print("❌ 数据库连接失败")
                if let errorPointer = sqlite3_errmsg(db) {
                    let message = String(cString: errorPointer)
                    print("❌ 错误信息: \(message)")
                }
                db = nil
            }
        }
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    private func createTablesInternal() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS audio_recordings (
                id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                duration REAL NOT NULL,
                transcription TEXT NOT NULL,
                summary TEXT NOT NULL,
                tags TEXT NOT NULL,
                audio_data BLOB,
                enriched_content TEXT,
                created_at REAL NOT NULL DEFAULT (julianday('now'))
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) == SQLITE_OK {
            print("✅ 录音表创建成功")
        } else {
            print("❌ 录音表创建失败")
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String(cString: errorPointer)
                print("错误信息: \(message)")
            }
        }
    }
    
    /// 调试用：打印所有录音记录的ID（内部版本，不使用队列）
    private func printAllRecordingIDsInternal() {
        let querySQL = "SELECT id, transcription, created_at FROM audio_recordings ORDER BY created_at DESC"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            print("🔍 数据库中的所有录音记录:")
            var index = 1
            while sqlite3_step(statement) == SQLITE_ROW {
                if let idString = sqlite3_column_text(statement, 0),
                   let transcription = sqlite3_column_text(statement, 1) {  // 修正索引：转录在索引1
                    let id = String(cString: idString)
                    let text = String(cString: transcription)
                    let createdAt = sqlite3_column_double(statement, 2)  // created_at在索引2
                    print("  \(index). ID: \(id), 转录: \(text), 创建时间: \(Date(timeIntervalSince1970: createdAt))")
                    index += 1
                }
            }
        }
        sqlite3_finalize(statement)
    }
    
    /// 内部版本：获取记录总数（不使用队列）
    private func getRecordingCountInternal() -> Int {
        print("🔍 getRecordingCountInternal: 开始查询总记录数")
        
        let countSQL = "SELECT COUNT(*) FROM audio_recordings"
        print("🔍 SQL语句: \(countSQL)")
        
        var statement: OpaquePointer?
        var count = 0
        
        // 检查数据库连接
        guard db != nil else {
            print("❌ 数据库连接为空")
            return 0
        }
        
        let prepareResult = sqlite3_prepare_v2(db, countSQL, -1, &statement, nil)
        print("🔍 SQL准备结果: \(prepareResult), SQLITE_OK=\(SQLITE_OK)")
        
        if prepareResult == SQLITE_OK {
            let stepResult = sqlite3_step(statement)
            print("🔍 SQL执行结果: \(stepResult), SQLITE_ROW=\(SQLITE_ROW)")
            
            if stepResult == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
                print("🔍 查询到的记录数: \(count)")
            } else {
                print("❌ SQL执行失败，无法获取行数据")
                if let errorPointer = sqlite3_errmsg(db) {
                    let message = String(cString: errorPointer)
                    print("❌ 错误信息: \(message)")
                }
            }
        } else {
            print("❌ SQL语句准备失败")
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String(cString: errorPointer)
                print("❌ 错误信息: \(message)")
            }
        }
        
        sqlite3_finalize(statement)
        print("🔍 getRecordingCountInternal完成，返回: \(count)")
        return count
    }
    
    // MARK: - 新增：统一的保存或更新方法
    func saveOrUpdateRecording(_ recording: AudioRecording) -> Bool {
        return dbQueue.sync {
            let existingCount = getRecordingCountByIdInternal(recording.id)
            if existingCount > 0 {
                print("📝 记录已存在，执行更新操作")
                return updateRecordingInternal(recording)
            } else {
                print("📝 记录不存在，执行保存操作")
                return saveRecordingInternal(recording)
            }
        }
    }
    
    func saveRecording(_ recording: AudioRecording) -> Bool {
        return dbQueue.sync {
            return saveRecordingInternal(recording)
        }
    }
    
    private func saveRecordingInternal(_ recording: AudioRecording) -> Bool {
        // 使用 INSERT 确保每条记录都是新的，不覆盖现有记录
            let insertSQL = """
                INSERT INTO audio_recordings (id, timestamp, duration, transcription, summary, tags, audio_data, enriched_content, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            
            print("💾 准备保存录音，ID: \(recording.id.uuidString), 转录: \(recording.transcription)")
            
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            let tagsJSON = try? JSONEncoder().encode(recording.tags)
            let tagsString = tagsJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            
            // 使用SQLITE_TRANSIENT确保字符串被复制
            let idString = recording.id.uuidString
            sqlite3_bind_text(statement, 1, (idString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 2, recording.timestamp.timeIntervalSince1970)
            sqlite3_bind_double(statement, 3, recording.duration)
            sqlite3_bind_text(statement, 4, (recording.transcription as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, (recording.summary as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 6, (tagsString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            
            if let audioData = recording.audioData {
                sqlite3_bind_blob(statement, 7, audioData.withUnsafeBytes { $0.bindMemory(to: Int8.self).baseAddress }, Int32(audioData.count), nil)
            } else {
                sqlite3_bind_null(statement, 7)
            }
            
            if let enrichedContent = recording.enrichedContent {
                sqlite3_bind_text(statement, 8, (enrichedContent as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 8)
            }
            
            sqlite3_bind_double(statement, 9, Date().timeIntervalSince1970)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ 录音保存成功，ID: \(recording.id.uuidString)")
                let totalCount = getRecordingCountInternal()
                print("📊 当前数据库总记录数: \(totalCount)")
                
                // 验证刚保存的数据是否可以读取
                print("🔍 验证刚保存的数据...")
                let verifySQL = "SELECT id, transcription FROM audio_recordings WHERE id = ?"
                var verifyStatement: OpaquePointer?
                if sqlite3_prepare_v2(db, verifySQL, -1, &verifyStatement, nil) == SQLITE_OK {
                        let verifyIdString = recording.id.uuidString
                    sqlite3_bind_text(verifyStatement, 1, (verifyIdString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                    if sqlite3_step(verifyStatement) == SQLITE_ROW {
                        if let idString = sqlite3_column_text(verifyStatement, 0),
                           let transcription = sqlite3_column_text(verifyStatement, 1) {
                            print("✅ 验证成功: ID=\(String(cString: idString).prefix(8))..., 转录=\(String(cString: transcription).prefix(30))...")
                        }
                    } else {
                        print("❌ 验证失败：无法找到刚保存的记录")
                    }
                }
                sqlite3_finalize(verifyStatement)
                
                // 额外验证：使用getRecordingCountByIdInternal方法验证
                print("🔍 使用getRecordingCountByIdInternal验证刚保存的记录...")
                let countCheck = getRecordingCountByIdInternal(recording.id)
                print("🔍 getRecordingCountByIdInternal返回: \(countCheck)")
                if countCheck != 1 {
                    print("⚠️ 警告：保存成功但getRecordingCountByIdInternal无法找到记录！")
                }
                
                sqlite3_finalize(statement)
                return true
            } else {
                print("❌ 录音保存失败")
                if let errorPointer = sqlite3_errmsg(db) {
                    let message = String(cString: errorPointer)
                    print("错误信息: \(message)")
                }
            }
            } else {
            print("❌ SQL语句准备失败")
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String(cString: errorPointer)
                print("错误信息: \(message)")
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    func loadRecordings() -> [AudioRecording] {
        return dbQueue.sync {
            let querySQL = "SELECT id, timestamp, duration, transcription, summary, tags, audio_data, enriched_content FROM audio_recordings ORDER BY timestamp DESC"
            
            var statement: OpaquePointer?
            var recordings: [AudioRecording] = []
            
            print("🔍 DatabaseManager.loadRecordings: 开始从数据库加载录音记录...")
            let totalCount = getRecordingCountInternal()
            print("📊 数据库中总记录数: \(totalCount)")
            
            // 打印所有记录的ID和转录内容用于调试
            printAllRecordingIDsInternal()
            
            if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
                print("🔍 SQL查询准备成功，开始逐行读取...")
                var rowIndex = 0
                while sqlite3_step(statement) == SQLITE_ROW {
                    rowIndex += 1
                    print("🔍 处理第 \(rowIndex) 行数据...")
                
                guard let idString = sqlite3_column_text(statement, 0),
                      let transcription = sqlite3_column_text(statement, 3),
                      let summary = sqlite3_column_text(statement, 4),
                      let tagsString = sqlite3_column_text(statement, 5) else {
                    print("❌ 第 \(rowIndex) 行数据格式错误，跳过")
                    continue
                }
                
                let id = UUID(uuidString: String(cString: idString)) ?? UUID()
                let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                let duration = sqlite3_column_double(statement, 2)
                let transcriptionStr = String(cString: transcription)
                let summaryStr = String(cString: summary)
                
                print("🔍 第 \(rowIndex) 行基础数据: ID=\(String(cString: idString).prefix(8))..., 转录=\(transcriptionStr.prefix(30))...")
                
                let tagsData = String(cString: tagsString).data(using: .utf8)
                let tags = (try? JSONDecoder().decode([String].self, from: tagsData ?? Data())) ?? []
                
                var audioData: Data?
                if let audioBlob = sqlite3_column_blob(statement, 6) {
                    let audioSize = sqlite3_column_bytes(statement, 6)
                    audioData = Data(bytes: audioBlob, count: Int(audioSize))
                    print("🔍 音频数据大小: \(audioSize) 字节")
                } else {
                    print("⚠️ 无音频数据")
                }
                
                var enrichedContent: String?
                if let enrichedText = sqlite3_column_text(statement, 7) {
                    enrichedContent = String(cString: enrichedText)
                }
                
                let recording = AudioRecording(
                    id: id,
                    timestamp: timestamp,
                    duration: duration,
                    transcription: transcriptionStr,
                    summary: summaryStr,
                    tags: tags,
                    audioData: audioData,
                    enrichedContent: enrichedContent
                )
                
                print("✅ 第 \(rowIndex) 行录音记录解析成功: ID=\(id.uuidString.prefix(8))..., 转录=\(transcriptionStr.prefix(30))...")
                recordings.append(recording)
            }
                print("🔍 所有行处理完成，共处理 \(rowIndex) 行，成功解析 \(recordings.count) 条记录")
            } else {
                print("❌ 查询录音失败")
                if let errorPointer = sqlite3_errmsg(db) {
                    let message = String(cString: errorPointer)
                    print("错误信息: \(message)")
                }
            }
        
            sqlite3_finalize(statement)
            print("✅ 成功加载 \(recordings.count) 条录音记录")
            return recordings
        }
    }
    
    func deleteRecording(id: UUID) -> Bool {
        return dbQueue.sync {
            let deleteSQL = "DELETE FROM audio_recordings WHERE id = ?"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
                let idString = id.uuidString
                sqlite3_bind_text(statement, 1, (idString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("录音删除成功")
                    sqlite3_finalize(statement)
                    return true
                }
            }
            
            sqlite3_finalize(statement)
            return false
        }
    }
    
    func updateRecording(_ recording: AudioRecording) -> Bool {
        return dbQueue.sync {
            return updateRecordingInternal(recording)
        }
    }
    
    private func updateRecordingInternal(_ recording: AudioRecording) -> Bool {
        print("🔄 DatabaseManager.updateRecordingInternal: 尝试更新录音，ID: \(recording.id.uuidString)")
        
        let updateSQL = """
            UPDATE audio_recordings 
            SET timestamp = ?, duration = ?, transcription = ?, summary = ?, tags = ?, audio_data = ?, enriched_content = ?
            WHERE id = ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            let tagsJSON = try? JSONEncoder().encode(recording.tags)
            let tagsString = tagsJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            
            sqlite3_bind_double(statement, 1, recording.timestamp.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, recording.duration)
            sqlite3_bind_text(statement, 3, (recording.transcription as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 4, (recording.summary as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 5, (tagsString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            
            if let audioData = recording.audioData {
                sqlite3_bind_blob(statement, 6, audioData.withUnsafeBytes { $0.bindMemory(to: Int8.self).baseAddress }, Int32(audioData.count), nil)
            } else {
                sqlite3_bind_null(statement, 6)
            }
            
            if let enrichedContent = recording.enrichedContent {
                sqlite3_bind_text(statement, 7, (enrichedContent as NSString).utf8String, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 7)
            }
            
            let idString = recording.id.uuidString
            sqlite3_bind_text(statement, 8, (idString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            
        if sqlite3_step(statement) == SQLITE_DONE {
            print("录音更新成功")
            sqlite3_finalize(statement)
            return true
        }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    func getRecordingCount() -> Int {
        return dbQueue.sync {
            print("🔍 getRecordingCount: 开始查询总记录数")
            
            let countSQL = "SELECT COUNT(*) FROM audio_recordings"
            print("🔍 SQL语句: \(countSQL)")
            
            var statement: OpaquePointer?
            var count = 0
            
            // 检查数据库连接
            guard db != nil else {
                print("❌ 数据库连接为空")
                return 0
            }
            
            let prepareResult = sqlite3_prepare_v2(db, countSQL, -1, &statement, nil)
            print("🔍 SQL准备结果: \(prepareResult), SQLITE_OK=\(SQLITE_OK)")
            
            if prepareResult == SQLITE_OK {
                let stepResult = sqlite3_step(statement)
                print("🔍 SQL执行结果: \(stepResult), SQLITE_ROW=\(SQLITE_ROW)")
                
                if stepResult == SQLITE_ROW {
                    count = Int(sqlite3_column_int(statement, 0))
                    print("🔍 查询到的记录数: \(count)")
                } else {
                    print("❌ SQL执行失败，无法获取行数据")
                    if let errorPointer = sqlite3_errmsg(db) {
                        let message = String(cString: errorPointer)
                        print("❌ 错误信息: \(message)")
                    }
                }
            } else {
                print("❌ SQL语句准备失败")
                if let errorPointer = sqlite3_errmsg(db) {
                    let message = String(cString: errorPointer)
                    print("❌ 错误信息: \(message)")
                }
            }
            
            sqlite3_finalize(statement)
            print("🔍 getRecordingCount完成，返回: \(count)")
            return count
        }
    }
    
    private func getRecordingCountById(_ id: UUID) -> Int {
        return dbQueue.sync {
            return getRecordingCountByIdInternal(id)
        }
    }
    
    private func getRecordingCountByIdInternal(_ id: UUID) -> Int {
        print("🔍 getRecordingCountByIdInternal: 查询ID \(id.uuidString.prefix(8))... 的记录数量")
        
        let countSQL = "SELECT COUNT(*) FROM audio_recordings WHERE id = ?"
        var statement: OpaquePointer?
        var count = 0
        
            if sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK {
                let idString = id.uuidString
                sqlite3_bind_text(statement, 1, (idString as NSString).utf8String, -1, SQLITE_TRANSIENT)
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
                print("🔍 查询结果: ID \(id.uuidString.prefix(8))... 的记录数量为 \(count)")
            }
        } else {
            print("❌ SQL查询准备失败")
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String(cString: errorPointer)
                print("❌ 错误信息: \(message)")
            }
        }
        
        // 如果找到记录，打印详细信息用于调试
        if count > 0 {
            print("🔍 该ID在数据库中已存在，查询详细信息:")
            let detailSQL = "SELECT id, transcription, summary, created_at FROM audio_recordings WHERE id = ?"
            var detailStatement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, detailSQL, -1, &detailStatement, nil) == SQLITE_OK {
                    let detailIdString = id.uuidString
                    sqlite3_bind_text(detailStatement, 1, (detailIdString as NSString).utf8String, -1, SQLITE_TRANSIENT)
                if sqlite3_step(detailStatement) == SQLITE_ROW {
                    if let idStr = sqlite3_column_text(detailStatement, 0),
                       let transcription = sqlite3_column_text(detailStatement, 1),
                       let summary = sqlite3_column_text(detailStatement, 2) {
                        let createdAt = sqlite3_column_double(detailStatement, 3)
                        print("  📝 ID: \(String(cString: idStr))")
                        print("  📝 转录: \(String(cString: transcription))")
                        print("  📝 摘要: \(String(cString: summary))")
                        print("  📝 创建时间: \(Date(timeIntervalSince1970: createdAt))")
                    }
                }
            }
            sqlite3_finalize(detailStatement)
        } else {
            print("✅ ID \(id.uuidString.prefix(8))... 在数据库中不存在，可以新建记录")
        }
        
        sqlite3_finalize(statement)
        return count
    }
    
    /// 清理数据库中的无效记录（空ID、空转录等）
    private func cleanupInvalidRecords() {
        print("🧹 开始清理数据库中的无效记录...")
        
        // 首先打印要清理的记录详情
        let detailSQL = """
            SELECT id, timestamp, transcription, summary, created_at 
            FROM audio_recordings 
            WHERE id IS NULL OR id = '' OR LENGTH(TRIM(id)) = 0
        """
        
        var detailStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, detailSQL, -1, &detailStatement, nil) == SQLITE_OK {
            print("📋 无效记录详情：")
            var index = 1
            while sqlite3_step(detailStatement) == SQLITE_ROW {
                let idValue = sqlite3_column_text(detailStatement, 0) != nil ? String(cString: sqlite3_column_text(detailStatement, 0)!) : "NULL"
                let timestamp = sqlite3_column_double(detailStatement, 1)
                let transcription = sqlite3_column_text(detailStatement, 2) != nil ? String(cString: sqlite3_column_text(detailStatement, 2)!) : "NULL"
                let summary = sqlite3_column_text(detailStatement, 3) != nil ? String(cString: sqlite3_column_text(detailStatement, 3)!) : "NULL"
                let createdAt = sqlite3_column_double(detailStatement, 4)
                
                print("  \(index). ID: '\(idValue)'")
                print("     时间戳: \(timestamp) (\(Date(timeIntervalSince1970: timestamp)))")
                print("     转录: \(transcription)")
                print("     摘要: \(summary)")
                print("     创建时间: \(createdAt) (\(Date(timeIntervalSince1970: createdAt)))")
                print("     ---")
                index += 1
            }
        }
        sqlite3_finalize(detailStatement)
        
        // 查找空ID或无效ID的记录
        let findInvalidSQL = """
            SELECT COUNT(*) FROM audio_recordings 
            WHERE id IS NULL OR id = '' OR LENGTH(TRIM(id)) = 0
        """
        
        var findStatement: OpaquePointer?
        var invalidCount = 0
        
        if sqlite3_prepare_v2(db, findInvalidSQL, -1, &findStatement, nil) == SQLITE_OK {
            if sqlite3_step(findStatement) == SQLITE_ROW {
                invalidCount = Int(sqlite3_column_int(findStatement, 0))
            }
        }
        sqlite3_finalize(findStatement)
        
        if invalidCount > 0 {
            print("⚠️ 发现 \(invalidCount) 条无效记录，准备清理...")
            
            // 删除无效记录
            let deleteInvalidSQL = """
                DELETE FROM audio_recordings 
                WHERE id IS NULL OR id = '' OR LENGTH(TRIM(id)) = 0
            """
            
            if sqlite3_exec(db, deleteInvalidSQL, nil, nil, nil) == SQLITE_OK {
                print("✅ 成功清理 \(invalidCount) 条无效记录")
                
                // 验证清理结果
                let afterCount = getRecordingCountInternal()
                print("📊 清理后数据库记录数: \(afterCount)")
            } else {
                print("❌ 清理无效记录失败")
                if let errorPointer = sqlite3_errmsg(db) {
                    let message = String(cString: errorPointer)
                    print("❌ 错误信息: \(message)")
                }
            }
        } else {
            print("✅ 数据库中没有无效记录，无需清理")
        }
    }
    
    /// 启用WAL模式，使数据库能被其他进程读取
    private func enableWALMode() {
        let enableWAL = "PRAGMA journal_mode=WAL;"
        if sqlite3_exec(db, enableWAL, nil, nil, nil) == SQLITE_OK {
            print("✅ WAL模式已启用")
        } else {
            print("❌ 启用WAL模式失败")
        }
    }
    
    /// 导出数据库的调试信息到文件
    func exportDatabaseDebugInfo() -> String {
        return dbQueue.sync {
            var debugInfo = "=== Raku Database Debug Info ===\n"
            debugInfo += "Generated at: \(Date())\n"
            debugInfo += "Database Path: \(dbPath)\n\n"
            
            // 获取表结构
            debugInfo += "=== Table Structure ===\n"
            let schemaSQL = "PRAGMA table_info(audio_recordings)"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, schemaSQL, -1, &statement, nil) == SQLITE_OK {
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let name = sqlite3_column_text(statement, 1),
                       let type = sqlite3_column_text(statement, 2) {
                        let columnName = String(cString: name)
                        let columnType = String(cString: type)
                        let notNull = sqlite3_column_int(statement, 3) == 1
                        let isPrimary = sqlite3_column_int(statement, 5) == 1
                        
                        debugInfo += "- \(columnName): \(columnType)"
                        if notNull { debugInfo += " NOT NULL" }
                        if isPrimary { debugInfo += " PRIMARY KEY" }
                        debugInfo += "\n"
                    }
                }
            }
            sqlite3_finalize(statement)
            
            // 获取记录统计
            debugInfo += "\n=== Statistics ===\n"
            debugInfo += "Total Records: \(getRecordingCountInternal())\n"
            
            // 获取所有记录
            debugInfo += "\n=== All Records ===\n"
            let querySQL = "SELECT id, timestamp, duration, transcription, summary, tags, LENGTH(audio_data) as audio_size, created_at FROM audio_recordings ORDER BY created_at DESC"
            
            if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
                var index = 1
                while sqlite3_step(statement) == SQLITE_ROW {
                    debugInfo += "\nRecord #\(index):\n"
                    
                    if let id = sqlite3_column_text(statement, 0) {
                        let idStr = String(cString: id)
                        debugInfo += "  ID: \(idStr.isEmpty ? "[EMPTY]" : idStr)\n"
                    } else {
                        debugInfo += "  ID: [NULL]\n"
                    }
                    
                    let timestamp = sqlite3_column_double(statement, 1)
                    debugInfo += "  Timestamp: \(Date(timeIntervalSince1970: timestamp))\n"
                    
                    let duration = sqlite3_column_double(statement, 2)
                    debugInfo += "  Duration: \(duration) seconds\n"
                    
                    if let transcription = sqlite3_column_text(statement, 3) {
                        let text = String(cString: transcription)
                        debugInfo += "  Transcription: \(text.prefix(100))...\n"
                    }
                    
                    if let summary = sqlite3_column_text(statement, 4) {
                        let text = String(cString: summary)
                        debugInfo += "  Summary: \(text.prefix(100))...\n"
                    }
                    
                    if let tags = sqlite3_column_text(statement, 5) {
                        debugInfo += "  Tags: \(String(cString: tags))\n"
                    }
                    
                    let audioSize = sqlite3_column_int(statement, 6)
                    debugInfo += "  Audio Size: \(audioSize) bytes\n"
                    
                    let createdAt = sqlite3_column_double(statement, 7)
                    debugInfo += "  Created At: \(Date(timeIntervalSince1970: createdAt))\n"
                    
                    index += 1
                }
            }
            sqlite3_finalize(statement)
            
            // 保存到文件
            let debugFileName = "RakuDatabase_Debug_\(Date().timeIntervalSince1970).txt"
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
}
