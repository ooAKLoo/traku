//
//  RecordingListView.swift
//  Echo Watch App
//
//  录音列表视图 - 使用 Digital Crown 滚动查看
//

import SwiftUI
import Combine

struct RecordingListView: View {
    @StateObject private var viewModel = RecordingListViewModel()

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.1),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部标题栏
                HStack {
                    Text("录音")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // 同步按钮
                    Button {
                        viewModel.syncAll()
                    } label: {
                        Image(systemName: viewModel.isSyncing ? "arrow.triangle.2.circlepath" : "iphone.and.arrow.right.outward")
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.isSyncing ? .blue : .white.opacity(0.8))
                            .rotationEffect(.degrees(viewModel.isSyncing ? 360 : 0))
                            .animation(viewModel.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isSyncing)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 10)

                // 内容区域
                if viewModel.recordings.isEmpty {
                    emptyStateView
                } else {
                    recordingsList
                }
            }
        }
        .onAppear {
            viewModel.loadRecordings()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // 图标容器
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 70, height: 70)

                Image(systemName: "waveform.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.6), .green.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 6) {
                Text("暂无录音")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text("向上滑动开始录音")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Recordings List

    private var recordingsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.recordings) { recording in
                    RecordingRow(
                        recording: recording,
                        isPlaying: viewModel.playingRecordingId == recording.id,
                        onTap: {
                            viewModel.togglePlayback(recording)
                        },
                        onDelete: {
                            viewModel.deleteRecording(recording)
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Recording Row

struct RecordingRow: View {
    let recording: RecordingInfo
    let isPlaying: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // 删除按钮背景
            if showDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            // 主内容
            HStack(spacing: 10) {
                // 播放/波形图标
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isPlaying ? Color.blue.opacity(0.2) : (recording.isSynced ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)))
                        .frame(width: 32, height: 32)

                    if isPlaying {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(recording.isSynced ? .green : .orange)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    // 时长
                    Text(formattedDuration)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)

                    // 时间或播放状态
                    if isPlaying {
                        Text("播放中...")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    } else {
                        Text(formattedTime)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                // 同步状态图标
                Image(systemName: recording.isSynced ? "checkmark.circle.fill" : "arrow.up.circle")
                    .font(.system(size: 16))
                    .foregroundColor(recording.isSynced ? .green : .orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isPlaying ? Color.blue.opacity(0.1) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = max(value.translation.width, -60)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            if value.translation.width < -30 {
                                offset = -55
                                showDelete = true
                            } else {
                                offset = 0
                                showDelete = false
                            }
                        }
                    }
            )
            .onTapGesture {
                if showDelete {
                    withAnimation(.spring()) {
                        offset = 0
                        showDelete = false
                    }
                } else {
                    onTap()
                }
            }
        }
    }

    private var formattedDuration: String {
        let minutes = Int(recording.duration) / 60
        let seconds = Int(recording.duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: recording.createdAt)
    }
}

// MARK: - ViewModel

@MainActor
class RecordingListViewModel: ObservableObject {
    @Published var recordings: [RecordingInfo] = []
    @Published var isSyncing = false
    @Published var playingRecordingId: UUID?

    private let audioRecorder = WatchAudioRecorder()

    init() {
        audioRecorder.onPlaybackFinished = { [weak self] in
            Task { @MainActor in
                self?.playingRecordingId = nil
            }
        }
    }

    func loadRecordings() {
        Task {
            let allRecordings = await audioRecorder.getAllRecordings()
            recordings = allRecordings.sorted { $0.createdAt > $1.createdAt }
        }
    }

    func togglePlayback(_ recording: RecordingInfo) {
        if playingRecordingId == recording.id {
            // 停止播放
            audioRecorder.stopPlayback()
            playingRecordingId = nil
            HapticManager.shared.playClick()
        } else {
            // 开始播放
            do {
                try audioRecorder.playRecording(recording)
                playingRecordingId = recording.id
                HapticManager.shared.playClick()
            } catch {
                print("播放失败: \(error)")
                HapticManager.shared.playError()
            }
        }
    }

    func deleteRecording(_ recording: RecordingInfo) {
        // 如果正在播放该录音，先停止
        if playingRecordingId == recording.id {
            audioRecorder.stopPlayback()
            playingRecordingId = nil
        }

        Task {
            await audioRecorder.deleteRecording(recording.id)
            loadRecordings()
            HapticManager.shared.playClick()
        }
    }

    func syncAll() {
        isSyncing = true
        Task {
            await WatchConnectivityManager.shared.syncPendingRecordings()
            isSyncing = false
            loadRecordings()
        }
    }
}

#Preview {
    RecordingListView()
}
