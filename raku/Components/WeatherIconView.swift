//
//  WeatherIconView.swift
//  raku
//
//  Created by 杨东举 on 2025/9/8.
//

import SwiftUI


// MARK: - 天气图标组件
struct WeatherIconView: View {
    let weatherType: WeatherType
    let isDarkMode: Bool
    let size: CGFloat
    let showBackground: Bool
    
    init(
        weatherType: WeatherType,
        isDarkMode: Bool = false,
        size: CGFloat = 32,
        showBackground: Bool = true
    ) {
        self.weatherType = weatherType
        self.isDarkMode = isDarkMode
        self.size = size
        self.showBackground = showBackground
    }
    
    var body: some View {
        ZStack {
            // 背景光晕效果
            if showBackground {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                weatherType.colors.secondary.opacity(isDarkMode ? 0.2 : 0.15),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.8
                        )
                    )
                    .frame(width: size * 1.6, height: size * 1.6)
            }
            
            // 天气图标
            Image(systemName: weatherType.rawValue)
                .font(.system(size: size, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            weatherType.colors.primary.opacity(isDarkMode ? 0.4 : 0.3),
                            weatherType.colors.secondary.opacity(isDarkMode ? 0.35 : 0.25)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(weatherType.rotation))
                .shadow(
                    color: weatherType.colors.primary.opacity(isDarkMode ? 0.15 : 0.1),
                    radius: 3,
                    x: 0,
                    y: 2
                )
        }
        .animation(.easeInOut(duration: 0.3), value: weatherType)
    }
}

// MARK: - 天气图标展示卡片
struct WeatherDisplayCard: View {
    let weatherType: WeatherType
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // 大图标展示
            WeatherIconView(
                weatherType: weatherType,
                isDarkMode: isDarkMode,
                size: 48,
                showBackground: true
            )
            
            // 天气名称
            Text(weatherType.displayName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDarkMode ? .white : .black)
            
            // 颜色信息
            HStack(spacing: 8) {
                Circle()
                    .fill(weatherType.colors.primary)
                    .frame(width: 12, height: 12)
                
                Circle()
                    .fill(weatherType.colors.secondary)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(20)
        .frame(width: 140, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
                .shadow(
                    color: Color.black.opacity(isDarkMode ? 0.3 : 0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
    }
}

// MARK: - 预览代码
struct WeatherIconView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 浅色模式 - 网格展示（基础天气）
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 基础天气类型
                    VStack(alignment: .leading, spacing: 12) {
                        Text("基础天气")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ForEach([WeatherType.sunny, .partlyCloudy, .cloudy, .rainy, .stormy, .snowy, .foggy, .windy], id: \.self) { weather in
                                WeatherDisplayCard(weatherType: weather, isDarkMode: false)
                            }
                        }
                    }
                    
                    // 时间场景
                    VStack(alignment: .leading, spacing: 12) {
                        Text("时间场景")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ForEach([WeatherType.sunrise, .sunset, .moonrise, .moonset, .night, .dawn, .dusk, .twilight], id: \.self) { weather in
                                WeatherDisplayCard(weatherType: weather, isDarkMode: false)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .previewDisplayName("Light Mode - Categorized")
            
            // 深色模式 - 网格展示（基础天气）
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 基础天气类型
                    VStack(alignment: .leading, spacing: 12) {
                        Text("基础天气")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ForEach([WeatherType.sunny, .partlyCloudy, .cloudy, .rainy, .stormy, .snowy, .foggy, .windy], id: \.self) { weather in
                                WeatherDisplayCard(weatherType: weather, isDarkMode: true)
                            }
                        }
                    }
                    
                    // 时间场景
                    VStack(alignment: .leading, spacing: 12) {
                        Text("时间场景")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ForEach([WeatherType.sunrise, .sunset, .moonrise, .moonset, .night, .dawn, .dusk, .twilight], id: \.self) { weather in
                                WeatherDisplayCard(weatherType: weather, isDarkMode: true)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.black)
            .previewDisplayName("Dark Mode - Categorized")
            
            // 单行展示 - 浅色模式
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(WeatherType.allCases, id: \.self) { weather in
                        VStack(spacing: 12) {
                            WeatherIconView(
                                weatherType: weather,
                                isDarkMode: false,
                                size: 32,
                                showBackground: true
                            )
                            Text(weather.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .previewLayout(.fixed(width: 400, height: 120))
            .previewDisplayName("Horizontal Scroll - Light")
            
            // 单行展示 - 深色模式
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(WeatherType.allCases, id: \.self) { weather in
                        VStack(spacing: 12) {
                            WeatherIconView(
                                weatherType: weather,
                                isDarkMode: true,
                                size: 32,
                                showBackground: true
                            )
                            Text(weather.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.black)
            .previewLayout(.fixed(width: 400, height: 120))
            .previewDisplayName("Horizontal Scroll - Dark")
            
            // 尺寸对比展示
            VStack(spacing: 30) {
                Text("图标尺寸对比")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 30) {
                    VStack(spacing: 8) {
                        WeatherIconView(weatherType: .sunny, isDarkMode: false, size: 16)
                        Text("16pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        WeatherIconView(weatherType: .partlyCloudy, isDarkMode: false, size: 24)
                        Text("24pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        WeatherIconView(weatherType: .rainy, isDarkMode: false, size: 32)
                        Text("32pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        WeatherIconView(weatherType: .stormy, isDarkMode: false, size: 48)
                        Text("48pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(40)
            .background(Color(UIColor.systemBackground))
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Size Comparison")
        }
    }
}
