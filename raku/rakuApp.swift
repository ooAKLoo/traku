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
        // 执行所有启动时的检查任务
        AppStartupManager.shared.performStartupTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            HomepageMainView()
                .toastContainer()
                .globalPopup()
        }
    }
}
