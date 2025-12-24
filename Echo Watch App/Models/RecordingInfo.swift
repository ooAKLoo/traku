//
//  RecordingInfo.swift
//  Echo Watch App
//
//  录音元数据模型
//

import Foundation

struct RecordingInfo: Codable, Identifiable {
    let id: UUID
    let fileName: String
    let duration: TimeInterval
    let createdAt: Date
    var isSynced: Bool

    var fileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("recordings").appendingPathComponent(fileName)
    }

    init(id: UUID = UUID(), duration: TimeInterval, createdAt: Date = Date(), isSynced: Bool = false) {
        self.id = id
        self.fileName = "\(id.uuidString).m4a"
        self.duration = duration
        self.createdAt = createdAt
        self.isSynced = isSynced
    }
}

// MARK: - 同步状态
enum SyncState: String, Codable {
    case pending     // 等待同步
    case syncing     // 正在传输
    case synced      // 已同步到 iPhone
    case processed   // AI 处理完成
}
