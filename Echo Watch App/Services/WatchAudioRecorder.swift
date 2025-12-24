//
//  WatchAudioRecorder.swift
//  Echo Watch App
//
//  录音服务 - 基于 AVAudioRecorder
//

import Foundation
import AVFoundation

final class WatchAudioRecorder: NSObject {

    // MARK: - Properties
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    private let audioSession = AVAudioSession.sharedInstance()

    // 播放状态回调
    var onPlaybackFinished: (() -> Void)?

    // 音频配置 - 使用更兼容的设置
    private var audioSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,              // 标准采样率
            AVNumberOfChannelsKey: 1,               // 单声道
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
    }

    // MARK: - Recording Directory
    private var recordingsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsPath = documentsPath.appendingPathComponent("recordings")

        // 确保目录存在
        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }

        return recordingsPath
    }

    override init() {
        super.init()
    }

    // MARK: - Public Methods

    /// 请求麦克风权限
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                print("[WatchAudioRecorder] 麦克风权限: \(granted)")
                continuation.resume(returning: granted)
            }
        }
    }

    /// 开始录音
    func startRecording() async throws -> URL {
        // 先检查权限
        let hasPermission = await requestPermission()
        print("[WatchAudioRecorder] 权限检查结果: \(hasPermission)")

        guard hasPermission else {
            throw WatchRecordingError.permissionDenied
        }

        // 配置音频会话
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            print("[WatchAudioRecorder] 音频会话配置成功")
        } catch {
            print("[WatchAudioRecorder] 音频会话配置失败: \(error)")
            throw WatchRecordingError.recordingFailed("音频会话配置失败: \(error.localizedDescription)")
        }

        // 创建录音文件
        let recordingId = UUID()
        let fileName = "\(recordingId.uuidString).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        print("[WatchAudioRecorder] 录音文件路径: \(fileURL.path)")
        print("[WatchAudioRecorder] 录音目录存在: \(FileManager.default.fileExists(atPath: recordingsDirectory.path))")

        // 创建录音器
        do {
            recorder = try AVAudioRecorder(url: fileURL, settings: audioSettings)
            recorder?.delegate = self
            print("[WatchAudioRecorder] 录音器创建成功")
        } catch {
            print("[WatchAudioRecorder] 创建录音器失败: \(error)")
            throw WatchRecordingError.recordingFailed("创建录音器失败: \(error.localizedDescription)")
        }

        guard let recorder = recorder else {
            throw WatchRecordingError.recordingFailed("录音器初始化失败")
        }

        // 准备录音
        let prepared = recorder.prepareToRecord()
        print("[WatchAudioRecorder] prepareToRecord: \(prepared)")

        // 开始录音
        let started = recorder.record()
        print("[WatchAudioRecorder] record() 返回: \(started)")

        guard started else {
            // 详细诊断
            print("[WatchAudioRecorder] 录音启动失败诊断:")
            print("  - 录音器 URL: \(recorder.url)")
            print("  - 录音器设置: \(recorder.settings)")
            print("  - 音频会话类别: \(audioSession.category)")
            print("  - 音频会话是否激活: \(audioSession.isOtherAudioPlaying)")

            throw WatchRecordingError.recordingFailed("无法启动录音")
        }

        recordingURL = fileURL
        recordingStartTime = Date()

        print("[WatchAudioRecorder] 录音已开始: \(fileURL.path)")
        return fileURL
    }

    /// 停止录音并返回录音信息
    func stopRecording() async throws -> RecordingInfo {
        guard let recorder = recorder, recorder.isRecording else {
            throw WatchRecordingError.notRecording
        }

        recorder.stop()

        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())

        guard let url = recordingURL else {
            throw WatchRecordingError.recordingFailed("录音文件不存在")
        }

        // 提取 UUID from filename
        let fileName = url.lastPathComponent
        let uuidString = fileName.replacingOccurrences(of: ".m4a", with: "")
        guard let uuid = UUID(uuidString: uuidString) else {
            throw WatchRecordingError.recordingFailed("无效的录音ID")
        }

        let info = RecordingInfo(id: uuid, duration: duration)

        // 保存元数据
        await saveMetadata(info)

        // 清理状态
        self.recorder = nil
        self.recordingURL = nil
        self.recordingStartTime = nil

        // 停用音频会话
        try? AVAudioSession.sharedInstance().setActive(false)

        return info
    }

    /// 取消录音
    func cancelRecording() async {
        recorder?.stop()

        // 删除录音文件
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        recorder = nil
        recordingURL = nil
        recordingStartTime = nil

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// 是否正在录音
    var isRecording: Bool {
        recorder?.isRecording ?? false
    }

    /// 当前录音时长
    var currentDuration: TimeInterval {
        guard let startTime = recordingStartTime, recorder?.isRecording == true else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }

    /// 获取所有待同步录音
    func getPendingRecordings() async -> [RecordingInfo] {
        let allRecordings = await loadAllMetadata()
        return allRecordings.filter { !$0.isSynced }
    }

    /// 获取所有录音
    func getAllRecordings() async -> [RecordingInfo] {
        return await loadAllMetadata()
    }

    /// 标记录音已同步
    func markAsSynced(_ id: UUID) async {
        var allRecordings = await loadAllMetadata()
        if let index = allRecordings.firstIndex(where: { $0.id == id }) {
            allRecordings[index].isSynced = true
            await saveAllMetadata(allRecordings)
        }
    }

    /// 删除录音
    func deleteRecording(_ id: UUID) async {
        var allRecordings = await loadAllMetadata()

        if let index = allRecordings.firstIndex(where: { $0.id == id }) {
            let recording = allRecordings[index]

            // 删除音频文件
            try? FileManager.default.removeItem(at: recording.fileURL)

            // 从列表中移除
            allRecordings.remove(at: index)
            await saveAllMetadata(allRecordings)
        }
    }

    // MARK: - Playback

    /// 播放录音
    func playRecording(_ recording: RecordingInfo) throws {
        // 停止当前播放
        stopPlayback()

        // 配置音频会话为播放模式
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)

        // 创建播放器
        player = try AVAudioPlayer(contentsOf: recording.fileURL)
        player?.delegate = self
        player?.play()
    }

    /// 停止播放
    func stopPlayback() {
        player?.stop()
        player = nil
        try? audioSession.setActive(false)
    }

    /// 是否正在播放
    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    /// 当前播放的时间
    var currentPlaybackTime: TimeInterval {
        player?.currentTime ?? 0
    }

    // MARK: - Metadata Management

    private var metadataURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("recording_metadata.json")
    }

    private func loadAllMetadata() async -> [RecordingInfo] {
        guard FileManager.default.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let recordings = try? JSONDecoder().decode([RecordingInfo].self, from: data) else {
            return []
        }
        return recordings
    }

    private func saveAllMetadata(_ recordings: [RecordingInfo]) async {
        guard let data = try? JSONEncoder().encode(recordings) else { return }
        try? data.write(to: metadataURL)
    }

    private func saveMetadata(_ recording: RecordingInfo) async {
        var allRecordings = await loadAllMetadata()
        allRecordings.append(recording)
        await saveAllMetadata(allRecordings)
    }
}

// MARK: - AVAudioRecorderDelegate

extension WatchAudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("[WatchAudioRecorder] 录音完成，成功: \(flag)")
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("[WatchAudioRecorder] 录音编码错误: \(error?.localizedDescription ?? "未知错误")")
    }
}

// MARK: - AVAudioPlayerDelegate

extension WatchAudioRecorder: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("[WatchAudioRecorder] 播放完成，成功: \(flag)")
        self.player = nil
        try? audioSession.setActive(false)
        onPlaybackFinished?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("[WatchAudioRecorder] 播放解码错误: \(error?.localizedDescription ?? "未知错误")")
    }
}

// MARK: - Error Types
enum WatchRecordingError: Error, LocalizedError {
    case recordingFailed(String)
    case notRecording
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .recordingFailed(let reason):
            return "录音失败: \(reason)"
        case .notRecording:
            return "当前未在录音"
        case .permissionDenied:
            return "没有麦克风权限"
        }
    }
}
