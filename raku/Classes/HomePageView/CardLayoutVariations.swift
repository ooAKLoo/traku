//
//  CardLayoutVariations.swift
//  raku
//
//  Layout design variations for HomeContentCardView
//  Created for exploring cleaner, more refined card designs
//

import SwiftUI

// MARK: - Layout Variation 1: Left Circular Weather Icon
struct LeftCircularWeatherCardView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    let onDelete: () -> Void
    
    private var weatherType: WeatherType {
        let hashValue = abs(recording.id.hashValue)
        let index = hashValue % WeatherType.allCases.count
        return WeatherType.allCases[index]
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 左侧圆形天气图标
            WeatherIconView(
                weatherType: weatherType,
                isDarkMode: isDarkMode,
                size: 32,
                showBackground: false
            )
            .frame(width: 48, height: 48)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                weatherType.primaryColor.opacity(0.15),
                                weatherType.primaryColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        weatherType.primaryColor.opacity(0.2),
                        lineWidth: 1
                    )
            )
            
            // 右侧内容区域
            VStack(alignment: .leading, spacing: 12) {
                // 时间戳
                Text(recording.timestamp.smartFormatted)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                
                // 标题
                Text(recording.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 标签和时长
                HStack {
                    // 标签
                    HStack(spacing: 6) {
                        ForEach(recording.tags.prefix(2), id: \.self) { tag in
                            TagView(text: tag, isDarkMode: isDarkMode)
                        }
                        if recording.tags.count > 2 {
                            Text("+\(recording.tags.count - 2)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                )
                        }
                    }
                    
                    Spacer()
                    
                    // 时长
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .medium))
                        Text(L("recording_duration_format", Int(recording.duration)))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    weatherType.primaryColor.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Layout Variation 2: Left Top Corner Overlay
struct LeftOverlayWeatherCardView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    let onDelete: () -> Void
    
    private var weatherType: WeatherType {
        let hashValue = abs(recording.id.hashValue)
        let index = hashValue % WeatherType.allCases.count
        return WeatherType.allCases[index]
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 主内容
            VStack(alignment: .leading, spacing: 14) {
                // 时间戳区域（给左上角图标预留空间）
                HStack {
                    Spacer()
                        .frame(width: 40) // 为天气图标预留空间
                    
                    Text(recording.timestamp.smartFormatted)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                    
                    Spacer()
                }
                
                // 标题
                Text(recording.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 8) // 轻微缩进，形成层次感
                
                // 标签和时长
                HStack {
                    // 标签
                    HStack(spacing: 6) {
                        ForEach(recording.tags.prefix(3), id: \.self) { tag in
                            TagView(text: tag, isDarkMode: isDarkMode)
                        }
                        if recording.tags.count > 3 {
                            Text("+\(recording.tags.count - 3)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                                )
                        }
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    // 时长
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .medium))
                        Text(L("recording_duration_format", Int(recording.duration)))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    )
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
            )
            
            // 左上角天气图标 overlay
            WeatherIconView(
                weatherType: weatherType,
                isDarkMode: isDarkMode,
                size: 24,
                showBackground: false
            )
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(weatherType.primaryColor.opacity(0.12))
                    .overlay(
                        Circle()
                            .stroke(weatherType.primaryColor.opacity(0.25), lineWidth: 1.5)
                    )
            )
            .shadow(
                color: weatherType.primaryColor.opacity(0.3),
                radius: 4,
                x: 0,
                y: 2
            )
            .offset(x: 12, y: 12) // 从左上角稍微偏移
        }
    }
}

// MARK: - Layout Variation 3: Right Side Weather Icon
struct RightSideWeatherCardView: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    let onDelete: () -> Void
    
    private var weatherType: WeatherType {
        let hashValue = abs(recording.id.hashValue)
        let index = hashValue % WeatherType.allCases.count
        return WeatherType.allCases[index]
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 左侧内容区域
            VStack(alignment: .leading, spacing: 12) {
                // 时间戳
                Text(recording.timestamp.smartFormatted)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                
                // 标题
                Text(recording.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 标签
                HStack(spacing: 6) {
                    ForEach(recording.tags.prefix(3), id: \.self) { tag in
                        TagView(text: tag, isDarkMode: isDarkMode)
                    }
                    if recording.tags.count > 3 {
                        Text("+\(recording.tags.count - 3)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右侧天气图标和装饰
            VStack(spacing: 8) {
                WeatherIconView(
                    weatherType: weatherType,
                    isDarkMode: isDarkMode,
                    size: 28,
                    showBackground: false
                )
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    weatherType.primaryColor.opacity(0.15),
                                    weatherType.primaryColor.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                
                // 装饰性的颜色条
                RoundedRectangle(cornerRadius: 2)
                    .fill(weatherType.primaryColor.opacity(0.6))
                    .frame(width: 20, height: 3)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white)
        )
    }
}

// MARK: - WeatherType Extension for Colors
extension WeatherType {
    var primaryColor: Color {
        switch self {
        case .sunny: return .orange
        case .partlyCloudy: return .gray
        case .cloudy: return .gray
        case .rainy: return .blue
        case .stormy: return .purple
        case .snowy: return .cyan
        case .foggy: return .purple
        case .windy: return .green
        }
    }
}

// MARK: - Preview for All Variations
struct CardLayoutVariations_Previews: PreviewProvider {
    static let sampleRecording = AudioRecording(
        timestamp: Date(),
        duration: 45.5,
        transcription: "这是一段关于SwiftUI开发的音频记录",
        title: "SwiftUI开发最佳实践和设计模式",
        summary: "本音频记录详细介绍了使用SwiftUI框架构建现代化iOS应用的技巧和方法",
        tags: ["SwiftUI", "iOS开发", "UI设计", "最佳实践"],
        audioData: nil,
        enrichedContent: "深度内容分析..."
    )
    
    static var previews: some View {
        Group {
            // 方案1: 左侧圆形天气图标
            VStack(alignment: .leading) {
                Text("方案1: 左侧圆形天气图标")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                LeftCircularWeatherCardView(
                    recording: sampleRecording,
                    isDarkMode: false,
                    onDelete: {}
                )
            }
            .padding()
            .background(Color(white: 0.95))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Layout 1: Left Circular")
            
            // 方案2: 左上角overlay
            VStack(alignment: .leading) {
                Text("方案2: 左上角Overlay")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                LeftOverlayWeatherCardView(
                    recording: sampleRecording,
                    isDarkMode: false,
                    onDelete: {}
                )
            }
            .padding()
            .background(Color(white: 0.95))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Layout 2: Left Overlay")
            
            // 方案3: 右侧天气图标
            VStack(alignment: .leading) {
                Text("方案3: 右侧天气图标")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                RightSideWeatherCardView(
                    recording: sampleRecording,
                    isDarkMode: false,
                    onDelete: {}
                )
            }
            .padding()
            .background(Color(white: 0.95))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Layout 3: Right Side")
            
            // 深色模式对比
            VStack(spacing: 16) {
                LeftCircularWeatherCardView(
                    recording: sampleRecording,
                    isDarkMode: true,
                    onDelete: {}
                )
                
                LeftOverlayWeatherCardView(
                    recording: sampleRecording,
                    isDarkMode: true,
                    onDelete: {}
                )
                
                RightSideWeatherCardView(
                    recording: sampleRecording,
                    isDarkMode: true,
                    onDelete: {}
                )
            }
            .padding()
            .background(Color.black)
            .previewDisplayName("Dark Mode Comparison")
        }
    }
}
