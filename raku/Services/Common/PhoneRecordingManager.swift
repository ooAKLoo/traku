//
//  PhoneRecordingManager.swift
//  手机录音管理器 - 专门处理设备本地录音功能
//

import Foundation
import AVFoundation
import Combine

// MARK: - 手机录音管理器协议
protocol PhoneRecordingManagerDelegate: AnyObject {
    /// 录音开始
    func phoneRecordingDidStart(_ manager: PhoneRecordingManager)
    
    /// 录音完成
    func phoneRecording(_ manager: PhoneRecordingManager, didFinishWithAudioData audioData: Data, duration: TimeInterval)
    
    /// 录音失败
    func phoneRecording(_ manager: PhoneRecordingManager, didFailWithError error: Error)
}

// MARK: - 手机录音管理器
class PhoneRecordingManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var duration: TimeInterval = 0
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var pausedRecordingURL: URL?
    private var recordingSegments: [Data] = []
    private var recordingStartTime: Date?
    
    // MARK: - Delegate
    weak var delegate: PhoneRecordingManagerDelegate?
    
    // MARK: - Public Methods
    
    /// 开始录音
    func startRecording() {
        guard !isRecording else { return }
        
        resetRecordingState()
        setupAndStartRecording()
    }
    
    /// 停止录音
    func stopRecording() {
        guard isRecording else { return }
        
        stopCurrentRecording()
    }
    
    /// 暂停录音
    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        
        isPaused = true
        pauseCurrentRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    /// 恢复录音
    func resumeRecording() {
        guard isRecording, isPaused else { return }
        
        isPaused = false
        resumeCurrentRecording()
        startRecordingTimer()
    }
    
    /// 检查并请求录音权限
    func checkAndRequestPermissions(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            print("✅ 麦克风权限已授权")
            completion(true)
            
        case .denied:
            print("❌ 麦克风权限被拒绝")
            completion(false)
            
        case .undetermined:
            print("🔔 请求麦克风权限")
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    print(granted ? "✅ 用户授权麦克风权限" : "❌ 用户拒绝麦克风权限")
                    completion(granted)
                }
            }
            
        @unknown default:
            completion(false)
        }
    }
    
    /// 诊断音频配置
    func diagnoseAudioConfiguration() {
        let session = AVAudioSession.sharedInstance()
        
        print("===== 音频配置诊断 =====")
        print("🎯 当前类别: \(session.category.rawValue)")
        print("🎯 当前模式: \(session.mode.rawValue)")
        print("🎯 采样率: \(session.sampleRate) Hz")
        print("🎯 输入通道数: \(session.inputNumberOfChannels)")
        print("🎯 当前输入: \(session.currentRoute.inputs.first?.portName ?? "无")")
        print("🎯 可用输入设备:")
        
        session.availableInputs?.forEach { input in
            print("  - \(input.portName) (\(input.portType.rawValue))")
        }
        
        print("========================")
    }
    
    // MARK: - Private Methods
    
    private func resetRecordingState() {
        duration = 0
        isPaused = false
        recordingSegments.removeAll()
        pausedRecordingURL = nil
        recordingStartTime = Date()
    }
    
    private func setupAndStartRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // 配置音频会话
            try audioSession.setCategory(.playAndRecord,
                                        mode: .measurement,
                                        options: [.defaultToSpeaker, .allowBluetooth])
            
            // 设置首选输入为内置麦克风
            if let builtInMic = audioSession.availableInputs?.first(where: {
                $0.portType == .builtInMic
            }) {
                try audioSession.setPreferredInput(builtInMic)
            }
            
            // 激活音频会话
            try audioSession.setActive(true)
            
            // 创建录音文件路径
            let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                        in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent(
                "recording_\(Date().timeIntervalSince1970).wav"
            )
            
            // 录音设置
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // 删除旧文件（如果存在）
            if FileManager.default.fileExists(atPath: audioFilename.path) {
                try FileManager.default.removeItem(at: audioFilename)
            }
            
            // 创建并配置录音器
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // 开始录音
            let recordingStarted = audioRecorder?.record() ?? false
            
            if recordingStarted {
                print("✅ 手机录音已开始")
                print("📁 录音文件路径: \(audioFilename.path)")
                
                isRecording = true
                startRecordingTimer()
                delegate?.phoneRecordingDidStart(self)
                
            } else {
                print("❌ 录音启动失败")
                throw PhoneRecordingError.recordingStartFailed
            }
            
        } catch {
            print("❌ 设置录音失败: \(error.localizedDescription)")
            delegate?.phoneRecording(self, didFailWithError: error)
        }
    }
    
    private func stopCurrentRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard let recorder = audioRecorder else {
            print("⚠️ 录音器不存在")
            if !recordingSegments.isEmpty {
                processRecordingSegments()
            }
            return
        }
        
        let recordingTime = duration
        print("📊 停止录音，时长: \(recordingTime)秒")
        
        recorder.stop()
        isRecording = false
        
        // 等待文件写入完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            let fileURL = recorder.url
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    let finalSegmentData = try Data(contentsOf: fileURL)
                    
                    if finalSegmentData.count > 0 {
                        self.recordingSegments.append(finalSegmentData)
                        print("✅ 保存最终录音片段，大小: \(finalSegmentData.count / 1024) KB")
                    }
                    
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: fileURL)
                    
                    // 处理录音片段
                    self.processRecordingSegments()
                    
                } catch {
                    print("❌ 读取最终录音文件失败: \(error.localizedDescription)")
                    self.processRecordingSegments()
                }
            } else {
                print("❌ 最终录音文件不存在")
                self.processRecordingSegments()
            }
            
            self.audioRecorder = nil
        }
        
        // 重置音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("⚠️ 重置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    private func pauseCurrentRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        let currentURL = recorder.url
        recorder.stop()
        
        // 读取并保存当前录音数据
        if FileManager.default.fileExists(atPath: currentURL.path) {
            do {
                let segmentData = try Data(contentsOf: currentURL)
                recordingSegments.append(segmentData)
                print("✅ 保存录音片段，大小: \(segmentData.count / 1024) KB")
                
                // 删除临时文件
                try? FileManager.default.removeItem(at: currentURL)
            } catch {
                print("❌ 保存录音片段失败: \(error.localizedDescription)")
            }
        }
        
        pausedRecordingURL = currentURL
        print("⏸ 录音已暂停")
    }
    
    private func resumeCurrentRecording() {
        guard pausedRecordingURL != nil else { return }
        
        do {
            // 创建新的录音文件
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let newAudioFilename = documentsPath.appendingPathComponent("recording_resume_\(Date().timeIntervalSince1970).wav")
            
            // 使用相同的录音设置
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            // 删除旧文件（如果存在）
            if FileManager.default.fileExists(atPath: newAudioFilename.path) {
                try FileManager.default.removeItem(at: newAudioFilename)
            }
            
            // 创建新的录音器
            audioRecorder = try AVAudioRecorder(url: newAudioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // 开始新的录音
            let recordingStarted = audioRecorder?.record() ?? false
            
            if recordingStarted {
                print("▶️ 录音已恢复")
                pausedRecordingURL = nil
            } else {
                print("❌ 恢复录音失败")
                throw PhoneRecordingError.recordingResumeFailed
            }
            
        } catch {
            print("❌ 恢复录音设置失败: \(error.localizedDescription)")
            delegate?.phoneRecording(self, didFailWithError: error)
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            self.duration = recorder.currentTime
            
            // 获取音频级别用于调试
            let averagePower = recorder.averagePower(forChannel: 0)
            let peakPower = recorder.peakPower(forChannel: 0)
            
            // 每秒打印一次调试信息
            if Int(self.duration * 10) % 10 == 0 {
                print("🎤 录音中 - 时长: \(String(format: "%.1f", self.duration))s, 平均音量: \(averagePower)dB, 峰值: \(peakPower)dB")
            }
            
            // 检测是否有声音输入
            if averagePower < -160 {
                print("⚠️ 检测到静音，请检查麦克风权限和输入源")
            }
        }
    }
    
    private func processRecordingSegments() {
        let finalAudioData: Data
        let finalDuration = duration
        
        if recordingSegments.isEmpty {
            print("❌ 没有录音片段可处理")
            delegate?.phoneRecording(self, didFailWithError: PhoneRecordingError.noRecordingData)
            return
        }
        
        // 合并录音片段
        if let mergedData = mergeRecordingSegments() {
            finalAudioData = mergedData
        } else {
            print("❌ 合并录音片段失败")
            delegate?.phoneRecording(self, didFailWithError: PhoneRecordingError.mergeFailed)
            return
        }
        
        print("✅ 最终录音数据大小: \(finalAudioData.count / 1024) KB，时长: \(finalDuration)秒")
        
        if finalAudioData.count > 0 {
            delegate?.phoneRecording(self, didFinishWithAudioData: finalAudioData, duration: finalDuration)
        } else {
            print("❌ 最终录音文件为空")
            delegate?.phoneRecording(self, didFailWithError: PhoneRecordingError.emptyRecording)
        }
    }
    
    private func mergeRecordingSegments() -> Data? {
        guard !recordingSegments.isEmpty else { return nil }
        
        // 如果只有一个片段，直接返回
        if recordingSegments.count == 1 {
            return recordingSegments.first
        }
        
        // 音频片段合并
        var mergedAudioData = Data()
        var totalSamples: UInt32 = 0
        
        for (index, segment) in recordingSegments.enumerated() {
            let audioData = extractAudioDataFromWAV(segment)
            
            if index == 0 {
                // 第一个片段：保留完整音频数据
                mergedAudioData.append(audioData)
                totalSamples += UInt32(audioData.count / 2)
            } else {
                // 后续片段：应用渐变处理减少咔嗒声
                let processedAudio = applyCrossfade(mergedAudioData, newAudio: audioData)
                mergedAudioData = processedAudio
                totalSamples += UInt32(audioData.count / 2)
            }
        }
        
        // 创建新的WAV文件头
        let finalWAV = createWAVHeader(audioDataSize: mergedAudioData.count) + mergedAudioData
        
        print("✅ 合并了 \(recordingSegments.count) 个录音片段，总大小: \(finalWAV.count / 1024) KB，总采样数: \(totalSamples)")
        return finalWAV
    }
    
    private func extractAudioDataFromWAV(_ wavData: Data) -> Data {
        guard wavData.count > 44 else { return wavData }
        
        // 查找"data"标识符
        let dataMarker: [UInt8] = [0x64, 0x61, 0x74, 0x61] // "data"
        
        for i in 0..<(wavData.count - 4) {
            let slice = wavData.subdata(in: i..<(i+4))
            if slice.elementsEqual(dataMarker) {
                let audioStartIndex = i + 8
                if audioStartIndex < wavData.count {
                    return wavData.subdata(in: audioStartIndex..<wavData.count)
                }
            }
        }
        
        // 如果找不到data标记，使用默认44字节偏移
        return wavData.subdata(in: 44..<wavData.count)
    }
    
    private func applyCrossfade(_ existingAudio: Data, newAudio: Data) -> Data {
        let crossfadeSamples = 160 // 10ms at 16kHz
        let crossfadeBytes = crossfadeSamples * 2
        
        guard existingAudio.count >= crossfadeBytes,
              newAudio.count >= crossfadeBytes else {
            print("⚠️ 音频片段太短，跳过交叉淡化")
            return existingAudio + newAudio
        }
        
        var result = Data(existingAudio)
        
        let existingEndBytes = Array(existingAudio.suffix(crossfadeBytes))
        let newStartBytes = Array(newAudio.prefix(crossfadeBytes))
        
        print("🔄 应用交叉淡化: \(crossfadeSamples)样本")
        
        var crossfadeData = Data()
        crossfadeData.reserveCapacity(crossfadeBytes)
        
        for i in 0..<crossfadeSamples {
            let byteIndex = i * 2
            
            guard byteIndex + 1 < existingEndBytes.count,
                  byteIndex + 1 < newStartBytes.count else {
                break
            }
            
            // 读取16位PCM样本
            let existingSample = Int16(existingEndBytes[byteIndex]) | (Int16(existingEndBytes[byteIndex + 1]) << 8)
            let newSample = Int16(newStartBytes[byteIndex]) | (Int16(newStartBytes[byteIndex + 1]) << 8)
            
            // 计算交叉淡化权重
            let fadeOut = Float(crossfadeSamples - i) / Float(crossfadeSamples)
            let fadeIn = Float(i) / Float(crossfadeSamples)
            
            // 混合样本
            let mixedSample = Int16(Float(existingSample) * fadeOut + Float(newSample) * fadeIn)
            
            // 写回数据
            crossfadeData.append(UInt8(mixedSample & 0xFF))
            crossfadeData.append(UInt8((mixedSample >> 8) & 0xFF))
        }
        
        // 替换重叠区域并添加剩余的新音频
        result.removeLast(crossfadeBytes)
        result.append(crossfadeData)
        result.append(newAudio.suffix(from: crossfadeBytes))
        
        return result
    }
    
    private func createWAVHeader(audioDataSize: Int) -> Data {
        var header = Data()
        
        // RIFF头
        header.append("RIFF".data(using: .ascii)!)
        let fileSize = UInt32(36 + audioDataSize)
        header.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)
        
        // fmt子块
        header.append("fmt ".data(using: .ascii)!)
        let fmtSize = UInt32(16)
        header.append(withUnsafeBytes(of: fmtSize.littleEndian) { Data($0) })
        let audioFormat = UInt16(1) // PCM
        header.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
        let numChannels = UInt16(1) // Mono
        header.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        let sampleRate = UInt32(16000)
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        let byteRate = UInt32(16000 * 1 * 16 / 8)
        header.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        let blockAlign = UInt16(1 * 16 / 8)
        header.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        let bitsPerSample = UInt16(16)
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        
        // data子块
        header.append("data".data(using: .ascii)!)
        let dataSize = UInt32(audioDataSize)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        
        return header
    }
}

// MARK: - AVAudioRecorderDelegate
extension PhoneRecordingManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            delegate?.phoneRecording(self, didFailWithError: PhoneRecordingError.recordingFinishFailed)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            delegate?.phoneRecording(self, didFailWithError: error)
        }
    }
}

// MARK: - 错误类型
enum PhoneRecordingError: Error, LocalizedError {
    case recordingStartFailed
    case recordingFinishFailed
    case recordingResumeFailed
    case noRecordingData
    case mergeFailed
    case emptyRecording
    
    var errorDescription: String? {
        switch self {
        case .recordingStartFailed:
            return "录音启动失败"
        case .recordingFinishFailed:
            return "录音结束失败"
        case .recordingResumeFailed:
            return "录音恢复失败"
        case .noRecordingData:
            return "没有录音数据"
        case .mergeFailed:
            return "合并录音片段失败"
        case .emptyRecording:
            return "录音文件为空"
        }
    }
}