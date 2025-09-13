//
//  AudioRecording.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI
import AVFoundation
import Combine


// MARK: - 主视图
struct ContentView: View {
    @StateObject private var audioManager = AudioManagerAdapter()
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 极简背景
                (isDarkMode ? Color.black : Color.appBackground)
                    .ignoresSafeArea()
                
                RecordingsPageView(
                    audioManager: audioManager,
                    isDarkMode: isDarkMode
                )
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}


// MARK: - 预览专用的 AudioManager
class PreviewAudioManager: AudioManagerAdapter {
    private var shouldSkipDatabaseInit = true
    
    init() {
        print("📱 PreviewAudioManager: 初始化预览数据管理器")
        super.init(skipDatabaseLoad: true)
        
        // 清空从数据库加载的数据，使用示例数据
        self.recordings = []
        self.recordings = [
            AudioRecording(
                timestamp: Date(),
                duration: 185.5,
                transcription: "这是一段会议录音的转写内容，讨论了关于新产品开发的进度和计划。我们需要在下个季度完成主要功能的开发，并准备进行用户测试。团队决定采用敏捷开发方法，每两周进行一次迭代评审。",
                title: "产品开发会议讨论",
                summary: "确定了Q2的开发目标，包括核心功能完成、用户界面优化和测试计划制定。",
                tags: ["会议", "产品", "开发"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: """
                ## 明确目标
                > 3个月内完成1个科技艺术项目原型，实现AI生成艺术作品并线下展览
                
                ## 行动清单
                - [ ] **优先级高**：调研科技艺术趋势与用户需求
                - [ ] **优先级高**：确定技术实现方案与艺术形式
                - [ ] **优先级中**：收集艺术素材与训练数据
                - [ ] **优先级低**：寻找技术与艺术合作资源
                
                ## 时间规划
                **短期（1周内）**：每日2小时调研科技艺术案例，周末输出趋势报告与用户需求分析
                **中期（1月内）**：前2周完成技术方案设计（含AI模型选型），后2周收集艺术素材与训练数据
                **长期（3月内）**：第3-6周开发AI生成模型并测试优化，第7-8周筹备线下展览（布展/宣传）
                """
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-3600),
                duration: 45.2,
                transcription: "今天的学习笔记，主要学习了SwiftUI的高级动画技巧。包括自定义转场动画、弹簧动画的参数调节，以及如何优化动画性能。",
                title: "SwiftUI动画技巧学习",
                summary: "掌握了转场动画和弹簧动画的实现方法，了解了动画性能优化的关键点。",
                tags: ["学习", "SwiftUI", "动画"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: """
                ## 学习要点
                
                ### 转场动画
                - asymmetric 转场的使用
                - move 和 opacity 的组合效果
                
                ### 弹簧动画
                - response 和 dampingFraction 参数调节
                - 不同场景下的最佳参数选择
                """
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-7200),
                duration: 126.8,
                transcription: "团队周会录音，讨论了本周的工作进展和下周的计划安排。产品团队完成了新功能的设计稿，开发团队修复了几个重要的bug。",
                title: "团队周会总结",
                summary: "产品设计按计划完成，开发进度良好，下周将开始新功能开发。",
                tags: ["团队", "周会", "进度"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: nil
            ),
            AudioRecording(
                timestamp: Date().addingTimeInterval(-10800),
                duration: 89.3,
                transcription: "个人想法记录：关于如何提升用户体验的一些思考，包括界面设计的简化、交互流程的优化，以及反馈机制的改进。",
                title: "用户体验优化思考",
                summary: "从界面、交互、反馈三个维度提出了改进建议。",
                tags: ["个人", "用户体验", "思考"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: """
                ## 用户体验优化方案
                
                ### 界面设计
                - 减少不必要的视觉元素
                - 提高对比度和可读性
                
                ### 交互优化
                - 简化操作步骤
                - 提供快捷操作方式
                
                ### 反馈机制
                - 及时的视觉反馈
                - 清晰的状态提示
                """
            )
        ]
        
        // 设置连接状态
        self.isConnected = true
        print("📱 PreviewAudioManager: 已加载 \(self.recordings.count) 条示例录音数据")
    }
}


// MARK: - 标签视图
struct TagView: View {
    let text: String
    let isDarkMode: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
    }
}

// MARK: - Preview
// 预览专用的 ContentView 包装器，可以覆盖 isDarkMode 设置
struct PreviewContentView: View {
    let forcedDarkMode: Bool
    @StateObject private var audioManager = PreviewAudioManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 极简背景
                (forcedDarkMode ? Color.black : Color.appBackground)
                    .ignoresSafeArea()
                
                RecordingsPageView(
                    audioManager: audioManager,
                    isDarkMode: forcedDarkMode
                )
            }
        }
        .preferredColorScheme(forcedDarkMode ? .dark : .light)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 浅色模式预览
            PreviewContentView(forcedDarkMode: false)
                .previewDisplayName("Light Mode")
            
            // 深色模式预览
            PreviewContentView(forcedDarkMode: true)
                .previewDisplayName("Dark Mode")
            
            // iPad 预览
            PreviewContentView(forcedDarkMode: true)
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (6th generation)"))
                .previewDisplayName("iPad Pro - Dark")
            
            // 小屏幕设备预览
            PreviewContentView(forcedDarkMode: false)
                .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
                .previewDisplayName("iPhone SE - Light")
        }
    }
}
