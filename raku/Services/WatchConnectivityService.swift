//
//  WatchConnectivityService.swift
//  raku
//
//  iPhone 端 WatchConnectivity 服务 - 接收来自 Apple Watch 的录音
//

import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityService: NSObject, ObservableObject {

    static let shared = WatchConnectivityService()

    // MARK: - Published Properties

    @Published var isReachable = false
    @Published var isWatchAppInstalled = false
    @Published var receivedRecordingsCount = 0

    // MARK: - Private Properties

    private let session = WCSession.default
    private var cancellables = Set<AnyCancellable>()

    // 录音保存目录
    private var watchRecordingsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let watchPath = documentsPath.appendingPathComponent("watch_recordings")

        if !FileManager.default.fileExists(atPath: watchPath.path) {
            try? FileManager.default.createDirectory(at: watchPath, withIntermediateDirectories: true)
        }

        return watchPath
    }

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else {
            print("WCSession 不支持")
            return
        }

        session.delegate = self
        session.activate()
    }

    // MARK: - Send Commands to Watch

    /// 请求 Watch 开始录音
    func requestStartRecording() {
        sendMessage(["command": "startRecording"])
    }

    /// 请求 Watch 停止录音
    func requestStopRecording() {
        sendMessage(["command": "stopRecording"])
    }

    /// 请求同步状态
    func requestSyncStatus() {
        sendMessage(["command": "syncStatus"])
    }

    /// 发送消息到 Watch
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard session.isReachable else {
            print("Watch 不可达")
            return
        }

        session.sendMessage(message, replyHandler: replyHandler) { error in
            print("发送消息到 Watch 失败: \(error)")
        }
    }

    /// 更新应用上下文
    func updateApplicationContext(_ context: [String: Any]) {
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("更新应用上下文失败: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession 激活失败: \(error)")
            return
        }

        print("WCSession 激活成功: \(activationState.rawValue)")

        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession 变为非活动状态")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession 已停用，重新激活...")
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    // MARK: - File Transfer

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("收到来自 Watch 的文件: \(file.fileURL)")

        guard let metadata = file.metadata,
              let idString = metadata["id"] as? String,
              let duration = metadata["duration"] as? TimeInterval,
              let createdAtTimestamp = metadata["createdAt"] as? TimeInterval else {
            print("元数据解析失败")
            return
        }

        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)

        // 移动文件到应用目录
        let destinationURL = watchRecordingsDirectory.appendingPathComponent("\(idString).m4a")

        do {
            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: file.fileURL, to: destinationURL)
            print("录音文件已保存: \(destinationURL)")

            // 处理录音
            Task {
                await processWatchRecording(
                    id: idString,
                    fileURL: destinationURL,
                    duration: duration,
                    createdAt: createdAt
                )
            }

            DispatchQueue.main.async {
                self.receivedRecordingsCount += 1
            }

        } catch {
            print("保存录音文件失败: \(error)")
        }
    }

    // MARK: - Message Receiving

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        print("收到来自 Watch 的消息: \(message)")

        // 处理来自 Watch 的消息
        if let status = message["status"] as? String {
            switch status {
            case "recordingStarted":
                NotificationCenter.default.post(name: .watchRecordingStarted, object: nil)

            case "recordingStopped":
                NotificationCenter.default.post(name: .watchRecordingStopped, object: nil)

            default:
                break
            }
        }
    }

    // MARK: - Application Context

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("收到应用上下文: \(applicationContext)")
    }

    // MARK: - Recording Processing

    /// 处理来自 Watch 的录音
    /// 创建独立的 Pipeline 实例来处理 Watch 录音
    private func processWatchRecording(id: String, fileURL: URL, duration: TimeInterval, createdAt: Date) async {
        do {
            // 读取音频数据
            let audioData = try Data(contentsOf: fileURL)

            // 创建独立的 Pipeline 实例处理 Watch 录音
            let pipeline = AudioProcessingPipeline()

            // 直接调用处理方法
            pipeline.processRecording(audioData: audioData, duration: duration)

            print("Watch 录音已提交处理: \(id)")

            // 发送通知
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .watchRecordingProcessed,
                    object: nil,
                    userInfo: ["id": id]
                )
            }

        } catch {
            print("处理 Watch 录音失败: \(error)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let watchRecordingStarted = Notification.Name("watchRecordingStarted")
    static let watchRecordingStopped = Notification.Name("watchRecordingStopped")
    static let watchRecordingProcessed = Notification.Name("watchRecordingProcessed")
    static let watchRecordingReceived = Notification.Name("watchRecordingReceived")
}
