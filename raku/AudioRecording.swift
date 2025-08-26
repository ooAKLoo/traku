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
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: isDarkMode ? 
                    [Color.black, Color(white: 0.05)] :
                    [Color(white: 0.95), Color(white: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            RecordingsListView(
                audioManager: audioManager,
                showingDetail: $showingDetail,
                isDarkMode: isDarkMode
            )
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}



// MARK: - 录音列表视图
struct RecordingsListView: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var showingDetail: AudioRecording?
    let isDarkMode: Bool
    @State private var selectedFilter = "全部"
    @State private var showingSettings = false
    
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
                                .foregroundColor(selectedFilter == filter ? 
                                    (isDarkMode ? .white : .black) : 
                                    (isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)))
                            
                            Rectangle()
                                .fill(isDarkMode ? Color.white : Color.black)
                                .frame(height: 2)
                                .opacity(selectedFilter == filter ? 1 : 0)
                        }
                    }
                }
                
                Spacer()
                
                // 设置按钮
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            
            // 录音列表
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(audioManager.recordings) { recording in
                        RecordingCardView(recording: recording, isDarkMode: isDarkMode)
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - 录音卡片视图
struct RecordingCardView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            // 时间线指示器
            VStack {
                Circle()
                    .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                    .frame(width: 1)
            }
            
            // 卡片内容
            VStack(alignment: .leading, spacing: 8) {
                // 时间戳
                Text(formatDate(recording.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                
                // 标题（总结的第一句）
                Text(recording.summary.prefix(50) + "...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                
                // 标签
                HStack(spacing: 8) {
                    ForEach(recording.tags, id: \.self) { tag in
                        TagView(text: tag, isDarkMode: isDarkMode)
                    }
                }
                
                // 时长
                HStack {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text("\(Int(recording.duration))秒")
                        .font(.system(size: 12))
                }
                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
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
    let isDarkMode: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 设置选项列表
                    VStack(spacing: 15) {
                        // 外观设置
                        HStack {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 20))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                                .frame(width: 30)
                            
                            Text("外观")
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Spacer()
                            
                            Picker("", selection: $isDarkMode) {
                                Text("深色").tag(true)
                                Text("浅色").tag(false)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 120)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                        )
                        
                        SettingsRowView(icon: "person.circle", title: "账户", isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "bell", title: "通知", isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "lock", title: "隐私", isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "questionmark.circle", title: "帮助", isDarkMode: isDarkMode, action: {})
                        SettingsRowView(icon: "info.circle", title: "关于", isDarkMode: isDarkMode, action: {})
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - 设置行视图
struct SettingsRowView: View {
    let icon: String
    let title: String
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .frame(width: 30)
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
            )
        }
    }
}

