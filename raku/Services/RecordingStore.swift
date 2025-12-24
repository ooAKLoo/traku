//
//  RecordingStore.swift
//  raku
//
//  统一的录音状态管理中心
//  - 管理所有录音数据
//  - 管理处理进度状态
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

    /// 更新或添加录音
    func updateRecording(_ recording: AudioRecording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        } else {
            recordings.insert(recording, at: 0)
        }

        // 同步到数据库
        _ = DatabaseManager.shared.saveOrUpdateRecording(recording)
    }

    /// 删除录音
    func deleteRecording(_ recording: AudioRecording) {
        recordings.removeAll { $0.id == recording.id }
        processingStates.removeValue(forKey: recording.id)
        _ = DatabaseManager.shared.deleteRecording(id: recording.id)
    }

    /// 删除录音（通过ID）
    func deleteRecording(id: UUID) {
        recordings.removeAll { $0.id == id }
        processingStates.removeValue(forKey: id)
        _ = DatabaseManager.shared.deleteRecording(id: id)
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
    }

    /// 刷新指定录音
    func refreshRecording(id: UUID) {
        if let recording = DatabaseManager.shared.getRecording(by: id.uuidString) {
            if let index = recordings.firstIndex(where: { $0.id == id }) {
                recordings[index] = recording
            }
        }
    }

    // MARK: - Private Methods

    private func loadFromDatabase() {
        recordings = DatabaseManager.shared.loadRecordings()
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
