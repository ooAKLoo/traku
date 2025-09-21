//
//  LocalizationManager.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import Foundation

// MARK: - 本地化管理器
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    private var currentLanguage: String
    private var localizedStrings: [String: [String: String]] = [:]
    
    private init() {
        // 初始化语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") {
            currentLanguage = savedLanguage
        } else {
            // 如果没有保存的语言设置，使用系统首选语言
            currentLanguage = LocalizationData.getSystemPreferredLanguage()
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
        }
        loadLocalizedStrings()
    }
    
    // MARK: - 核心本地化方法
    /// 获取本地化文本
    /// - Parameter key: 本地化key
    /// - Returns: 本地化后的文本，如果找不到则返回key本身
    func localized(_ key: String) -> String {
        guard let languageDict = localizedStrings[currentLanguage],
              let localizedText = languageDict[key] else {
            // 如果找不到对应的本地化文本，返回key本身以便发现问题
            print("⚠️ LocalizationManager: Missing localization for key: \(key)")
            return key
        }
        return localizedText
    }
    
    /// 获取本地化文本（带参数插值）
    /// - Parameters:
    ///   - key: 本地化key
    ///   - arguments: 参数数组
    /// - Returns: 插值后的本地化文本
    func localized(_ key: String, arguments: CVarArg...) -> String {
        let template = localized(key)
        return String(format: template, arguments: arguments)
    }
    
    // MARK: - 语言管理
    /// 切换语言
    /// - Parameter language: 语言代码 (如: "zh-CN", "en-US")
    func switchLanguage(to language: String) {
        currentLanguage = language
        UserDefaults.standard.set(language, forKey: "appLanguage")
        loadLocalizedStrings()
        // 发送通知，让UI更新
        DispatchQueue.main.async {
            self.objectWillChange.send()
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }
    
    /// 获取当前语言
    var currentLang: String {
        return currentLanguage
    }
    
    // MARK: - 私有方法
    private func loadLocalizedStrings() {
        // 这里可以从文件、网络或其他来源加载本地化字符串
        // 目前直接在代码中定义，后续可改为从JSON文件加载
        localizedStrings = LocalizationData.getLocalizedStrings()
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - 全局便捷函数
/// 获取本地化文本的全局函数
/// - Parameter key: 本地化key
/// - Returns: 本地化后的文本
func L(_ key: String) -> String {
    return LocalizationManager.shared.localized(key)
}

/// 获取本地化文本的全局函数（带参数）
/// - Parameters:
///   - key: 本地化key
///   - arguments: 参数列表
/// - Returns: 插值后的本地化文本
func L(_ key: String, _ arguments: CVarArg...) -> String {
    return LocalizationManager.shared.localized(key, arguments: arguments)
}