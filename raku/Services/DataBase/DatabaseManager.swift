import Foundation
import SQLite3

class DatabaseManager {
    private var db: OpaquePointer?
    private let dbPath: String
    
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
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("数据库连接成功")
            createTables()
        } else {
            print("数据库连接失败")
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String(cString: errorPointer)
                print("错误信息: \(message)")
            }
            db = nil
        }
    }
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }
    
    private func createTables() {
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
            
            // 添加调试信息：检查现有记录
            let existingCount = getRecordingCount()
            print("📊 表中现有记录数: \(existingCount)")
            
            // 如果需要，可以打印所有记录的ID用于调试
            if existingCount > 0 {
                printAllRecordingIDs()
            }
        } else {
            print("❌ 录音表创建失败")
            if let errorPointer = sqlite3_errmsg(db) {
                let message = String(cString: errorPointer)
                print("错误信息: \(message)")
            }
        }
    }
    
    /// 调试用：打印所有录音记录的ID
    private func printAllRecordingIDs() {
        let querySQL = "SELECT id, transcription, created_at FROM audio_recordings ORDER BY created_at DESC"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            print("🔍 数据库中的所有录音记录:")
            var index = 1
            while sqlite3_step(statement) == SQLITE_ROW {
                if let idString = sqlite3_column_text(statement, 0),
                   let transcription = sqlite3_column_text(statement, 2) {
                    let id = String(cString: idString)
                    let text = String(cString: transcription)
                    let createdAt = sqlite3_column_double(statement, 2)
                    print("  \(index). ID: \(id), 转录: \(text), 创建时间: \(Date(timeIntervalSince1970: createdAt))")
                    index += 1
                }
            }
        }
        sqlite3_finalize(statement)
    }
    
    func saveRecording(_ recording: AudioRecording) -> Bool {
        // 使用 INSERT 确保每条记录都是新的，不覆盖现有记录
        let insertSQL = """
            INSERT INTO audio_recordings (id, timestamp, duration, transcription, summary, tags, audio_data, enriched_content, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        
        print("💾 准备保存录音，ID: \(recording.id.uuidString), 转录: \(recording.transcription)")
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            let tagsJSON = try? JSONEncoder().encode(recording.tags)
            let tagsString = tagsJSON != nil ? String(data: tagsJSON!, encoding: .utf8) : "[]"
            
            sqlite3_bind_text(statement, 1, recording.id.uuidString, -1, nil)
            sqlite3_bind_double(statement, 2, recording.timestamp.timeIntervalSince1970)
            sqlite3_bind_double(statement, 3, recording.duration)
            sqlite3_bind_text(statement, 4, recording.transcription, -1, nil)
            sqlite3_bind_text(statement, 5, recording.summary, -1, nil)
            sqlite3_bind_text(statement, 6, tagsString, -1, nil)
            
            if let audioData = recording.audioData {
                sqlite3_bind_blob(statement, 7, audioData.withUnsafeBytes { $0.bindMemory(to: Int8.self).baseAddress }, Int32(audioData.count), nil)
            } else {
                sqlite3_bind_null(statement, 7)
            }
            
            if let enrichedContent = recording.enrichedContent {
                sqlite3_bind_text(statement, 8, enrichedContent, -1, nil)
            } else {
                sqlite3_bind_null(statement, 8)
            }
            
            sqlite3_bind_double(statement, 9, Date().timeIntervalSince1970)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("✅ 录音保存成功，ID: \(recording.id.uuidString)")
                let totalCount = getRecordingCount()
                print("📊 当前数据库总记录数: \(totalCount)")
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
        let querySQL = "SELECT id, timestamp, duration, transcription, summary, tags, audio_data, enriched_content FROM audio_recordings ORDER BY timestamp DESC"
        
        var statement: OpaquePointer?
        var recordings: [AudioRecording] = []
        
        print("🔍 开始从数据库加载录音记录...")
        let totalCount = getRecordingCount()
        print("📊 数据库中总记录数: \(totalCount)")
        
        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idString = sqlite3_column_text(statement, 0),
                      let transcription = sqlite3_column_text(statement, 3),
                      let summary = sqlite3_column_text(statement, 4),
                      let tagsString = sqlite3_column_text(statement, 5) else {
                    continue
                }
                
                let id = UUID(uuidString: String(cString: idString)) ?? UUID()
                let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                let duration = sqlite3_column_double(statement, 2)
                let transcriptionStr = String(cString: transcription)
                let summaryStr = String(cString: summary)
                
                let tagsData = String(cString: tagsString).data(using: .utf8)
                let tags = (try? JSONDecoder().decode([String].self, from: tagsData ?? Data())) ?? []
                
                var audioData: Data?
                if let audioBlob = sqlite3_column_blob(statement, 6) {
                    let audioSize = sqlite3_column_bytes(statement, 6)
                    audioData = Data(bytes: audioBlob, count: Int(audioSize))
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
                
                print("📱 加载录音记录: ID=\(id.uuidString), 转录=\(transcriptionStr)")
                recordings.append(recording)
            }
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
    
    func deleteRecording(id: UUID) -> Bool {
        let deleteSQL = "DELETE FROM audio_recordings WHERE id = ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, id.uuidString, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_DONE {
                print("录音删除成功")
                sqlite3_finalize(statement)
                return true
            }
        }
        
        sqlite3_finalize(statement)
        return false
    }
    
    func updateRecording(_ recording: AudioRecording) -> Bool {
        let updateSQL = """
            UPDATE audio_recordings 
            SET timestamp = ?, duration = ?, transcription = ?, summary = ?, tags = ?, audio_data = ?, enriched_content = ?
            WHERE id = ?
        """
        
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK {
            let tagsJSON = try? JSONEncoder().encode(recording.tags)
            let tagsString = tagsJSON != nil ? String(data: tagsJSON!, encoding: .utf8) : "[]"
            
            sqlite3_bind_double(statement, 1, recording.timestamp.timeIntervalSince1970)
            sqlite3_bind_double(statement, 2, recording.duration)
            sqlite3_bind_text(statement, 3, recording.transcription, -1, nil)
            sqlite3_bind_text(statement, 4, recording.summary, -1, nil)
            sqlite3_bind_text(statement, 5, tagsString, -1, nil)
            
            if let audioData = recording.audioData {
                sqlite3_bind_blob(statement, 6, audioData.withUnsafeBytes { $0.bindMemory(to: Int8.self).baseAddress }, Int32(audioData.count), nil)
            } else {
                sqlite3_bind_null(statement, 6)
            }
            
            if let enrichedContent = recording.enrichedContent {
                sqlite3_bind_text(statement, 7, enrichedContent, -1, nil)
            } else {
                sqlite3_bind_null(statement, 7)
            }
            
            sqlite3_bind_text(statement, 8, recording.id.uuidString, -1, nil)
            
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
        let countSQL = "SELECT COUNT(*) FROM audio_recordings"
        var statement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, countSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(statement, 0))
            }
        }
        
        sqlite3_finalize(statement)
        return count
    }
}