//
//  RecordingDetailNavigationBar.swift
//  raku
//
//  Created by 杨东举 on 2025/9/10.
//

import SwiftUI

struct RecordingDetailNavigationBar: View {
    @ObservedObject var audioManager: AudioManagerAdapter
    let recording: AudioRecording
    let isDarkMode: Bool
    let onDismiss: () -> Void
    let onShare: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void
    let onTogglePlayback: () -> Void
    let onDownload: () -> Void
    
    @State private var showExportSheet = false
    
    var body: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // 播放控件 - 更简洁
            HStack(spacing: 12) {
                Button(action: onTogglePlayback) {
                    HStack(spacing: 8) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .contentTransition(.symbolEffect(.replace.downUp))
                        Text(FormatHelper.formatDuration(recording.duration))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: audioManager.isPlaying)
                
                // 下载按钮 - 只在播放时显示
                if audioManager.isPlaying {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: audioManager.isPlaying)
            
            Spacer()
            
            Menu {
                Button(action: onShare) {
                    Label("分享", systemImage: "square.and.arrow.up")
                }
                Button(action: { showExportSheet = true }) {
                    Label("导出", systemImage: "doc.on.doc")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .sheet(isPresented: $showExportSheet) {
            ExportOptionsSheet(
                isPresented: $showExportSheet,
                recording: recording
            )
        }
    }
}