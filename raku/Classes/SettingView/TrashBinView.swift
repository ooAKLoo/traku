//
//  TrashBinView.swift
//  raku
//
//  回收站页面 - 显示已删除的录音，支持恢复和清空操作
//

import SwiftUI

struct TrashBinView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = RecordingStore.shared

    @State private var showingEmptyConfirm = false

    private var isDarkMode: Bool { colorScheme == .dark }

    var body: some View {
        NavigationView {
            ZStack {
                // 背景 - 与首页一致
                (isDarkMode ? Color.black : Color(white: 0.96))
                    .ignoresSafeArea()

                if store.deletedRecordings.isEmpty {
                    emptyStateView
                } else {
                    trashListView
                }
            }
            .navigationTitle(L("settings_trash_bin"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                    }
                }

                if !store.deletedRecordings.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingEmptyConfirm = true }) {
                            Text(L("trash_clear_all"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.9))
                        }
                    }
                }
            }
        }
        .alert(L("trash_clear_all"), isPresented: $showingEmptyConfirm) {
            Button(L("common_cancel"), role: .cancel) { }
            Button(L("trash_delete_permanently"), role: .destructive) {
                store.emptyTrash()
            }
        } message: {
            Text(L("trash_clear_confirm"))
        }
        .onAppear {
            store.loadDeletedFromDatabase()
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // 图标容器
            ZStack {
                Circle()
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    .frame(width: 100, height: 100)

                Image(systemName: "trash")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(isDarkMode ? .white.opacity(0.25) : .black.opacity(0.2))
            }

            VStack(spacing: 8) {
                Text(L("trash_empty"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))

                Text(L("trash_empty_description"))
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 50)
            }
        }
    }

    // MARK: - Trash List
    private var trashListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                // 提示信息
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text(L("trash_auto_delete_hint"))
                        .font(.system(size: 12))
                }
                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.35))
                .padding(.bottom, 6)

                ForEach(store.deletedRecordings, id: \.id) { recording in
                    TrashItemCard(
                        recording: recording,
                        isDarkMode: isDarkMode,
                        onRestore: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                store.restoreRecording(recording)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Trash Item Card
struct TrashItemCard: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 卡片内容
            VStack(alignment: .leading, spacing: 0) {
                // 剩余天数
                if let days = recording.daysUntilPermanentDeletion {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(L("trash_days_remaining").replacingOccurrences(of: "%d", with: "\(days)"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(days <= 3 ? .red.opacity(0.8) : .orange.opacity(0.7))

                    Spacer().frame(height: 10)
                }

                // 标题
                Text(recording.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // 摘要
                if !recording.summary.isEmpty {
                    Spacer().frame(height: 8)
                    Text(recording.summary)
                        .font(.system(size: 13))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.45))
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                Spacer().frame(height: 12)

                // 标签
                if !recording.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(recording.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.45))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                )
                        }
                        if recording.tags.count > 3 {
                            Text("+\(recording.tags.count - 3)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.35) : .black.opacity(0.3))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 恢复按钮
            Button(action: onRestore) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.green.opacity(0.12))
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
        )
    }
}

// MARK: - Preview
#Preview("有数据") {
    TrashBinPreviewWrapper(hasData: true)
}

#Preview("空状态") {
    TrashBinPreviewWrapper(hasData: false)
}

// MARK: - Preview Helper
private struct TrashBinPreviewWrapper: View {
    let hasData: Bool
    @State private var previewRecordings: [AudioRecording] = []
    @Environment(\.colorScheme) private var colorScheme

    private var isDarkMode: Bool { colorScheme == .dark }

    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.96))
                    .ignoresSafeArea()

                if previewRecordings.isEmpty {
                    // 空状态
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                                .frame(width: 100, height: 100)

                            Image(systemName: "trash")
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(isDarkMode ? .white.opacity(0.25) : .black.opacity(0.2))
                        }

                        VStack(spacing: 8) {
                            Text("回收站为空")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))

                            Text("已删除的录音会在7天后自动永久删除")
                                .font(.system(size: 14))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.35))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 50)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12))
                                Text("点击恢复按钮可恢复录音，7天后自动永久删除")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.35))
                            .padding(.bottom, 6)

                            ForEach(previewRecordings, id: \.id) { recording in
                                TrashItemCard(
                                    recording: recording,
                                    isDarkMode: isDarkMode,
                                    onRestore: { }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("回收站")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                    }
                }

                if !previewRecordings.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { }) {
                            Text("清空回收站")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red.opacity(0.9))
                        }
                    }
                }
            }
        }
        .onAppear {
            if hasData {
                previewRecordings = [
                    AudioRecording(
                        id: UUID(),
                        timestamp: Date().addingTimeInterval(-86400 * 2),
                        duration: 125,
                        transcription: "这是一段关于产品设计的讨论录音",
                        title: "产品设计讨论会议",
                        summary: "讨论了新版本的UI设计方向和用户体验优化方案",
                        tags: ["会议", "产品", "设计"],
                        audioData: nil,
                        enrichedContent: nil,
                        deletedAt: Date().addingTimeInterval(-86400 * 1)
                    ),
                    AudioRecording(
                        id: UUID(),
                        timestamp: Date().addingTimeInterval(-86400 * 5),
                        duration: 89,
                        transcription: "今天的灵感记录",
                        title: "关于AI助手的思考",
                        summary: "思考了如何让AI助手更好地理解用户意图",
                        tags: ["灵感", "AI"],
                        audioData: nil,
                        enrichedContent: nil,
                        deletedAt: Date().addingTimeInterval(-86400 * 5)
                    ),
                    AudioRecording(
                        id: UUID(),
                        timestamp: Date().addingTimeInterval(-86400 * 3),
                        duration: 210,
                        transcription: "项目进度同步",
                        title: "Q4项目规划",
                        summary: "规划了第四季度的主要目标和里程碑",
                        tags: ["工作", "规划", "项目", "季度总结"],
                        audioData: nil,
                        enrichedContent: nil,
                        deletedAt: Date().addingTimeInterval(-86400 * 6)
                    )
                ]
            }
        }
    }
}
