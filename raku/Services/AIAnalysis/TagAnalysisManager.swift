//
//  TagAnalysisManager.swift
//  raku
//
//  Created by Assistant on 2025/9/22.
//  AI标签分析管理器 - 处理启动时的智能检查
//

import Foundation

class TagAnalysisManager: NSObject {
    static let shared = TagAnalysisManager()
    
    private let databaseManager = DatabaseManager.shared
    private let clusteringService = TagClusteringService()
    
    private override init() {
        super.init()
    }
    
    /// 检查是否需要进行AI标签分析
    /// - Returns: 如果需要分析返回true，否则返回false
    func shouldPerformAIAnalysis() -> Bool {
        // 1. 检查标签数量是否大于5
        let allTags = databaseManager.getAllUniqueTags()
        guard allTags.count > 5 else {
            print("🏷️ 标签数量(\(allTags.count))不足5个，跳过AI分析")
            return false
        }
        
        // 2. 检查上次检查日期是否超过一周
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        if let lastCheckDate = databaseManager.getLastAIAnalysisCheckDate() {
            if lastCheckDate > oneWeekAgo {
                print("🕐 距离上次AI分析不足一周，跳过分析")
                return false
            }
        }
        
        print("✅ 满足AI分析条件：标签数量(\(allTags.count))，需要进行分析")
        return true
    }
    
    /// 执行AI标签分析
    func performAIAnalysis() {
        guard shouldPerformAIAnalysis() else { return }
        
        let allTags = databaseManager.getAllUniqueTags()
        print("🤖 开始执行AI标签分析，共\(allTags.count)个标签")
        
        // 设置回调
        clusteringService.delegate = self
        
        // 开始分析
        clusteringService.analyzeTags(allTags)
    }
    
    /// 获取当前可用的AI分析结果
    func getCurrentAIAnalysisResult() -> TagClusteringResult? {
        return databaseManager.getLastAIAnalysisResult()
    }
    
    /// 清除AI分析结果
    func clearAIAnalysisResult() {
        databaseManager.clearAIAnalysisResult()
    }
}

// MARK: - TagClusteringServiceDelegate

extension TagAnalysisManager: TagClusteringServiceDelegate {
    func tagClusteringService(_ service: TagClusteringService, didCompleteAnalysis result: TagClusteringResult) {
        print("✅ AI标签分析完成，发现\(result.clusters.count)个可合并的标签组")
        
        // 保存分析结果
        databaseManager.saveAIAnalysisResult(result)
        
        // 发送通知，通知UI更新
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .aiAnalysisCompleted, object: result)
        }
    }
    
    func tagClusteringService(_ service: TagClusteringService, didFailWithError error: TagClusteringError) {
        print("❌ AI标签分析失败: \(error.localizedDescription)")
        
        // 即使失败也要更新检查日期，避免频繁重试
        databaseManager.saveAIAnalysisCheckDate(Date())
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let aiAnalysisCompleted = Notification.Name("aiAnalysisCompleted")
}