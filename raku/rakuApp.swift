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
        // 在应用启动时开始后台处理未向量化的录音记录
        startBackgroundEmbeddingProcessing()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .toastContainer()
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
