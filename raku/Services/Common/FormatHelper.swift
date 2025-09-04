//
//  FormatHelper.swift
//  统一的格式化工具类
//

import Foundation

// MARK: - 格式化工具类
struct FormatHelper {
    
    // MARK: - 时长格式化
    
    /// 格式化时长为 MM:SS 格式
    /// - Parameter duration: 时长（秒）
    /// - Returns: 格式化后的字符串，如 "05:30"
    static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 格式化时长为 MM:SS.T 格式（包含十分之一秒）
    /// - Parameter duration: 时长（秒）
    /// - Returns: 格式化后的字符串，如 "05:30.5"
    static func formatDurationWithDecimal(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let decimal = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, decimal)
    }
    
    // MARK: - 日期时间格式化
    
    /// 智能格式化日期（今天/昨天/星期/月日）
    /// - Parameter date: 日期
    /// - Returns: 智能格式化的日期字符串
    static func formatSmartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "今天 HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "昨天 HH:mm"
        } else if let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            formatter.dateFormat = "EEEE HH:mm"
        } else {
            formatter.dateFormat = "MM月dd日 HH:mm"
        }
        
        return formatter.string(from: date)
    }
    
    /// 格式化时间为 HH:mm 格式
    /// - Parameter date: 日期
    /// - Returns: 时间字符串，如 "14:30"
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    /// 格式化日期为文件命名格式
    /// - Parameter date: 日期
    /// - Returns: 文件命名格式的日期字符串，如 "20241201_1430"
    static func formatFileDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        return formatter.string(from: date)
    }
    
    /// 格式化完整日期时间
    /// - Parameter date: 日期
    /// - Returns: 完整的日期时间字符串，如 "2024年12月1日 14:30"
    static func formatFullDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - 数据大小格式化
    
    /// 格式化数据大小
    /// - Parameter bytes: 字节数
    /// - Returns: 格式化的数据大小字符串，如 "1.5 KB", "2.3 MB"
    static func formatDataSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .decimal
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 简单格式化数据大小（仅KB）
    /// - Parameter bytes: 字节数
    /// - Returns: KB格式的数据大小字符串，如 "1.5 KB"
    static func formatDataSizeInKB(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024.0
        return String(format: "%.1f KB", kb)
    }
    
    // MARK: - 便利方法
    
    /// 格式化时长（TimeInterval重载）
    /// - Parameter time: 时间间隔
    /// - Returns: MM:SS格式字符串
    static func formatTime(_ time: TimeInterval) -> String {
        return formatDuration(time)
    }
    
    /// 格式化带毫秒的时长（TimeInterval重载）
    /// - Parameter time: 时间间隔
    /// - Returns: MM:SS.T格式字符串
    static func formatTimeWithDecimal(_ time: TimeInterval) -> String {
        return formatDurationWithDecimal(time)
    }
    
    // MARK: - 相对时间格式化
    
    /// 格式化相对时间（多久前）
    /// - Parameter date: 日期
    /// - Returns: 相对时间字符串，如 "5分钟前", "2小时前"
    static func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - TimeInterval 扩展
extension TimeInterval {
    /// 格式化为 MM:SS 格式
    var formatted: String {
        return FormatHelper.formatDuration(self)
    }
    
    /// 格式化为 MM:SS.T 格式
    var formattedWithDecimal: String {
        return FormatHelper.formatDurationWithDecimal(self)
    }
}

// MARK: - Date 扩展
extension Date {
    /// 智能格式化日期
    var smartFormatted: String {
        return FormatHelper.formatSmartDate(self)
    }
    
    /// 格式化为时间
    var timeFormatted: String {
        return FormatHelper.formatTime(self)
    }
    
    /// 格式化为文件名
    var fileFormatted: String {
        return FormatHelper.formatFileDate(self)
    }
    
    /// 格式化为相对时间
    var relativeFormatted: String {
        return FormatHelper.formatRelativeTime(self)
    }
}