//
//  ProcessingContext.swift
//  raku
//
//  处理上下文 - Pipeline数据载体
//

import Foundation

// MARK: - 录音来源
enum RecordingSource: String, Codable {
    case phone
    case watch
    case esp32
}

// MARK: - 处理上下文
struct ProcessingContext {
    let id: UUID
    let audioData: Data
    let duration: TimeInterval
    let createdAt: Date
    let source: RecordingSource

    // 各阶段产出
    var transcription: String?
    var firstStepAnalysis: FirstStepAnalysis?
    var enrichedContent: String?
    var embedding: [Float]?
    var weather: WeatherData?

    // 从FirstStepAnalysis派生的字段（方便访问）
    var title: String? {
        firstStepAnalysis?.title
    }

    var summary: String? {
        firstStepAnalysis?.oneSentenceSummary
    }

    var tags: [String] {
        firstStepAnalysis?.tags ?? []
    }

    var polishedText: String? {
        firstStepAnalysis?.polishedText
    }

    var thoughtType: FlashThoughtType {
        firstStepAnalysis?.thoughtType ?? .unknown
    }

    // 初始化
    init(
        id: UUID = UUID(),
        audioData: Data,
        duration: TimeInterval,
        createdAt: Date = Date(),
        source: RecordingSource
    ) {
        self.id = id
        self.audioData = audioData
        self.duration = duration
        self.createdAt = createdAt
        self.source = source
    }

    // 构建最终录音记录
    func buildRecording() -> AudioRecording {
        let contentType = thoughtType == .insight ? "inspiration" : "thinking"

        return AudioRecording(
            id: id,
            timestamp: createdAt,
            duration: duration,
            transcription: transcription ?? "",
            title: title ?? "录音",
            summary: summary ?? "",
            tags: tags,
            audioData: nil,  // 音频数据单独存储
            enrichedContent: enrichedContent,
            polishedText: polishedText ?? "",
            contentType: contentType,
            weatherType: weather?.type.rawValue,
            weatherLocation: weather?.location
        )
    }
}
