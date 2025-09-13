//
//  AudioRecording.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import Foundation

// MARK: - 录音数据模型
struct AudioRecording: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let duration: TimeInterval
    let transcription: String
    var title: String
    let summary: String
    var tags: [String]
    let audioData: Data?
    var isPlaying: Bool = false
    var enrichedContent: String?
    var polishedText: String = ""  // 润色后的文本，默认为空
    
    init(id: UUID? = nil, timestamp: Date, duration: TimeInterval, transcription: String, title: String, summary: String, tags: [String], audioData: Data?, enrichedContent: String?, polishedText: String = "") {
        self.id = id ?? UUID()
        self.timestamp = timestamp
        self.duration = duration
        self.transcription = transcription
        self.title = title
        self.summary = summary
        self.tags = tags
        self.audioData = audioData
        self.enrichedContent = enrichedContent
        self.polishedText = polishedText
    }
    
    static func == (lhs: AudioRecording, rhs: AudioRecording) -> Bool {
        return lhs.id == rhs.id &&
               lhs.transcription == rhs.transcription &&
               lhs.title == rhs.title &&
               lhs.summary == rhs.summary &&
               lhs.tags == rhs.tags &&
               lhs.enrichedContent == rhs.enrichedContent &&
               lhs.polishedText == rhs.polishedText
    }
}