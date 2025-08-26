//
//  AudioRecording.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//


import SwiftUI
import AVFoundation
import Combine

// MARK: - 数据模型
struct AudioRecording: Identifiable {
    let id = UUID()
    let timestamp: Date
    let duration: TimeInterval
    let transcription: String
    let summary: String
    let tags: [String]
    let audioData: Data?
    var isPlaying: Bool = false
}

// MARK: - 主视图
struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showingDetail: AudioRecording? = nil
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [Color.black, Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            RecordingsListView(
                audioManager: audioManager,
                showingDetail: $showingDetail
            )
        }
        .preferredColorScheme(.dark)
    }
}



// MARK: - 录音列表视图
struct RecordingsListView: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var showingDetail: AudioRecording?
    @State private var selectedFilter = "全部"
    
    let filters = ["全部", "标签", "时间"]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部筛选栏
            HStack(spacing: 20) {
                ForEach(filters, id: \.self) { filter in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text(filter)
                                .font(.system(size: 16, weight: selectedFilter == filter ? .semibold : .regular))
                                .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.5))
                            
                            Rectangle()
                                .fill(Color.white)
                                .frame(height: 2)
                                .opacity(selectedFilter == filter ? 1 : 0)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            
            // 录音列表
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(audioManager.recordings) { recording in
                        RecordingCardView(recording: recording)
                            .onTapGesture {
                                showingDetail = recording
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
        }
        .sheet(item: $showingDetail) { recording in
            RecordingDetailView(recording: recording)
        }
    }
}

// MARK: - 录音卡片视图
struct RecordingCardView: View {
    let recording: AudioRecording
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 时间线指示器
            VStack {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1)
            }
            
            // 卡片内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间戳
                Text(formatDate(recording.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                
                // 标题（总结的第一句）
                Text(recording.summary.prefix(50) + "...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                // 标签
                HStack(spacing: 8) {
                    ForEach(recording.tags, id: \.self) { tag in
                        TagView(text: tag)
                    }
                }
                
                // 时长
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text("\(Int(recording.duration))秒")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 标签视图
struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

