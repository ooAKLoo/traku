//
//  RecordingUpdateManager.swift
//  raku
//
//  Created by Claude on 2025/1/11.
//

import Foundation
import Combine
import SwiftUI

// MARK: - 录音更新管理器
class RecordingUpdateManager: ObservableObject {
    static let shared = RecordingUpdateManager()
    
    // 当前处理中的录音状态
    @Published var processingRecordings: [UUID: ProcessingStatus] = [:]
    
    // 录音数据更新
    @Published var recordingUpdates: [UUID: AudioRecording] = [:]
    
    private init() {}
    
    // 更新处理状态
    func updateProcessingStatus(for recordingId: UUID, stage: UIProcessingStage, progress: Float) {
        DispatchQueue.main.async {
            // 如果状态是完成或失败，直接清除状态而不是显示
            if stage == .completed || stage == .failed {
                self.processingRecordings.removeValue(forKey: recordingId)
                print("📝 RecordingUpdateManager: 清除处理状态 - ID: \(recordingId), Stage: \(stage)")
            } else {
                self.processingRecordings[recordingId] = ProcessingStatus(
                    stage: stage,
                    progress: progress,
                    timestamp: Date()
                )
                print("📝 RecordingUpdateManager: 更新处理状态 - ID: \(recordingId), Stage: \(stage)")
            }
        }
    }
    
    // 更新录音数据
    func updateRecording(_ recording: AudioRecording) {
        DispatchQueue.main.async {
            self.recordingUpdates[recording.id] = recording
            
            // 不在这里清除处理状态，让RecordingPipeline通过updateProcessingStatus来控制
            // 这样可以确保只有在真正完成时才清除状态
        }
    }
    
    // 移除处理状态
    func clearProcessingStatus(for recordingId: UUID) {
        DispatchQueue.main.async {
            self.processingRecordings.removeValue(forKey: recordingId)
        }
    }
    
    // 获取录音处理状态
    func getProcessingStatus(for recordingId: UUID) -> ProcessingStatus? {
        return processingRecordings[recordingId]
    }
    
    // 获取最新录音数据
    func getLatestRecording(for recordingId: UUID) -> AudioRecording? {
        return recordingUpdates[recordingId]
    }
}

// MARK: - 处理状态
struct ProcessingStatus {
    let stage: UIProcessingStage
    let progress: Float
    let timestamp: Date
}

// MARK: - UI处理阶段
enum UIProcessingStage {
    case idle
    case recording
    case speechRecognition
    case llmAnalysisFirstStep
    case llmAnalysisSecondStep
    case completed
    case failed
    
    var displayText: String {
        switch self {
        case .idle: return ""
        case .recording: return "录音中..."
        case .speechRecognition: return "识别中..."
        case .llmAnalysisFirstStep: return "分析中..."
        case .llmAnalysisSecondStep: return "生成中..."
        case .completed: return "完成"
        case .failed: return "失败"
        }
    }
    
    var color: Color {
        switch self {
        case .idle, .completed: return .clear
        case .recording: return .red
        case .speechRecognition: return .blue
        case .llmAnalysisFirstStep: return .orange
        case .llmAnalysisSecondStep: return .purple
        case .failed: return .red
        }
    }
}