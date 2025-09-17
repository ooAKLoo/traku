# 📱 AudioSources 音频源模块

## 概述

AudioSources 模块负责管理不同类型的音频输入源，为 Raku 应用提供统一的音频录制能力。

## 架构设计

```
AudioSources/
├── Phone/                    # 手机录音相关
│   └── PhoneRecordingManager.swift
├── ESP32/                    # ESP32硬件录音相关
│   ├── ESP32AudioService.swift
│   ├── WebSocketModule.swift
│   └── AudioStreamModule.swift
└── README_AudioSources.md    # 本文档
```

## 🎯 设计原则

1. **统一接口**: 所有音频源都实现 `AudioRecorder` 协议
2. **职责分离**: 每个音频源只负责自己的硬件交互
3. **状态管理**: 通过 `AudioRecordingService` 统一管理状态
4. **易于扩展**: 新增音频源只需实现协议即可

## 📋 核心组件

### Core 组件（位于 `/Services/Core/`）
- **AudioRecorder.swift** - 统一的音频录制接口协议
- **AudioRecordingService.swift** - 音频录制服务管理器
- **PhoneRecorder.swift** - 手机录音新实现
- **ESP32Recorder.swift** - ESP32硬件录音新实现

### Phone 目录
- **PhoneRecordingManager.swift** - 原有的手机录音管理器（待重构替换）

### ESP32 目录  
- **ESP32AudioService.swift** - 原有的ESP32音频服务（待重构替换）
- **WebSocketModule.swift** - WebSocket通信模块
- **AudioStreamModule.swift** - 音频流处理模块

## 🚀 使用方式

### 基本录音流程

```swift
// 1. 创建录音服务
let audioService = AudioRecordingService()

// 2. 切换到手机录音
try await audioService.switchToSource(.phone)

// 3. 开始录音
try await audioService.startRecording()

// 4. 停止录音并获取结果
let result = await audioService.stopRecording()
```

### ESP32设备录音

```swift
// 1. 连接ESP32设备
let device = ESP32Recorder.ESP32Device(
    name: "我的ESP32",
    ipAddress: "192.168.1.100", 
    port: 8888
)
try await audioService.connectToESP32(device: device)

// 2. 开始录音
try await audioService.startRecording()
```

## 🔄 重构说明

### 原有架构问题
```
❌ 复杂的依赖关系:
AudioManagerAdapter (上帝对象)
├── ESP32AudioService
├── PhoneRecordingManager  
├── AudioInputManager
├── AudioInputSource (过度抽象)
├── ESP32AudioInputSource
├── PhoneAudioInputSource
└── AudioProcessingPipeline
```

### 新的简洁架构
```
✅ 清晰的职责分离:
AudioRecordingService (统一管理)
├── PhoneRecorder (手机录音实现)
├── ESP32Recorder (ESP32录音实现)
└── AudioRecorder (统一接口协议)
```

### 重构进度

- [x] 创建新的统一接口和实现
- [x] 移动文件到AudioSources目录
- [ ] 替换UI层调用原有AudioManagerAdapter
- [ ] 删除旧的复杂抽象层
- [ ] 更新相关测试

## 🧪 测试示例

```swift
func testUnifiedAudioRecording() async throws {
    let service = AudioRecordingService()
    
    // 测试手机录音
    try await service.switchToSource(.phone)
    XCTAssertTrue(service.isPhoneRecorderAvailable)
    
    try await service.startRecording()
    XCTAssertTrue(service.isRecording)
    
    let result = await service.stopRecording()
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.sourceType, .phone)
}
```

---

**最后更新**: 2025-09-17  
**维护者**: Raku Development Team