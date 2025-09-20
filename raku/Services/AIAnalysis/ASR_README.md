# ASR 语音识别服务配置指南

本文档介绍如何在 Raku 应用中配置语音识别服务。

## 支持的 ASR 模型

### 1. SenseVoice（默认）
- **模型名称**: SenseVoice Normal  
- **提供商**: 自建服务
- **特点**: 本地部署、无需网络认证
- **适用场景**: 开发测试或内网环境

### 2. 豆包语音识别
- **模型名称**: BigModel Recognize Flash
- **提供商**: 字节跳动
- **特点**: 高精度、支持中文、速度快
- **适用场景**: 生产环境推荐使用

## 快速配置

### 修改生产环境模型

在 `ASRConfiguration.swift` 中修改默认模型：

```swift
// 文件位置: /Services/AIAnalysis/ASRConfiguration.swift
struct ASRConfiguration {
    /// 生产环境使用的ASR模型
    /// 修改此值来切换生产环境使用的模型
    static let defaultModel: ASRModelType = .senseVoice  // 或 .doubao
}
```

**这是唯一需要修改的地方！**

### 模型选择指南

```swift
// 开发/测试环境推荐
static let defaultModel: ASRModelType = .senseVoice

// 生产环境推荐  
static let defaultModel: ASRModelType = .doubao
```

## 服务配置

### SenseVoice 配置

如需修改 SenseVoice 服务地址：

```swift
// 文件位置: /Services/AIAnalysis/VolcEngineSpeechService.swift
// 第 22-26 行
static let `default` = SenseVoiceConfiguration(
    serverURL: "http://115.190.136.178:8001",  // 修改为您的服务地址
    endpoint: "/transcribe/normal",
    timeout: 130.0
)
```

### 豆包语音识别配置

如需修改豆包服务的认证信息：

```swift
// 文件位置: /Services/AIAnalysis/VolcEngineSpeechService.swift  
// 第 218-224 行
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

## 音频格式要求

所有 ASR 服务都要求音频格式为：
- **格式**: WAV
- **采样率**: 16kHz  
- **声道数**: 单声道
- **位深度**: 16bit

系统会自动处理音频格式转换。

## 错误处理

常见错误及解决方案：

| 错误代码 | 描述 | 解决方案 |
|---------|------|----------|
| 400 | 请求格式错误 | 检查音频格式和请求参数 |
| 401 | 认证失败 | 检查 API Key 是否正确 |
| 413 | 文件过大 | 确保音频文件小于 100MB |
| 500 | 服务器错误 | 稍后重试或联系服务提供商 |

## 调试日志

查看控制台日志判断当前使用的模型：

```
🎯 使用豆包模型进行语音识别
```
或
```  
🎯 使用SenseVoice模型进行语音识别
```

其他关键日志：
- 📥 原始响应数据
- ✅ 识别成功结果  
- ❌ 错误信息

## 常见问题

### Q1: 如何切换模型？
修改 `ASRConfiguration.defaultModel` 并重新编译应用。

### Q2: 豆包识别返回 400 错误？
检查：
1. API Key 是否正确
2. 音频格式是否为 WAV
3. 网络连接是否正常

### Q3: SenseVoice 连接失败？
检查：
1. 服务地址是否正确
2. 服务是否已启动
3. 防火墙设置

### Q4: 修改配置后没有生效？
确保重新编译应用，配置是编译时确定的。

## 性能建议

1. **选择合适的模型**
   - 生产环境推荐使用豆包（更稳定、更准确）
   - 开发测试使用 SenseVoice（无需认证）

2. **音频优化**
   - 控制录音时长（建议单次不超过 5 分钟）
   - 确保音频质量（避免过多噪音）

3. **网络优化**
   - 使用稳定的网络连接（豆包需要）
   - SenseVoice 可在内网环境使用

---

**注意**: 本配置为编译时配置，不支持运行时切换。如需更换模型，请修改配置文件并重新编译应用。