//
//  AudioStreamModule.swift
//  可复用的音频流处理模块
//
//  使用说明：
//  1. 遵循 AudioStreamModuleDelegate 协议
//  2. 创建 AudioStreamModule 实例并配置音频参数
//  3. 设置代理并开始录音/播放
//

import Foundation
import AVFoundation
import Combine

// MARK: - 音频流模块协议
public protocol AudioStreamModuleDelegate: AnyObject {
    /// 录音开始
    func audioStreamDidStartRecording(_ module: AudioStreamModule)
    
    /// 录音结束
    func audioStreamDidStopRecording(_ module: AudioStreamModule, audioData: Data, duration: TimeInterval)
    
    /// 音频振幅更新（用于可视化）
    func audioStreamDidUpdateAmplitude(_ module: AudioStreamModule, amplitude: Float)
    
    /// 播放开始
    func audioStreamDidStartPlaying(_ module: AudioStreamModule)
    
    /// 播放结束
    func audioStreamDidStopPlaying(_ module: AudioStreamModule)
    
    /// 发生错误
    func audioStreamDidEncounterError(_ module: AudioStreamModule, error: Error)
}

// MARK: - 音频配置
public struct AudioStreamConfiguration {
    let sampleRate: Double
    let channels: UInt32
    let bitsPerSample: UInt32
    let bufferDuration: TimeInterval
    let enableRealTimeMonitoring: Bool
    
    public init(
        sampleRate: Double = 16000,
        channels: UInt32 = 1,
        bitsPerSample: UInt32 = 16,
        bufferDuration: TimeInterval = 0.1,
        enableRealTimeMonitoring: Bool = false
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.bufferDuration = bufferDuration
        self.enableRealTimeMonitoring = enableRealTimeMonitoring
    }
    
    /// 标准配置：16kHz, 单声道, 16位
    public static let standard = AudioStreamConfiguration()
    
    /// 高质量配置：44.1kHz, 立体声, 16位
    public static let highQuality = AudioStreamConfiguration(
        sampleRate: 44100,
        channels: 2,
        bitsPerSample: 16
    )
}

// MARK: - 录音数据
public struct RecordingData {
    public let data: Data
    public let duration: TimeInterval
    public let configuration: AudioStreamConfiguration
    public let timestamp: Date
    
    /// 格式化的时长
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 数据大小（KB）
    public var sizeInKB: Double {
        Double(data.count) / 1024.0
    }
}

// MARK: - 可复用的音频流模块
public class AudioStreamModule: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published public var isRecording = false
    @Published public var isPlaying = false
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var currentAmplitude: Float = 0
    
    // MARK: - Private Properties
    private let configuration: AudioStreamConfiguration
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioPlayer: AVAudioPlayer?
    private var recordingData = Data()
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    // MARK: - Delegate
    public weak var delegate: AudioStreamModuleDelegate?
    
    // MARK: - Initialization
    public init(configuration: AudioStreamConfiguration = .standard) {
        self.configuration = configuration
        super.init()
        setupAudioSession()
    }
    
    deinit {
        stopRecording()
        stopPlaying()
        stopAudioEngine()
    }
    
    // MARK: - Public Methods
    
    /// 开始录音
    public func startRecording() {
        guard !isRecording else { return }
        
        do {
            try audioSession.setActive(true)
            
            recordingData = Data()
            recordingDuration = 0
            recordingStartTime = Date()
            
            startRecordingTimer()
            
            if configuration.enableRealTimeMonitoring {
                setupAudioEngineForMonitoring()
            }
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.delegate?.audioStreamDidStartRecording(self)
            }
        } catch {
            delegate?.audioStreamDidEncounterError(self, error: error)
        }
    }
    
    /// 停止录音
    public func stopRecording() {
        guard isRecording else { return }
        
        stopRecordingTimer()
        stopAudioEngine()
        
        let finalDuration = recordingDuration
        let finalData = recordingData
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingDuration = 0
            self.currentAmplitude = 0
            
            if !finalData.isEmpty {
                self.delegate?.audioStreamDidStopRecording(self, audioData: finalData, duration: finalDuration)
            }
        }
    }
    
    /// 处理接收到的音频数据（来自 WebSocket）
    public func processReceivedAudioData(_ data: Data) {
        guard isRecording else { return }
        
        recordingData.append(data)
        
        // 计算音频振幅
        let amplitude = calculateAmplitude(from: data)
        
        DispatchQueue.main.async {
            self.currentAmplitude = amplitude
            self.delegate?.audioStreamDidUpdateAmplitude(self, amplitude: amplitude)
        }
    }
    
    /// 播放录音数据
    public func playAudioData(_ data: Data) {
        stopPlaying()
        
        do {
            try audioSession.setActive(true)
            let wavData = createWAVFile(from: data)
            let tempURL = createTempFile(with: wavData)
            
            audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1.0
            
            if audioPlayer?.play() == true {
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.delegate?.audioStreamDidStartPlaying(self)
                }
            }
        } catch {
            delegate?.audioStreamDidEncounterError(self, error: error)
        }
    }
    
    /// 停止播放
    public func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.delegate?.audioStreamDidStopPlaying(self)
        }
    }
    
    /// 创建 WAV 文件数据
    public func createWAVFile(from audioData: Data) -> Data {
        var wavData = Data()
        
        let sampleRate = UInt32(configuration.sampleRate)
        let bitsPerSample = UInt16(configuration.bitsPerSample)
        let channels = UInt16(configuration.channels)
        let dataSize = UInt32(audioData.count)
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample) / 8
        let blockAlign = channels * bitsPerSample / 8
        
        // RIFF chunk
        wavData.append("RIFF".data(using: .ascii)!)
        wavData.append(UInt32(36 + dataSize).littleEndianData)
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        wavData.append(UInt32(16).littleEndianData)
        wavData.append(UInt16(1).littleEndianData)
        wavData.append(channels.littleEndianData)
        wavData.append(sampleRate.littleEndianData)
        wavData.append(byteRate.littleEndianData)
        wavData.append(blockAlign.littleEndianData)
        wavData.append(bitsPerSample.littleEndianData)
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        wavData.append(dataSize.littleEndianData)
        wavData.append(audioData)
        
        return wavData
    }
    
    // MARK: - Private Methods
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord,
                                       mode: .default,
                                       options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(false)
        } catch {
            delegate?.audioStreamDidEncounterError(self, error: error)
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func setupAudioEngineForMonitoring() {
        guard configuration.enableRealTimeMonitoring else { return }
        
        do {
            audioEngine = AVAudioEngine()
            playerNode = AVAudioPlayerNode()
            
            guard let engine = audioEngine, let node = playerNode else { return }
            
            engine.attach(node)
            let format = engine.mainMixerNode.outputFormat(forBus: 0)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            
            try engine.start()
            node.play()
        } catch {
            delegate?.audioStreamDidEncounterError(self, error: error)
            stopAudioEngine()
        }
    }
    
    private func stopAudioEngine() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }
    
    private func calculateAmplitude(from data: Data) -> Float {
        let int16Array = data.withUnsafeBytes { ptr in
            ptr.bindMemory(to: Int16.self)
        }
        
        var sum: Float = 0
        for sample in int16Array {
            let floatSample = Float(sample) / 32768.0
            sum += floatSample * floatSample
        }
        
        return sqrt(sum / Float(int16Array.count))
    }
    
    private func createTempFile(with data: Data) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("temp_audio_\(UUID().uuidString).wav")
        try? data.write(to: tempFile)
        return tempFile
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioStreamModule: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopPlaying()
    }
    
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            delegate?.audioStreamDidEncounterError(self, error: error)
        }
        stopPlaying()
    }
}

// MARK: - 音频流错误类型
public enum AudioStreamError: Error, LocalizedError {
    case audioSessionSetupFailed(String)
    case recordingFailed(String)
    case playbackFailed(String)
    case audioEngineSetupFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .audioSessionSetupFailed(let reason):
            return "音频会话设置失败: \(reason)"
        case .recordingFailed(let reason):
            return "录音失败: \(reason)"
        case .playbackFailed(let reason):
            return "播放失败: \(reason)"
        case .audioEngineSetupFailed(let reason):
            return "音频引擎设置失败: \(reason)"
        }
    }
}

// MARK: - 扩展支持
// 注意：这些扩展已在 ContentView.swift 中定义，此处不再重复声明