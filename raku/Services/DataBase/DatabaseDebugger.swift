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
    private let inspirationRepository: InspirationRepository
    private let embeddingRepository: EmbeddingRepository
    
    init(sqliteCore: SQLiteCore,
         recordingRepository: RecordingRepository,
         inspirationRepository: InspirationRepository,
         embeddingRepository: EmbeddingRepository) {
        self.sqliteCore = sqliteCore
        self.recordingRepository = recordingRepository
        self.inspirationRepository = inspirationRepository
        self.embeddingRepository = embeddingRepository
    }
    
    // MARK: - Public Debug Methods
    
    /// 打印数据库统计信息
    func printDatabaseStats() async {
        print("\n📊 ========== 数据库统计信息 ==========")
        
        do {
            let recordingCount = try await recordingRepository.count()
            let inspirationCount = try await inspirationRepository.count()
            let embeddingCount = try await embeddingRepository.count()
            
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
            }
            
            if recordings.count > 10 {
                print("\n... 还有 \(recordings.count - 10) 条记录未显示")
            }
            
        } catch {
            print("❌ 获取录音记录失败: \(error)")
        }
        
        print("\n🎵 =====================================\n")
    }
    
    /// 打印所有灵感记录的摘要信息
    func printInspirationSummary() async {
        print("\n💡 ========== 灵感记录摘要 ==========")
        
        do {
            let inspirations = try await inspirationRepository.list()
            
            for (index, inspiration) in inspirations.prefix(10).enumerated() {
                print("\n✨ 灵感 #\(index + 1):")
                print("   ID: \(inspiration.id)")
                print("   原始文本: \(inspiration.originalText.prefix(50))...")
                print("   润色文本: \(inspiration.polishedText.prefix(50))...")
                print("   标签: \(inspiration.tags.joined(separator: ", "))")
                print("   创建时间: \(formatDate(inspiration.createdAt))")
                print("   音频数据: \(inspiration.audioData != nil ? "✅" : "❌")")
                print("   向量数据: \(inspiration.embeddingVector.isEmpty ? "❌" : "✅ (\(inspiration.embeddingVector.count)维)")")
            }
            
            if inspirations.count > 10 {
                print("\n... 还有 \(inspirations.count - 10) 条记录未显示")
            }
            
        } catch {
            print("❌ 获取灵感记录失败: \(error)")
        }
        
        print("\n💡 =====================================\n")
    }
    
    /// 检查数据库表结构
    func printTableSchemas() async {
        print("\n🏗️ ========== 数据库表结构 ==========")
        
        let tables = ["audio_recordings", "inspirations", "embeddings"]
        
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
            let embeddingFilter = FilterCriteria(orderBy: "recording_id")
            let embeddings = try await embeddingRepository.list(filter: embeddingFilter)
            
            // 按录音ID分组向量
            var embeddingsByRecording: [String: [EmbeddingData]] = [:]
            for embedding in embeddings {
                embeddingsByRecording[embedding.recordingId, default: []].append(embedding)
            }
            
            print("📊 录音记录数: \(recordings.count)")
            print("📊 有向量数据的录音数: \(embeddingsByRecording.keys.count)")
            
            var missingEmbeddings: [String] = []
            var incompleteEmbeddings: [String] = []
            
            for recording in recordings {
                let recordingId = recording.id.uuidString
                
                if let recordingEmbeddings = embeddingsByRecording[recordingId] {
                    let embeddingTypes = Set(recordingEmbeddings.map { $0.embeddingType })
                    
                    // 检查必要的向量类型
                    let expectedTypes = ["title", "polished_text"]
                    let missingTypes = expectedTypes.filter { !embeddingTypes.contains($0) }
                    
                    if !missingTypes.isEmpty {
                        incompleteEmbeddings.append("\(recordingId.prefix(8))... (缺少: \(missingTypes.joined(separator: ", ")))")
                    }
                } else {
                    missingEmbeddings.append("\(recordingId.prefix(8))... (\(recording.title))")
                }
            }
            
            if missingEmbeddings.isEmpty && incompleteEmbeddings.isEmpty {
                print("✅ 所有录音都有完整的向量数据")
            } else {
                if !missingEmbeddings.isEmpty {
                    print("❌ 缺少向量数据的录音 (\(missingEmbeddings.count)):")
                    for missing in missingEmbeddings.prefix(5) {
                        print("   - \(missing)")
                    }
                    if missingEmbeddings.count > 5 {
                        print("   ... 还有 \(missingEmbeddings.count - 5) 条")
                    }
                }
                
                if !incompleteEmbeddings.isEmpty {
                    print("⚠️ 向量数据不完整的录音 (\(incompleteEmbeddings.count)):")
                    for incomplete in incompleteEmbeddings.prefix(5) {
                        print("   - \(incomplete)")
                    }
                    if incompleteEmbeddings.count > 5 {
                        print("   ... 还有 \(incompleteEmbeddings.count - 5) 条")
                    }
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
            let inspirationCount = try await inspirationRepository.count()
            let embeddingCount = try await embeddingRepository.count()
            
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
        let tables = ["audio_recordings", "inspirations", "embeddings"]
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
            // 检查是否有孤立的向量数据
            let embeddings = try await embeddingRepository.list()
            let recordings = try await recordingRepository.list()
            let recordingIds = Set(recordings.map { $0.id.uuidString })
            
            let orphanedEmbeddings = embeddings.filter { !recordingIds.contains($0.recordingId) }
            
            if orphanedEmbeddings.isEmpty {
                print("✅ 数据完整性检查通过")
            } else {
                print("⚠️ 发现 \(orphanedEmbeddings.count) 条孤立的向量记录")
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
            recordingRepository: recordingRepository,
            inspirationRepository: inspirationRepository,
            embeddingRepository: embeddingRepository
        )
    }
    
    /// 快速调试方法
    func printDebugInfo() {
        Task {
            await debugger.printDatabaseStats()
            await debugger.printRecordingSummary()
            await debugger.checkEmbeddingIntegrity()
        }
    }
    
    // MARK: - Internal Access for Debugger
    
    internal var _sqliteCore: SQLiteCore { return sqliteCore }
    internal var _recordingRepository: RecordingRepository { return recordingRepository }
    internal var _inspirationRepository: InspirationRepository { return inspirationRepository }
    internal var _embeddingRepository: EmbeddingRepository { return embeddingRepository }
}