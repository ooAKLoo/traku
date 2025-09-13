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
    
    // 时间场景天气
    case sunrise = "sunrise.fill"
    case sunset = "sunset.fill"
    case moonrise = "moonrise.fill"
    case moonset = "moonset.fill"
    case night = "moon.stars.fill"
    case dawn = "sun.horizon.fill"
    case dusk = "sun.dust.fill"
    case twilight = "moon.circle.fill"
    
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
        
        // 时间场景
        case .sunrise: return "日出"
        case .sunset: return "日落"
        case .moonrise: return "月升"
        case .moonset: return "月落"
        case .night: return "夜晚"
        case .dawn: return "黎明"
        case .dusk: return "黄昏"
        case .twilight: return "暮光"
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
            
        // 时间场景颜色
        case .sunrise:
            return (.orange, .pink)
        case .sunset:
            return (.red, .orange)
        case .moonrise:
            return (.blue.opacity(0.8), .purple.opacity(0.5))
        case .moonset:
            return (.purple.opacity(0.7), .blue.opacity(0.4))
        case .night:
            return (.indigo, .purple.opacity(0.6))
        case .dawn:
            return (.pink.opacity(0.8), .orange.opacity(0.5))
        case .dusk:
            return (.purple.opacity(0.8), .pink.opacity(0.6))
        case .twilight:
            return (.indigo.opacity(0.7), .blue.opacity(0.4))
        }
    }
}