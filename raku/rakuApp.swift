//
//  rakuApp.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

@main
struct rakuApp: App {
    
    init() {
        // 在应用启动时主动申请所需权限
        requestPermissionsOnLaunch()
        
        // 在应用启动时开始后台处理未向量化的录音记录
        startBackgroundEmbeddingProcessing()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toastContainer()
        }
    }
    
    /// 在应用启动时请求权限
    private func requestPermissionsOnLaunch() {
        // 延迟1秒后请求权限，确保UI已经准备就绪
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("[App] 🔐 开始请求应用所需权限...")
            PermissionManager.shared.requestAllPermissions()
        }
    }
    
    private func startBackgroundEmbeddingProcessing() {
        // 延迟5秒后开始，避免影响应用启动性能
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5.0) {
            print("[App] Starting background embedding processing...")
            VolcEngineEmbeddingService.shared.processUnembeddedRecordings()
        }
    }
}
