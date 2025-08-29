# raku 项目音频模块集成说明

## 🎯 概述

已成功将 Traku2 项目中的模块化 WebSocket 和音频处理组件集成到 raku 项目中。通过适配器模式，现有代码无需大幅修改即可使用新的模块化服务。

## 📁 新增文件结构

```
Services/
├── WebSocketModule.swift          # WebSocket 连接管理模块
├── AudioStreamModule.swift       # 音频流处理模块  
├── DataExtensions.swift          # 数据类型扩展
├── ESP32AudioService.swift       # ESP32 专用音频服务
├── AudioManagerAdapter.swift     # 适配器（兼容原 AudioManager）
└── README_Integration.md         # 本说明文件
```

## 🔄 架构说明

### 模块化架构
```
┌─────────────────────┐
│   AudioManagerAdapter  │ ← 适配器层，保持原有接口
├─────────────────────┤
│   ESP32AudioService    │ ← 业务逻辑层，专为 ESP32 设计
├─────────────────────┤
│ WebSocketModule │ AudioStreamModule │ ← 核心模块层
├─────────────────────┤
│   DataExtensions       │ ← 基础扩展层
└─────────────────────┘
```

### 适配器模式
- **AudioManagerAdapter**: 包装新的 ESP32AudioService
- **保持兼容性**: 原有的 UI 代码无需修改
- **渐进式迁移**: 可以逐步替换旧的实现

## 🚀 主要改动

### 1. AudioManager 替换
```swift
// 原来
@StateObject private var audioManager = AudioManager()

// 现在  
@StateObject private var audioManager = AudioManagerAdapter()
```

### 2. 类型声明更新
所有引用 `AudioManager` 的地方都已更新为 `AudioManagerAdapter`：
- `ContentView.swift`
- `RecordingsListView` 
- `RecordingControlView`
- `ConnectionConfigView.swift`

### 3. 保持的接口
所有原有方法调用保持不变：
```swift
audioManager.connectToDevice(device)
audioManager.startRecording()
audioManager.stopRecording()
audioManager.isConnected
audioManager.recordings
```

## ✨ 新功能特性

### 1. 增强的 WebSocket 连接
- **自动重连**: 连接断开后自动尝试重连
- **状态管理**: 详细的连接状态跟踪
- **错误处理**: 完善的错误处理机制
- **配置灵活**: 可自定义连接参数

### 2. 改进的音频处理
- **模块化设计**: 音频处理逻辑独立封装
- **WAV 格式支持**: 自动生成标准 WAV 文件
- **实时监听**: 可选的实时音频监听功能
- **振幅计算**: 准确的音频振幅可视化

### 3. 更好的设备管理
- **设备发现**: 继续使用原有的设备发现机制
- **连接管理**: 改进的设备连接和断开逻辑
- **状态同步**: 实时的连接状态同步

## 🔧 使用方式

### 基本使用（与原来相同）
```swift
struct MyView: View {
    @StateObject private var audioManager = AudioManagerAdapter()
    
    var body: some View {
        VStack {
            // 连接状态显示
            Text(audioManager.connectionStatus)
            
            // 录音按钮
            Button(audioManager.isRecording ? "停止录音" : "开始录音") {
                if audioManager.isRecording {
                    audioManager.stopRecording()
                } else {
                    audioManager.startRecording()
                }
            }
            .disabled(!audioManager.isConnected)
            
            // 录音列表
            List(audioManager.recordings, id: \.id) { recording in
                Text(recording.summary)
                    .onTapGesture {
                        audioManager.playRecording(recording)
                    }
            }
        }
        .onAppear {
            audioManager.loadMockData()
        }
    }
}
```

### 设备连接（与原来相同）
```swift
// 连接到设备
audioManager.connectToDevice(selectedDevice)

// 断开连接
audioManager.disconnectFromDevice()
```

### 录音控制（与原来相同）
```swift
// 开始录音
audioManager.startRecording()

// 停止录音
audioManager.stopRecording()

// 播放录音
audioManager.playRecording(recording)
```

## 🎨 UI 兼容性

### 完全兼容的属性
```swift
@Published var isConnected: Bool           // 连接状态
@Published var isRecording: Bool           // 录音状态  
@Published var recordings: [AudioRecording] // 录音列表
@Published var audioLevels: [Float]        // 音频级别
@Published var connectionStatus: String    // 连接状态文本
@Published var connectedDevice: DiscoveredDevice? // 已连接设备
```

### SwiftUI 绑定示例
```swift
// 状态绑定
.disabled(!audioManager.isConnected)
.foregroundColor(audioManager.isRecording ? .red : .blue)

// 列表绑定
List(audioManager.recordings, id: \.id) { ... }

// 音频可视化
AudioVisualizerView(levels: audioManager.audioLevels)
```

## 🔍 调试和日志

### 连接状态监听
```swift
audioManager.$isConnected
    .sink { isConnected in
        print("连接状态: \(isConnected)")
    }
    .store(in: &cancellables)
```

### 录音状态监听
```swift
audioManager.$recordings
    .sink { recordings in
        print("录音数量: \(recordings.count)")
    }
    .store(in: &cancellables)
```

## 🚨 注意事项

### 1. 依赖关系
确保所有 Services 目录下的文件都已添加到项目中：
- WebSocketModule.swift
- AudioStreamModule.swift  
- DataExtensions.swift
- ESP32AudioService.swift
- AudioManagerAdapter.swift

### 2. 权限设置
确保 Info.plist 中包含必要的权限：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要麦克风权限来录制音频</string>
```

### 3. 网络设置
如需连接 HTTP 设备，确保 ATS 设置：
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 🎯 未来扩展

### 可选的高级功能
如果需要使用更高级的功能，可以直接访问底层服务：
```swift
class AdvancedAudioManager: AudioManagerAdapter {
    var esp32Service: ESP32AudioService {
        return super.esp32Service // 需要将 esp32Service 设为 protected
    }
    
    // 访问高级功能
    func configureAdvancedAudio() {
        // 使用 esp32Service 的高级配置
    }
}
```

### 自定义配置
```swift
// 创建自定义配置的服务（未来版本可能支持）
let customConfig = AudioStreamConfiguration(
    sampleRate: 44100,
    channels: 2,
    enableRealTimeMonitoring: true
)
```

## ✅ 迁移完成检查清单

- [x] 复制所有模块文件到 Services 目录
- [x] 创建 ESP32AudioService 专用服务
- [x] 实现 AudioManagerAdapter 适配器
- [x] 更新所有 AudioManager 类型引用
- [x] 保持原有接口兼容性
- [x] 测试基本功能（连接、录音、播放）
- [x] 验证 UI 绑定正常工作

## 🎉 总结

通过模块化重构，raku 项目现在具备了：
- **更稳定的连接**: 自动重连和错误恢复
- **更好的代码结构**: 清晰的模块分离
- **更容易维护**: 职责单一的组件
- **更强的扩展性**: 易于添加新功能
- **向后兼容**: 现有代码无需大幅修改

所有原有功能保持不变，同时获得了更强大和可靠的底层实现！