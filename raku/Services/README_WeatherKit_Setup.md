# WeatherKit 配置指南

## 项目配置步骤

### 1. Xcode 项目设置
1. 打开项目的 **Signing & Capabilities**
2. 点击 **+ Capability**
3. 添加 **WeatherKit**

### 2. Apple Developer 配置
1. 登录 [Apple Developer Portal](https://developer.apple.com)
2. 进入 **Certificates, Identifiers & Profiles**
3. 选择你的 **App ID**
4. 在 **Capabilities** 中启用 **WeatherKit**
5. 保存配置

### 3. 最低系统要求
- iOS 16.0+
- Xcode 14.0+

### 4. 使用限制
- 每月500,000次免费调用
- 超出后按使用量计费

## 如果暂时无法配置 WeatherKit

可以修改 `WeatherService.swift` 使用简单的随机天气：

```swift
// 在 getCurrentWeather() 方法中添加fallback
func getCurrentWeather() async throws -> WeatherData {
    do {
        let location = try await getCurrentLocation()
        return try await fetchWeatherWithAppleWeatherKit(for: location)
    } catch {
        // WeatherKit 不可用时的降级方案
        print("❌ [WeatherService] WeatherKit 不可用，使用随机天气")
        return createRandomWeatherData()
    }
}

private func createRandomWeatherData() -> WeatherData {
    let types: [WeatherType] = [.sunny, .partlyCloudy, .cloudy, .rainy]
    let cities = ["北京", "上海", "广州", "深圳", "杭州"]
    
    return WeatherData(
        type: types.randomElement() ?? .sunny,
        location: cities.randomElement() ?? "北京",
        timestamp: Date()
    )
}
```

## 错误排查

如果出现编译错误：
1. 确保 WeatherKit 已正确添加到项目
2. 检查 iOS Deployment Target 是否为 16.0+
3. 确保开发者账号有效且已启用 WeatherKit