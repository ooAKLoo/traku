# AudioWebSocketKit 使用说明

AudioWebSocketKit 是一个可复用的 iOS 音频 WebSocket 工具包，专门为 ESP32 等设备的音频传输而设计。

## 核心模块

### 1. WebSocketModule.swift
负责 WebSocket 连接管理，提供：
- 自动重连机制
- 连接状态监控
- 文本和二进制数据传输
- 错误处理

### 2. AudioStreamModule.swift
负责音频流处理，提供：
- 音频录制和播放
- WAV 文件格式转换
- 实时音频振幅计算
- 多种音频配置支持

### 3. AudioWebSocketKit.swift
整合工具包，提供：
- 简化的 API 接口
- SwiftUI 组件支持
- 完整的代理模式
- 状态管理

## 快速开始

### 1. 基本设置

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var audioKit = AudioWebSocketKit(esp32Host: "192.168.1.100")
    @State private var recordings: [RecordingData] = []
    
    var body: some View {
        VStack(spacing: 20) {
            // 连接状态显示
            AudioWebSocketKitStatusView(kit: audioKit)
            
            // 连接控制按钮
            Button(audioKit.isConnected ? "断开连接" : "连接设备") {
                if audioKit.isConnected {
                    audioKit.disconnect()
                } else {
                    audioKit.connect()
                }
            }
            
            // 录音控制按钮
            Button(audioKit.isRecording ? "停止录音" : "开始录音") {
                if audioKit.isRecording {
                    audioKit.stopRecording()
                } else {
                    audioKit.startRecording()
                }
            }
            .disabled(!audioKit.isConnected)
            
            // 录音列表
            List(recordings, id: \.timestamp) { recording in
                VStack(alignment: .leading) {
                    Text("录音 - \(recording.formattedDuration)")
                        .font(.headline)
                    Text("大小: \(String(format: "%.1f KB", recording.sizeInKB))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onTapGesture {
                    audioKit.playRecording(recording.data)
                }
            }
        }
        .padding()
        .onAppear {
            setupAudioKitDelegate()
        }
    }
    
    private func setupAudioKitDelegate() {
        // 注意：在实际项目中，建议使用 Coordinator 模式来处理代理
        // 这里为了简化示例，可以创建一个包装类
    }
}
```

### 2. 代理模式使用

```swift
class AudioManager: ObservableObject, AudioWebSocketKitDelegate {
    @Published var recordings: [RecordingData] = []
    @Published var connectionStatus = "未连接"
    @Published var isRecording = false
    
    private let audioKit: AudioWebSocketKit
    
    init(esp32Host: String) {
        self.audioKit = AudioWebSocketKit(esp32Host: esp32Host)
        self.audioKit.delegate = self
    }
    
    func connect() {
        audioKit.connect()
    }
    
    func disconnect() {
        audioKit.disconnect()
    }
    
    func startRecording() {
        audioKit.startRecording()
    }
    
    func stopRecording() {
        audioKit.stopRecording()
    }
    
    // MARK: - AudioWebSocketKitDelegate
    
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didChangeConnectionStatus isConnected: Bool, status: String) {
        connectionStatus = status
    }
    
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didChangeRecordingStatus isRecording: Bool, duration: TimeInterval) {
        self.isRecording = isRecording
    }
    
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didFinishRecording data: RecordingData) {
        recordings.append(data)
        saveRecordingToFile(data)
    }
    
    func audioWebSocketKit(_ kit: AudioWebSocketKit, didEncounterError error: Error) {
        print("错误: \(error.localizedDescription)")
        // 显示错误提示
    }
    
    private func saveRecordingToFile(_ recordingData: RecordingData) {
        let wavData = audioKit.createWAVFile(from: recordingData.data)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Int(recordingData.timestamp.timeIntervalSince1970)).wav"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        try? wavData.write(to: fileURL)
        print("录音已保存到: \(fileURL.path)")
    }
}
```

### 3. 高级配置

```swift
// 自定义 WebSocket 配置
let webSocketConfig = WebSocketConfiguration(
    host: "192.168.1.100",
    port: 8081,              // 自定义端口
    path: "/audio-stream",   // 自定义路径
    timeoutInterval: 15,     // 15秒超时
    reconnectInterval: 3,    // 3秒重连间隔
    maxReconnectAttempts: 5  // 最多重连5次
)

// 自定义音频配置
let audioConfig = AudioStreamConfiguration(
    sampleRate: 44100,                    // 44.1kHz 采样率
    channels: 2,                          // 立体声
    bitsPerSample: 16,                    // 16位深度
    bufferDuration: 0.1,                  // 100ms 缓冲
    enableRealTimeMonitoring: true        // 启用实时监听
)

// 创建自定义配置的工具包
let audioKit = AudioWebSocketKit(
    webSocketConfig: webSocketConfig,
    audioConfig: audioConfig
)
```

## 配置选项详解

### WebSocketConfiguration

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| host | String | - | ESP32 设备的 IP 地址 |
| port | Int | 81 | WebSocket 端口号 |
| path | String | "/" | WebSocket 路径 |
| timeoutInterval | TimeInterval | 10 | 连接超时时间（秒） |
| reconnectInterval | TimeInterval | 3 | 重连间隔时间（秒） |
| maxReconnectAttempts | Int | 5 | 最大重连次数 |

### AudioStreamConfiguration

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| sampleRate | Double | 16000 | 采样率 (Hz) |
| channels | UInt32 | 1 | 声道数 |
| bitsPerSample | UInt32 | 16 | 位深度 |
| bufferDuration | TimeInterval | 0.1 | 缓冲区时长（秒） |
| enableRealTimeMonitoring | Bool | false | 是否启用实时监听 |

### 预设配置

```swift
// 标准配置：16kHz, 单声道, 16位
let standardConfig = AudioStreamConfiguration.standard

// 高质量配置：44.1kHz, 立体声, 16位  
let hqConfig = AudioStreamConfiguration.highQuality
```

## 代理方法说明

### AudioWebSocketKitDelegate

```swift
// 连接状态改变
func audioWebSocketKit(_ kit: AudioWebSocketKit, didChangeConnectionStatus isConnected: Bool, status: String)

// 录音状态改变  
func audioWebSocketKit(_ kit: AudioWebSocketKit, didChangeRecordingStatus isRecording: Bool, duration: TimeInterval)

// 音频振幅更新（用于可视化）
func audioWebSocketKit(_ kit: AudioWebSocketKit, didUpdateAmplitude amplitude: Float)

// 录音完成
func audioWebSocketKit(_ kit: AudioWebSocketKit, didFinishRecording data: RecordingData)

// 错误处理
func audioWebSocketKit(_ kit: AudioWebSocketKit, didEncounterError error: Error)
```

所有代理方法都有默认实现，您只需要实现需要的方法。

## 错误处理

### 常见错误类型

1. **WebSocketError**
   - `.notConnected` - WebSocket 未连接
   - `.invalidURL` - 无效的 WebSocket URL
   - `.connectionFailed` - 连接失败
   - `.sendMessageFailed` - 发送消息失败

2. **AudioStreamError**
   - `.audioSessionSetupFailed` - 音频会话设置失败
   - `.recordingFailed` - 录音失败
   - `.playbackFailed` - 播放失败
   - `.audioEngineSetupFailed` - 音频引擎设置失败

3. **AudioWebSocketKitError**
   - `.notConnected` - 未连接到服务器
   - `.recordingInProgress` - 录音正在进行中
   - `.playbackInProgress` - 音频正在播放中

### 错误处理示例

```swift
func audioWebSocketKit(_ kit: AudioWebSocketKit, didEncounterError error: Error) {
    if let wsError = error as? WebSocketError {
        switch wsError {
        case .notConnected:
            showAlert("请先连接设备")
        case .invalidURL:
            showAlert("设备地址无效")
        case .connectionFailed(let reason):
            showAlert("连接失败: \(reason)")
        case .sendMessageFailed(let reason):
            showAlert("发送消息失败: \(reason)")
        }
    } else if let audioError = error as? AudioStreamError {
        // 处理音频相关错误
        showAlert("音频错误: \(audioError.localizedDescription)")
    }
}
```

## 最佳实践

### 1. 内存管理
- 在 `deinit` 中调用 `disconnect()`
- 及时释放不再使用的录音数据
- 使用 `weak` 引用避免循环引用

### 2. 线程安全
- 所有 UI 更新都在主线程进行
- 代理方法自动在主线程回调
- 文件操作建议在后台线程进行

### 3. 错误恢复
- 实现连接断开后的自动重连
- 提供用户友好的错误提示
- 保存录音失败时的恢复机制

### 4. 性能优化
- 合理设置音频缓冲区大小
- 根据需要选择合适的音频质量
- 及时清理临时文件

## 迁移到新项目

### 1. 复制文件
复制以下四个文件到新项目：
- `WebSocketModule.swift`
- `AudioStreamModule.swift` 
- `AudioWebSocketKit.swift`
- `DataExtensions.swift` (包含必要的数据类型扩展)

### 2. 添加权限
在 `Info.plist` 中添加：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限来录制音频</string>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 3. 基本集成
```swift
// 1. 创建实例
let audioKit = AudioWebSocketKit(esp32Host: "YOUR_ESP32_IP")

// 2. 设置代理（如果需要）
audioKit.delegate = self

// 3. 连接和使用
audioKit.connect()
audioKit.startRecording()
```

这样就可以在任何 iOS 项目中快速集成 ESP32 音频传输功能了！

## 支持的 iOS 版本

- iOS 14.0+
- iPadOS 14.0+
- macOS 11.0+（使用 Mac Catalyst）

## 技术要求

- Swift 5.5+
- Xcode 13.0+
- ESP32 设备支持 WebSocket 音频传输