//
//  WatchConnectivityManager.swift
//  Echo Watch App
//
//  Watch 端连接管理器 - 负责与 iPhone 同步录音
//

import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    @Published var isReachable = false
    @Published var isSyncing = false
    @Published var pendingCount = 0

    private let session = WCSession.default
    private let audioRecorder = WatchAudioRecorder()

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Send Recording

    /// 发送录音文件到 iPhone
    func sendRecording(_ info: RecordingInfo) async {
        guard session.activationState == .activated else {
            print("WCSession 未激活")
            return
        }

        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: info.fileURL.path) else {
            print("录音文件不存在: \(info.fileURL.path)")
            return
        }

        let metadata: [String: Any] = [
            "id": info.id.uuidString,
            "duration": info.duration,
            "createdAt": info.createdAt.timeIntervalSince1970,
            "type": "recording"
        ]

        await MainActor.run {
            isSyncing = true
        }

        // 使用 transferFile 进行后台传输
        session.transferFile(info.fileURL, metadata: metadata)

        print("开始传输录音: \(info.id)")
    }

    /// 同步所有待传输录音
    func syncPendingRecordings() async {
        let pending = await audioRecorder.getPendingRecordings()

        await MainActor.run {
            pendingCount = pending.count
        }

        for recording in pending {
            await sendRecording(recording)
        }
    }

    /// 发送消息到 iPhone (立即传输，需要 iPhone 可达)
    func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard session.isReachable else {
            print("iPhone 不可达")
            return
        }

        session.sendMessage(message, replyHandler: replyHandler) { error in
            print("发送消息失败: \(error)")
        }
    }

    /// 更新应用上下文 (后台传输，无需 iPhone 可达)
    func updateApplicationContext(_ context: [String: Any]) {
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("更新应用上下文失败: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession 激活失败: \(error)")
            return
        }

        print("WCSession 激活成功: \(activationState.rawValue)")

        Task { @MainActor in
            isReachable = session.isReachable
        }

        // 激活后同步待传输录音
        Task {
            await syncPendingRecordings()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isReachable = session.isReachable
        }

        if session.isReachable {
            // iPhone 变为可达，同步待传输录音
            Task {
                await syncPendingRecordings()
            }
        }
    }

    // MARK: - File Transfer

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            isSyncing = false
        }

        if let error = error {
            print("文件传输失败: \(error)")
            HapticManager.shared.playError()
            return
        }

        // 传输成功，标记为已同步
        if let idString = fileTransfer.file.metadata?["id"] as? String,
           let id = UUID(uuidString: idString) {
            Task {
                await audioRecorder.markAsSynced(id)

                await MainActor.run {
                    pendingCount = max(0, pendingCount - 1)
                }

                HapticManager.shared.playSyncSuccess()
                print("录音同步成功: \(id)")
            }
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
        // 处理来自 iPhone 的消息
        if let command = message["command"] as? String {
            switch command {
            case "startRecording":
                // iPhone 请求开始录音
                NotificationCenter.default.post(name: .startRecordingFromPhone, object: nil)

            case "stopRecording":
                // iPhone 请求停止录音
                NotificationCenter.default.post(name: .stopRecordingFromPhone, object: nil)

            case "syncStatus":
                // iPhone 请求同步状态
                Task {
                    await syncPendingRecordings()
                }

            default:
                print("未知命令: \(command)")
            }
        }
    }

    // MARK: - Application Context

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // 处理来自 iPhone 的应用上下文
        print("收到应用上下文: \(applicationContext)")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingFromPhone = Notification.Name("startRecordingFromPhone")
    static let stopRecordingFromPhone = Notification.Name("stopRecordingFromPhone")
}
