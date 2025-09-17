//
//  WeatherType.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 天气类型枚举
enum WeatherType: String, CaseIterable {
    case sunny = "sun.max.fill"
    case partlyCloudy = "cloud.sun.fill"
    case cloudy = "cloud.fill"
    case rainy = "cloud.rain.fill"
    case stormy = "cloud.bolt.rain.fill"
    case snowy = "cloud.snow.fill"
    case foggy = "cloud.fog.fill"
    case windy = "wind"
    
    var displayName: String {
        switch self {
        case .sunny: return "晴天"
        case .partlyCloudy: return "多云"
        case .cloudy: return "阴天"
        case .rainy: return "雨天"
        case .stormy: return "雷暴"
        case .snowy: return "雪天"
        case .foggy: return "雾天"
        case .windy: return "大风"
        }
    }
    
    var colors: (primary: Color, secondary: Color) {
        switch self {
        case .sunny:
            return (.orange, .yellow)
        case .partlyCloudy:
            return (.blue, .orange)
        case .cloudy:
            return (.gray, .blue.opacity(0.3))
        case .rainy:
            return (.blue, .cyan)
        case .stormy:
            return (.purple, .blue)
        case .snowy:
            return (.white, .blue.opacity(0.2))
        case .foggy:
            return (.gray.opacity(0.7), .white.opacity(0.3))
        case .windy:
            return (.teal, .mint)
        }
    }
}