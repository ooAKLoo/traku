//
//  WeatherIconView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 天气图标基础组件
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

// MARK: - 预览
struct WeatherIconView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 尺寸对比展示
            VStack(spacing: 30) {
                Text("天气图标尺寸对比")
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
            .previewDisplayName("Size Comparison - Light")
            
            // 深色模式尺寸对比
            VStack(spacing: 30) {
                Text("天气图标尺寸对比")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 30) {
                    VStack(spacing: 8) {
                        WeatherIconView(weatherType: .sunset, isDarkMode: true, size: 16)
                        Text("16pt")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 8) {
                        WeatherIconView(weatherType: .night, isDarkMode: true, size: 24)
                        Text("24pt")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 8) {
                        WeatherIconView(weatherType: .stormy, isDarkMode: true, size: 32)
                        Text("32pt")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 8) {
                        WeatherIconView(weatherType: .snowy, isDarkMode: true, size: 48)
                        Text("48pt")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(40)
            .background(Color.black)
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Size Comparison - Dark")
        }
    }
}