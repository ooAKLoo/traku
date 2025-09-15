//
//  DatabaseDebugger.swift
//  raku
//
//  Created by Assistant on Repository Pattern Refactor
//

import Foundation

/// 数据库调试工具类
class DatabaseDebugger {
    
    private let sqliteCore: SQLiteCore
    private let recordingRepository: RecordingRepository
    
    init(sqliteCore: SQLiteCore,
         recordingRepository: RecordingRepository) {
        self.sqliteCore = sqliteCore
        self.recordingRepository = recordingRepository
    }
    
    // MARK: - Public Debug Methods
    
    /// 打印数据库统计信息
    func printDatabaseStats() async {
        print("\n📊 ========== 数据库统计信息 ==========")
        
        do {
            let recordingCount = try await recordingRepository.count()
            let inspirationCount = 0 // Inspiration功能已整合到RecordingRepository中
            let embeddingCount = try await recordingRepository.count()
            
            print("📈 录音记录数: \(recordingCount)")
            print("💡 灵感记录数: \(inspirationCount)")
            print("🔢 向量记录数: \(embeddingCount)")
            
            // 检查数据完整性
            await checkDataIntegrity()
            
        } catch {
            print("❌ 获取统计信息失败: \(error)")
        }
        
        print("📊 ========================================\n")
    }
    
    /// 打印所有录音记录的摘要信息
    func printRecordingSummary() async {
        print("\n🎵 ========== 录音记录摘要 ==========")
        
        do {
            let recordings = try await recordingRepository.list()
            
            for (index, recording) in recordings.prefix(10).enumerated() {
                print("\n📝 录音 #\(index + 1):")
                print("   ID: \(recording.id.uuidString.prefix(8))...")
                print("   标题: \(recording.title)")
                print("   时长: \(String(format: "%.1f", recording.duration))秒")
                print("   创建时间: \(formatDate(recording.timestamp))")
                print("   转录内容: \(recording.transcription.prefix(50))...")
                print("   标签: \(recording.tags.joined(separator: ", "))")
                print("   音频数据: \(recording.audioData != nil ? "✅" : "❌")")
                print("   润色文本: \(recording.polishedText.isEmpty ? "❌" : "✅")")
                
                // 尝试获取向量数据
                do {
                    if let vector = try await recordingRepository.getEmbeddingVector(id: recording.id) {
                        print("   向量数据: ✅ (\(vector.count)维)")
                    } else {
                        print("   向量数据: ❌")
                    }
                } catch {
                    print("   向量数据: ❌")
                }
            }
            
            if recordings.count > 10 {
                print("\n... 还有 \(recordings.count - 10) 条记录未显示")
            }
            
        } catch {
            print("❌ 获取录音记录失败: \(error)")
        }
        
        print("\n🎵 =====================================\n")
    }
    
    /// 打印所有灵感记录的摘要信息（从统一的录音表获取灵感类型记录）
    func printInspirationSummary() async {
        print("\n💡 ========== 灵感记录摘要 ==========")
        
        do {
            let inspirationRecordings = try await recordingRepository.getInspirationRecordings()
            
            for (index, recording) in inspirationRecordings.prefix(10).enumerated() {
                print("\n✨ 灵感 #\(index + 1):")
                print("   ID: \(recording.id)")
                print("   标题: \(recording.title)")
                print("   原始文本: \(recording.transcription.prefix(50))...")
                print("   润色文本: \(recording.polishedText.prefix(50))...")
                print("   标签: \(recording.tags.joined(separator: ", "))")
                print("   创建时间: \(formatDate(recording.timestamp))")
                print("   音频数据: \(recording.audioData != nil ? "✅" : "❌")")
                
                // 检查向量数据
                do {
                    if let vector = try await recordingRepository.getEmbeddingVector(id: recording.id) {
                        print("   向量数据: ✅ (\(vector.count)维)")
                    } else {
                        print("   向量数据: ❌")
                    }
                } catch {
                    print("   向量数据: ❌")
                }
            }
            
            if inspirationRecordings.count > 10 {
                print("\n... 还有 \(inspirationRecordings.count - 10) 条记录未显示")
            }
            
        } catch {
            print("❌ 获取灵感记录失败: \(error)")
        }
        
        print("\n💡 =====================================\n")
    }
    
    /// 检查数据库表结构
    func printTableSchemas() async {
        print("\n🏗️ ========== 数据库表结构 ==========")
        
        let tables = ["audio_recordings"]
        
        for tableName in tables {
            print("\n📋 表: \(tableName)")
            do {
                let schema = try sqliteCore.getTableSchema(tableName)
                for column in schema {
                    var columnInfo = "   \(column.name): \(column.type)"
                    if column.notNull { columnInfo += " NOT NULL" }
                    if column.primaryKey { columnInfo += " PRIMARY KEY" }
                    print(columnInfo)
                }
            } catch {
                print("   ❌ 获取表结构失败: \(error)")
            }
        }
        
        print("\n🏗️ =====================================\n")
    }
    
    /// 检查向量数据完整性
    func checkEmbeddingIntegrity() async {
        print("\n🔍 ========== 向量数据完整性检查 ==========")
        
        do {
            let recordings = try await recordingRepository.list()
            print("📊 录音记录数: \(recordings.count)")
            
            // 统计有向量数据的录音
            var recordingsWithEmbeddings = 0
            for recording in recordings {
                do {
                    if try await recordingRepository.getEmbeddingVector(id: recording.id) != nil {
                        recordingsWithEmbeddings += 1
                    }
                } catch {
                    // 忽略错误，继续统计
                }
            }
            print("📊 有向量数据的录音数: \(recordingsWithEmbeddings)")
            
            var missingEmbeddings: [String] = []
            var incompleteEmbeddings: [String] = []
            
            for recording in recordings {
                let recordingId = recording.id.uuidString
                
                do {
                    if try await recordingRepository.getEmbeddingVector(id: recording.id) == nil {
                        missingEmbeddings.append("\(recordingId.prefix(8))... (\(recording.title))")
                    }
                } catch {
                    missingEmbeddings.append("\(recordingId.prefix(8))... (\(recording.title))")
                }
            }
            
            if missingEmbeddings.isEmpty {
                print("✅ 所有录音都有向量数据")
            } else {
                print("❌ 缺少向量数据的录音 (\(missingEmbeddings.count)):")
                for missing in missingEmbeddings.prefix(5) {
                    print("   - \(missing)")
                }
                if missingEmbeddings.count > 5 {
                    print("   ... 还有 \(missingEmbeddings.count - 5) 条")
                }
            }
            
        } catch {
            print("❌ 检查向量完整性失败: \(error)")
        }
        
        print("\n🔍 =======================================\n")
    }
    
    /// 导出完整的调试报告
    func exportDebugReport() async -> String {
        let timestamp = Date().timeIntervalSince1970
        let fileName = "RakuDB_Debug_\(Int(timestamp)).txt"
        
        var report = """
        ===================================
        Raku Database 调试报告
        生成时间: \(formatDate(Date()))
        ===================================
        
        """
        
        // 添加统计信息
        do {
            let recordingCount = try await recordingRepository.count()
            let inspirationCount = 0 // Inspiration功能已整合到RecordingRepository中
            let embeddingCount = try await recordingRepository.count()
            
            report += """
            📊 数据库统计:
            - 录音记录: \(recordingCount)
            - 灵感记录: \(inspirationCount)
            - 向量记录: \(embeddingCount)
            
            """
        } catch {
            report += "❌ 无法获取统计信息: \(error)\n\n"
        }
        
        // 添加录音记录详情
        do {
            let recordings = try await recordingRepository.list()
            report += "🎵 录音记录详情:\n"
            
            for (index, recording) in recordings.enumerated() {
                report += """
                
                录音 #\(index + 1):
                  ID: \(recording.id.uuidString)
                  标题: \(recording.title)
                  时长: \(String(format: "%.1f", recording.duration))秒
                  创建时间: \(formatDate(recording.timestamp))
                  转录内容: \(recording.transcription.prefix(100))...
                  标签: [\(recording.tags.joined(separator: ", "))]
                  音频数据: \(recording.audioData?.count ?? 0) bytes
                  润色文本长度: \(recording.polishedText.count) chars
                """
            }
            
        } catch {
            report += "❌ 无法获取录音记录: \(error)\n"
        }
        
        // 添加表结构信息
        let tables = ["audio_recordings"]
        report += "\n\n🏗️ 数据库表结构:\n"
        
        for tableName in tables {
            report += "\n表: \(tableName)\n"
            do {
                let schema = try sqliteCore.getTableSchema(tableName)
                for column in schema {
                    var columnInfo = "  \(column.name): \(column.type)"
                    if column.notNull { columnInfo += " NOT NULL" }
                    if column.primaryKey { columnInfo += " PRIMARY KEY" }
                    report += "\(columnInfo)\n"
                }
            } catch {
                report += "  ❌ 获取表结构失败: \(error)\n"
            }
        }
        
        // 保存报告
        let documentsURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            print("📝 调试报告已保存: \(fileName)")
        } catch {
            print("❌ 保存调试报告失败: \(error)")
        }
        
        return fileName
    }
    
    // MARK: - Private Helper Methods
    
    /// 检查数据完整性
    private func checkDataIntegrity() async {
        do {
            // 检查录音数据完整性
            let recordings = try await recordingRepository.list()
            var invalidCount = 0
            
            for recording in recordings {
                if recording.transcription.isEmpty || recording.title.isEmpty {
                    invalidCount += 1
                }
            }
            
            if invalidCount == 0 {
                print("✅ 数据完整性检查通过")
            } else {
                print("⚠️ 发现 \(invalidCount) 条不完整的录音记录")
            }
            
        } catch {
            print("❌ 数据完整性检查失败: \(error)")
        }
    }
    
    /// 格式化日期显示
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - DatabaseManager Extension

extension DatabaseManager {
    
    /// 获取调试器实例
    var debugger: DatabaseDebugger {
        return DatabaseDebugger(
            sqliteCore: sqliteCore,
            recordingRepository: recordingRepository
        )
    }
    
    /// 快速调试方法
    func printDebugInfo() {
        Task {
            await debugger.printDatabaseStats()
            await debugger.printRecordingSummary()
            await debugger.printInspirationSummary()
            await debugger.checkEmbeddingIntegrity()
        }
    }
    
    // MARK: - Internal Access for Debugger
    
    internal var _sqliteCore: SQLiteCore { return sqliteCore }
    internal var _recordingRepository: RecordingRepository { return recordingRepository }
}