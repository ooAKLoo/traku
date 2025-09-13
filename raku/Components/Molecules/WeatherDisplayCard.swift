//
//  WeatherDisplayCard.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

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

// MARK: - 预览
struct WeatherDisplayCard_Previews: PreviewProvider {
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
            
            // 深色模式 - 网格展示
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
        }
    }
}