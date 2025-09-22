//
//  AppStartupManager.swift
//  raku
//
//  Created by Assistant on 2025/9/22.
//  应用启动时的自动检查任务管理器
//

import Foundation

class AppStartupManager {
    static let shared = AppStartupManager()
    
    private init() {}
    
    /// 执行所有启动时的检查任务
    func performStartupTasks() {
        print("[StartupManager] 🚀 开始执行应用启动检查任务...")
        
        // 1. 权限检查
        requestPermissions()
        
        // 2. 后台向量化处理
        startBackgroundEmbeddingProcessing()
        
        // 3. AI标签分析检查
        startAITagAnalysisCheck()
        
        // 4. 其他启动任务可以在这里添加
        // performOtherStartupTasks()
    }
    
    // MARK: - Private Methods
    
    /// 请求应用权限
    private func requestPermissions() {
        // 延迟1秒后请求权限，确保UI已经准备就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("[StartupManager] 🔐 开始请求应用所需权限...")
            PermissionManager.shared.requestAllPermissions()
        }
    }
    
    /// 启动后台向量化处理
    private func startBackgroundEmbeddingProcessing() {
        // 延迟5秒后开始，避免影响应用启动性能
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5.0) {
            print("[StartupManager] 🔍 开始后台向量化处理...")
            VolcEngineEmbeddingService.shared.processUnembeddedRecordings()
        }
    }
    
    /// 启动AI标签分析检查
    private func startAITagAnalysisCheck() {
        // 延迟10秒后开始，确保应用完全启动后再进行AI分析
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 10.0) {
            print("[StartupManager] 🏷️ 开始检查是否需要进行AI标签分析...")
            TagAnalysisManager.shared.performAIAnalysis()
        }
    }
    
    // MARK: - Future Tasks
    
    /// 其他启动任务的示例方法
    private func performOtherStartupTasks() {
        // 可以在这里添加其他启动时需要执行的任务
        // 例如：
        // - 检查应用更新
        // - 同步云端数据
        // - 清理过期缓存
        // - 数据库维护
    }
}