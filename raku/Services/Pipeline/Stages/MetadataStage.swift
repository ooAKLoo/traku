//
//  MetadataStage.swift
//  raku
//
//  元数据阶段 - 天气信息获取
//

import Foundation

final class MetadataStage: ProcessingStage {
    let name = "元数据获取"

    func process(_ context: ProcessingContext) async throws -> ProcessingContext {
        print("🌤️ [\(name)] 开始获取天气信息")

        var updatedContext = context

        do {
            let weatherData = try await WeatherService.shared.getWeatherForNote(noteId: context.id.uuidString)
            updatedContext.weather = weatherData
            print("✅ [\(name)] 天气信息: \(weatherData.type.displayName) @ \(weatherData.location)")
        } catch {
            print("⚠️ [\(name)] 天气获取失败，使用默认值: \(error.localizedDescription)")
            // 设置默认天气
            updatedContext.weather = WeatherData(
                type: .sunny,
                location: "位置未知",
                timestamp: context.createdAt
            )
        }

        return updatedContext
    }
}
