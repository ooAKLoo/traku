# ASR 语音识别服务配置指南

本文档介绍如何在 Raku 应用中配置和切换不同的语音识别服务。

## 支持的 ASR 模型

### 1. 豆包语音识别（默认）
- **模型名称**: BigModel Recognize Flash
- **提供商**: 字节跳动
- **特点**: 高精度、支持中文、速度快
- **适用场景**: 生产环境推荐使用

### 2. SenseVoice
- **模型名称**: SenseVoice Normal
- **提供商**: 自建服务
- **特点**: 本地部署、无需网络认证
- **适用场景**: 开发测试或内网环境

## 快速开始

### 1. 切换 ASR 模型

#### 方式一：修改默认模型（推荐）

在 `VolcEngineSpeechService.swift` 中修改默认模型：

```swift
// 文件位置: /Services/AIAnalysis/VolcEngineSpeechService.swift
// 第 77 行
@Published var currentModel: ASRModelType = .doubao  // 修改为 .senseVoice 切换到 SenseVoice
```

#### 方式二：运行时切换

在应用运行时动态切换模型：

```swift
// 在 AudioProcessingPipeline 或相关服务中
speechService.switchToModel(.senseVoice)  // 切换到 SenseVoice
speechService.switchToModel(.doubao)      // 切换到豆包
```

#### 方式三：初始化时指定

创建服务实例时指定模型：

```swift
let speechService = VolcEngineSpeechService(defaultModel: .senseVoice)
```

### 2. 配置服务参数

#### 豆包语音识别配置

如需修改豆包服务的认证信息：

```swift
// 文件位置: /Services/AIAnalysis/VolcEngineSpeechService.swift
// 第 230-232 行
let headers: [String: String] = [
    "X-Api-App-Key": "8206093786",  // 替换为您的 APP ID
    "X-Api-Access-Key": "Yq1AuAcWxBELZP-MSUcyctGRcFU17HvX",  // 替换为您的 Access Token
    "X-Api-Resource-Id": "volc.bigasr.auc_turbo",
    // ...
]
```

获取认证信息：
1. 登录[火山引擎控制台](https://console.volcengine.com)
2. 进入语音技术 > 语音识别服务
3. 获取 APP ID 和 Access Token

#### SenseVoice 配置

如需修改 SenseVoice 服务地址：

```swift
// 文件位置: /Services/AIAnalysis/VolcEngineSpeechService.swift
// 第 22-24 行
static let `default` = SenseVoiceConfiguration(
    serverURL: "http://115.190.136.178:8001",  // 修改为您的服务地址
    endpoint: "/transcribe/normal",
    timeout: 130.0
)
```

## 高级配置

### 1. 添加新的 ASR 服务

如需添加其他 ASR 服务，按以下步骤操作：

1. **添加模型类型**
```swift
enum ASRModelType {
    case senseVoice
    case doubao
    case yourNewModel  // 添加新模型
}
```

2. **创建配置结构体**
```swift
struct YourModelConfiguration {
    let apiEndpoint: String
    let apiKey: String
    let timeout: TimeInterval
    
    static let `default` = YourModelConfiguration(
        apiEndpoint: "https://your-api-endpoint.com",
        apiKey: "your-api-key",
        timeout: 60.0
    )
}
```

3. **实现识别方法**
```swift
private func recognizeAudioWithYourModel(_ audioData: Data) {
    // 实现您的识别逻辑
}
```

4. **在 sendAudioData 中添加分支**
```swift
switch currentModel {
case .doubao:
    recognizeAudioWithDoubao(audioData)
case .senseVoice:
    recognizeAudioWithSenseVoice(audioData)
case .yourNewModel:
    recognizeAudioWithYourModel(audioData)
}
```

### 2. 音频格式要求

所有 ASR 服务都要求音频格式为：
- **格式**: WAV
- **采样率**: 16kHz
- **声道数**: 单声道
- **位深度**: 16bit

系统会自动处理音频格式转换。

### 3. 错误处理

常见错误及解决方案：

| 错误代码 | 描述 | 解决方案 |
|---------|------|----------|
| 400 | 请求格式错误 | 检查音频格式和请求参数 |
| 401 | 认证失败 | 检查 API Key 是否正确 |
| 413 | 文件过大 | 确保音频文件小于 100MB |
| 500 | 服务器错误 | 稍后重试或联系服务提供商 |

### 4. 性能优化建议

1. **选择合适的模型**
   - 生产环境推荐使用豆包（更稳定、更准确）
   - 开发测试可使用 SenseVoice（无需认证）

2. **音频预处理**
   - 控制录音时长（建议单次不超过 5 分钟）
   - 确保音频质量（避免过多噪音）

3. **网络优化**
   - 使用稳定的网络连接
   - 考虑实现断点续传机制

## 测试指南

### 1. 测试单个模型
```swift
// 在 AudioProcessingPipeline 中
speechService.currentModel = .doubao
// 进行录音测试
```

### 2. 对比测试
```swift
// 测试脚本示例
func testASRModels(audioData: Data) {
    // 测试豆包
    speechService.switchToModel(.doubao)
    speechService.processRecordingAudio(audioData, duration: 10.0)
    
    // 等待结果...
    
    // 测试 SenseVoice
    speechService.switchToModel(.senseVoice)
    speechService.processRecordingAudio(audioData, duration: 10.0)
}
```

### 3. 查看调试日志

启用详细日志查看识别过程：
- 🎯 使用模型提示
- 📥 原始响应数据
- ✅ 识别成功结果
- ❌ 错误信息

## 常见问题

### Q1: 如何判断当前使用的是哪个模型？
查看控制台日志，会显示：
```
🎯 使用豆包模型进行语音识别
```
或
```
🎯 使用SenseVoice模型进行语音识别
```

### Q2: 切换模型后没有生效？
确保在正确的位置调用切换方法，建议在应用启动时设置。

### Q3: 豆包识别返回 400 错误？
检查：
1. API Key 是否正确
2. 音频格式是否为 WAV
3. 网络连接是否正常

### Q4: SenseVoice 连接失败？
检查：
1. 服务地址是否正确
2. 服务是否已启动
3. 防火墙设置

## 联系支持

如遇到问题，请提供：
1. 使用的 ASR 模型
2. 错误日志
3. 音频文件样本（如可能）

---

最后更新：2024年1月