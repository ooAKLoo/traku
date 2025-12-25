//
//  RecordingStore.swift
//  raku
//
//  统一的录音状态管理中心
//  - 管理所有录音数据
//  - 管理处理进度状态
//  - 管理回收站数据
//  - 作为UI层的唯一数据源
//

import Foundation
import SwiftUI
import Combine

@MainActor
class RecordingStore: ObservableObject {
    static let shared = RecordingStore()

    // MARK: - Published Properties
    @Published private(set) var recordings: [AudioRecording] = []
    @Published private(set) var deletedRecordings: [AudioRecording] = []  // 回收站数据
    @Published private(set) var processingStates: [UUID: ProcessingState] = [:]

    // MARK: - Processing State
    struct ProcessingState {
        let stage: ProcessingStage
        let progress: Float
        let timestamp: Date

        init(stage: ProcessingStage, progress: Float) {
            self.stage = stage
            self.progress = progress
            self.timestamp = Date()
        }
    }

    // MARK: - Initialization
    private init() {
        loadFromDatabase()
    }

    // MARK: - Public Methods

    /// 更新或添加录音（同时写入数据库）
    func updateRecording(_ recording: AudioRecording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        } else {
            recordings.insert(recording, at: 0)
        }

        // 同步到数据库
        _ = DatabaseManager.shared.saveOrUpdateRecording(recording)
    }

    /// 仅更新内存状态（不写数据库），用于Pipeline中间状态的UI刷新
    func updateInMemory(_ recording: AudioRecording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        } else {
            recordings.insert(recording, at: 0)
        }
    }

    /// 软删除录音（移入回收站）
    func deleteRecording(_ recording: AudioRecording) {
        recordings.removeAll { $0.id == recording.id }
        processingStates.removeValue(forKey: recording.id)
        
        // 执行软删除
        if DatabaseManager.shared.softDeleteRecording(id: recording.id) {
            // 更新本地回收站数据
            var deletedRecording = recording
            deletedRecording.deletedAt = Date()
            deletedRecordings.insert(deletedRecording, at: 0)
        }
    }

    /// 软删除录音（通过ID）
    func deleteRecording(id: UUID) {
        if let recording = recordings.first(where: { $0.id == id }) {
            deleteRecording(recording)
        } else {
            // 直接从数据库软删除
            recordings.removeAll { $0.id == id }
            processingStates.removeValue(forKey: id)
            _ = DatabaseManager.shared.softDeleteRecording(id: id)
            loadDeletedFromDatabase()
        }
    }
    
    // MARK: - Trash Operations (回收站操作)
    
    /// 恢复录音（从回收站恢复）
    func restoreRecording(_ recording: AudioRecording) {
        if DatabaseManager.shared.restoreRecording(id: recording.id) {
            deletedRecordings.removeAll { $0.id == recording.id }
            var restoredRecording = recording
            restoredRecording.deletedAt = nil
            recordings.insert(restoredRecording, at: 0)
            // 按时间排序
            recordings.sort { $0.timestamp > $1.timestamp }
        }
    }
    
    /// 恢复录音（通过ID）
    func restoreRecording(id: UUID) {
        if let recording = deletedRecordings.first(where: { $0.id == id }) {
            restoreRecording(recording)
        }
    }
    
    /// 清空回收站
    func emptyTrash() {
        let count = DatabaseManager.shared.emptyTrash()
        if count > 0 {
            deletedRecordings.removeAll()
        }
    }
    
    /// 获取回收站中的录音数量
    var deletedCount: Int {
        return deletedRecordings.count
    }

    /// 设置处理状态
    func setProcessingState(for id: UUID, stage: ProcessingStage, progress: Float? = nil) {
        let actualProgress = progress ?? stage.progress
        processingStates[id] = ProcessingState(stage: stage, progress: actualProgress)
    }

    /// 清除处理状态
    func clearProcessingState(for id: UUID) {
        processingStates.removeValue(forKey: id)
    }

    /// 从数据库重新加载
    func reload() {
        loadFromDatabase()
        loadDeletedFromDatabase()
    }

    /// 刷新指定录音
    func refreshRecording(id: UUID) {
        if let recording = DatabaseManager.shared.getRecording(by: id.uuidString) {
            if let index = recordings.firstIndex(where: { $0.id == id }) {
                recordings[index] = recording
            }
        }
    }
    
    /// 加载回收站数据
    func loadDeletedFromDatabase() {
        deletedRecordings = DatabaseManager.shared.loadDeletedRecordings()
    }

    // MARK: - Private Methods

    private func loadFromDatabase() {
        recordings = DatabaseManager.shared.loadRecordings()
        loadDeletedFromDatabase()
    }
}

// MARK: - Processing Stage (统一枚举)
enum ProcessingStage: String, CaseIterable {
    case idle = "空闲"
    case saving = "保存中"
    case speechRecognition = "识别中"
    case classification = "分析中"
    case embedding = "生成中"
    case metadata = "处理中"
    case completed = "完成"
    case failed = "失败"

    var progress: Float {
        switch self {
        case .idle: return 0.0
        case .saving: return 0.1
        case .speechRecognition: return 0.25
        case .classification: return 0.5
        case .embedding: return 0.75
        case .metadata: return 0.9
        case .completed: return 1.0
        case .failed: return 0.0
        }
    }

    var displayText: String {
        return rawValue
    }

    var color: Color {
        switch self {
        case .idle, .completed: return .clear
        case .saving: return .gray
        case .speechRecognition: return .blue
        case .classification: return .orange
        case .embedding: return .purple
        case .metadata: return .green
        case .failed: return .red
        }
    }

    var isProcessing: Bool {
        switch self {
        case .idle, .completed, .failed: return false
        default: return true
        }
    }
}

// MARK: - Notification Names
extension NSNotification.Name {
    static let tagsDidUpdate = NSNotification.Name("tagsDidUpdate")
}
