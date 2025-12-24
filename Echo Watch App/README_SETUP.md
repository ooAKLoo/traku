# Echo Watch App 配置指南

## Xcode 项目配置

### 1. Info.plist 配置

在 Xcode 中为 Echo Watch App target 添加以下 Info.plist 条目:

```xml
<!-- 麦克风使用说明 -->
<key>NSMicrophoneUsageDescription</key>
<string>Echo 需要使用麦克风来录制您的语音灵感</string>

<!-- 后台模式 -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- WatchKit 应用 -->
<key>WKWatchKitApp</key>
<true/>

<!-- 伴侣 App Bundle ID -->
<key>WKCompanionAppBundleIdentifier</key>
<string>com.yourdomain.raku</string>
```

### 2. Capabilities 配置

在 Xcode 中为 Watch App 启用以下 Capabilities:

- **Background Modes**
  - Audio, AirPlay, and Picture in Picture (用于后台录音)

### 3. Action Button 配置 (Apple Watch Ultra)

用户需要在 Apple Watch 设置中配置 Action Button:

1. 打开 Watch App 或 设置 > Action Button
2. 选择 "Shortcut" 或 "App"
3. 选择 Echo App

### 4. 表盘 Complication 配置

如需添加 WidgetKit Complication:

1. 在 Xcode 中创建新的 Widget Extension target
2. 选择 "Watch" 作为目标平台
3. 将 `Complication/EchoComplication.swift` 移动到新 target
4. 取消注释 `@main` 属性

### 5. 文件添加到 Xcode 项目

确保以下文件已添加到 Echo Watch App target:

```
Echo Watch App/
├── EchoApp.swift              ✓ (入口)
├── ContentView.swift          ✓ (主视图)
├── Models/
│   └── RecordingInfo.swift
├── Views/
│   ├── RecordingView.swift
│   └── RecordingListView.swift
├── Components/
│   ├── BreathingLight.swift
│   └── HapticManager.swift
├── Services/
│   ├── WatchAudioRecorder.swift
│   └── WatchConnectivityManager.swift
└── Complication/
    ├── ComplicationController.swift (CLKKit, 可选)
    └── EchoComplication.swift       (WidgetKit, 需单独 target)
```

### 6. iOS App 配置

在 iOS raku App 的 Info.plist 中添加:

```xml
<!-- 支持 WatchConnectivity -->
<key>WKWatchOnly</key>
<false/>
```

确保 `WatchConnectivityService.swift` 已添加到 iOS target。

## 测试清单

### Action Button (Ultra 系列)
- [ ] 在 Watch 设置中将 Action Button 绑定到 Echo App
- [ ] 测试按下 Action Button 是否触发录音
- [ ] 测试再次按下是否停止录音

### 表盘快捷方式 (全系列)
- [ ] 将 Echo Complication 添加到表盘
- [ ] 测试点击 Complication 是否进入录音界面

### 全屏盲触 (全系列)
- [ ] 测试转动表冠解锁
- [ ] 测试点击屏幕开始录音
- [ ] 测试再次点击停止录音
- [ ] 验证触觉反馈 ("哒" 开始 / "哒哒" 结束)

### 录音同步
- [ ] 录音后验证自动同步到 iPhone
- [ ] 测试离线录音，恢复连接后同步
- [ ] 在 iOS App 中查看已同步录音
