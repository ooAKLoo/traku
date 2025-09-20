//
//  Date+ExportFormatting.swift
//  raku
//
//  Created by 杨东举 on 2025/9/20.
//

import Foundation

extension Date {
    /// Formats date for export based on current app language setting
    /// - Returns: Formatted date string in appropriate language format
    func formattedForExport() -> String {
        let formatter = DateFormatter()
        
        // Get current language from LocalizationManager
        let currentLanguage = LocalizationManager.shared.currentLang
        
        switch currentLanguage {
        case "zh-CN":
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        case "en-US":
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        default:
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
        }
        
        return formatter.string(from: self)
    }
    
    /// Formats date for export with custom style
    /// - Parameters:
    ///   - dateStyle: Date style to use
    ///   - timeStyle: Time style to use
    /// - Returns: Formatted date string in appropriate language format
    func formattedForExport(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        
        // Get current language from LocalizationManager
        let currentLanguage = LocalizationManager.shared.currentLang
        
        switch currentLanguage {
        case "zh-CN":
            formatter.locale = Locale(identifier: "zh_CN")
        case "en-US":
            formatter.locale = Locale(identifier: "en_US")
        default:
            formatter.locale = Locale(identifier: "zh_CN")
        }
        
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        
        return formatter.string(from: self)
    }
}