# VolcEngine语音识别配置指南

## 概述
本项目已集成VolcEngine语音识别服务，用于将录音自动转换为文本。本指南将帮助您配置必要的认证信息。

## 配置步骤

### 1. 获取VolcEngine凭证
1. 访问 [VolcEngine控制台](https://console.volcengine.com/)
2. 注册并登录账户
3. 进入"语音技术" -> "语音识别"服务
4. 创建应用并获取以下信息：
   - App ID (应用ID)
   - Access Token (访问令牌)
   - Cluster (集群名称，通常为 "volcano_speech")

### 2. 配置凭证信息

在 `ESP32AudioService.swift` 文件中，找到以下代码段：

```swift
let volcConfig = VolcEngineConfiguration(
    appId: "your_app_id",  // 替换为您的应用ID
    accessToken: "your_access_token",  // 替换为您的访问令牌
    cluster: "volcano_speech",
    userId: "raku_user_\(UUID().uuidString)",
    requestId: UUID().uuidString
)
```

将 `your_app_id` 和 `your_access_token` 替换为您从VolcEngine控制台获取的实际值。

### 3. 功能特性

集成后，语音识别具有以下功能：

- **实时识别**：录音完成后自动开始语音识别
- **文本转录**：将音频转换为中文文本
- **智能摘要**：自动生成录音内容摘要
- **标签生成**：根据内容自动添加相关标签
- **错误处理**：网络或识别失败时的友好提示

### 4. 支持的音频格式

- 采样率：16kHz
- 声道数：单声道 (Mono)
- 位深度：16位
- 格式：PCM

### 5. 使用流程

1. 用户点击开始录音
2. ESP32设备开始录音并传输音频数据
3. 用户点击停止录音
4. 系统自动调用VolcEngine进行语音识别
5. 识别结果实时更新到录音列表中

### 6. 注意事项

- 确保设备有稳定的网络连接
- VolcEngine可能有使用费用，请查看官方定价
- 首次使用可能需要等待几秒钟进行初始化
- 识别准确率可能因音频质量而异

### 7. 故障排除

**识别失败**：
- 检查网络连接
- 验证API凭证是否正确
- 确认音频格式是否符合要求

**识别结果为空**：
- 检查录音是否包含清晰的语音内容
- 确认音频时长是否太短

**连接超时**：
- 检查网络状态
- 尝试重新录音

## 安全建议

- 不要将API凭证硬编码在代码中，考虑使用环境变量或配置文件
- 在生产环境中使用更安全的认证方式
- 定期更新访问令牌