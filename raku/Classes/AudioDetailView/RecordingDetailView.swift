//
//  RecordingDetailView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI
import AVFoundation
import Combine
import MarkdownUI

// MARK: - 录音详情视图
struct RecordingDetailView: View {
    let recording: AudioRecording
    @State private var isPlaying = false
    @State private var playProgress: Double = 0
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = true
    @StateObject private var audioManager = AudioManagerAdapter()
    
    var body: some View {
        ZStack {
            // 极简背景
            (isDarkMode ? Color.black : Color(white: 0.98))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部导航栏 - 更加精简
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // 播放控件 - 更简洁
                    HStack(spacing: 12) {
                        Button(action: togglePlayback) {
                            HStack(spacing: 8) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14))
                                Text(FormatHelper.formatDuration(recording.duration))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                            }
                            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                            )
                        }
                        
                        // 下载按钮 - 只在播放时显示
                        if isPlaying {
                            Button(action: downloadAudio) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button(action: shareRecording) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        Button(action: exportRecording) {
                            Label("导出", systemImage: "doc.on.doc")
                        }
                        Button(role: .destructive, action: deleteRecording) {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题区域 - 更紧凑
                        VStack(alignment: .leading, spacing: 16) {
                            Text(extractTitle(from: recording.summary))
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.95))
                                .lineLimit(2)
                            
                            // 时间和标签在同一行
                            HStack(spacing: 22) {
                                Text(recording.timestamp.smartFormatted)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                                
                                // 标签 - 更简洁
                                if !recording.tags.isEmpty {
                                    HStack(spacing: 8) {
                                        ForEach(recording.tags.prefix(3), id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(isDarkMode ? Color.gray.opacity(0.2) : Color.gray.opacity(0.15))
                                                )
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 50)
                        
                        // 转写文本部分 - 引用样式
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top, spacing: 10) {
                                // 引用符号
                                Text("“")
                                    .font(.system(size: 48, weight: .semibold))
                                    .foregroundColor(isDarkMode ? Color.white.opacity(0.15) : Color.gray.opacity(0.2))
                                    .offset(y: -11)
                                
                                // 转写内容 - 浅色斜体
                                Text(recording.transcription)
                                    .font(.system(size: 17, weight: .regular))
                                    .italic()
                                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.6))
                                    .lineSpacing(12)
                            }
                            .padding(.horizontal, 18)
                        }
                        .padding(.bottom, 58)
                        
                        // AI总结部分 - 黑体强调，无标题
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // 增强内容 - 使用Markdown渲染
                            if let enrichedContent = recording.enrichedContent, !enrichedContent.isEmpty {
                                Markdown("\(enrichedContent)")  // 直接传入 Markdown 字符串
                                    .markdownTheme(Theme.docC)  // 应用自定义主题（或内置主题）
                                    .padding(.horizontal, 24)
                                    .padding(.top, 12)
                            }
                        }
                        
                        // 底部留白
                        Color.clear.frame(height: 60)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // 辅助函数
    
    func extractTitle(from summary: String) -> String {
        // 从总结中提取第一句作为标题
        let sentences = summary.components(separatedBy: CharacterSet(charactersIn: "。！？"))
        if let firstSentence = sentences.first, !firstSentence.isEmpty {
            // 限制标题长度
            if firstSentence.count > 30 {
                return String(firstSentence.prefix(30)) + "..."
            }
            return firstSentence
        }
        return "录音记录"
    }
    
    func shareRecording() {
        // 实现分享功能
        let text = """
        \(extractTitle(from: recording.summary))
        
        转写内容：
        \(recording.transcription)
        
        总结：
        \(recording.summary)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func exportRecording() {
        // 实现导出功能
        copySummary()
    }
    
    func deleteRecording() {
        // 实现删除功能
        dismiss()
    }
    
    func downloadAudio() {
        guard let audioData = recording.audioData else {
            print("没有音频数据可供下载")
            showErrorAlert(message: "没有可用的音频数据")
            return
        }
        
        // 验证是否为模拟数据
        if MockDataService.shared.isMockAudioData(audioData) {
            print("检测到模拟音频数据，无法下载")
            showErrorAlert(message: MockDataService.shared.demoModeMessage + "，无法下载音频")
            return
        }
        
        // 检查是否已经是WAV格式（WAV文件以"RIFF"开头）
        let wavHeaderBytes = [UInt8](audioData.prefix(4))
        let isWAV = wavHeaderBytes == [0x52, 0x49, 0x46, 0x46] // "RIFF"的ASCII值
        
        // 如果不是WAV格式，说明数据可能有问题
        if !isWAV {
            print("音频数据格式无效，不是有效的WAV文件")
            showErrorAlert(message: "音频数据格式无效")
            return
        }
        
        // 验证音频数据大小（WAV文件头至少44字节）
        if audioData.count < 44 {
            print("音频数据太小，无效的WAV文件: \(audioData.count) bytes")
            showErrorAlert(message: "音频数据无效")
            return
        }
        
        // 生成安全的文件名
        let title = extractTitle(from: recording.summary)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
        let fileName = "\(title)_\(recording.timestamp.fileFormatted).wav"
        
        // 使用临时目录避免权限问题
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            // 直接写入WAV数据（数据已经是WAV格式）
            try audioData.write(to: fileURL)
            print("音频文件已保存到: \(fileURL)")
            print("文件大小: \(audioData.count) bytes")
            
            // 创建分享界面
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            // 设置完成回调，清理临时文件
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("临时文件已清理")
                } catch {
                    print("清理临时文件失败: \(error)")
                }
            }
            
            // 展示分享界面
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                // iPad需要设置popover
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = rootVC.view
                    popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("保存音频文件失败: \(error)")
            showErrorAlert(message: "保存音频文件失败: \(error.localizedDescription)")
        }
    }
    
    func copySummary() {
        let fullContent = """
        \(recording.transcription)
        
        ---
        
        \(recording.summary)
        """
        UIPasteboard.general.string = fullContent
    }
    
    func togglePlayback() {
        if isPlaying {
            audioManager.stopPlaying()
            isPlaying = false
        } else {
            if let audioData = recording.audioData {
                if MockDataService.shared.isMockAudioData(audioData) {
                    showMockDataAlert()
                } else {
                    audioManager.playRecording(recording)
                    isPlaying = true
                }
            }
        }
    }
    
    private func showMockDataAlert() {
        isPlaying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isPlaying = false
        }
    }
    
    
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "提示",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}

// MARK: - 预览
struct RecordingDetailView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingDetailView(
            recording: AudioRecording(
                timestamp: Date(),
                duration: 185,
                transcription: "这是一段会议录音的转写内容，讨论了关于新产品开发的进度和计划。我们需要在下个季度完成主要功能的开发，并准备进行用户测试。",
                summary: "产品开发会议总结：确定了Q2的开发目标，包括核心功能完成、用户界面优化和测试计划制定。团队将采用敏捷开发方法，每两周进行一次迭代评审。",
                tags: ["会议", "产品", "开发"],
                audioData: "mock audio data".data(using: .utf8),
                enrichedContent: """
                ## 🎯 明确目标
                > 3个月内完成1个科技艺术项目原型，实现AI生成艺术作品并线下展览
                
                ## ✅ 行动清单
                - [ ] **优先级高**：调研科技艺术趋势与用户需求
                - [ ] **优先级高**：确定技术实现方案与艺术形式
                - [ ] **优先级中**：收集艺术素材与训练数据
                - [ ] **优先级低**：寻找技术与艺术合作资源
                
                ## 📦 所需资源
                | 资源类型 | 具体内容 |
                |---------|---------|
                | 时间 | 调研1周，方案设计1周，素材收集2周，技术开发4周，展览筹备2周 |
                | 工具 | AI工具（Midjourney/Stable Diffusion）、设计软件（PS/Blender）、项目管理工具（Trello） |
                | 支持 | 技术伙伴、艺术指导、线下展览场地资源 |
                
                ## ⏰ 时间规划
                **短期（1周内）**：每日2小时调研科技艺术案例，周末输出趋势报告与用户需求分析
                **中期（1月内）**：前2周完成技术方案设计（含AI模型选型），后2周收集艺术素材与训练数据
                **长期（3月内）**：第3-6周开发AI生成模型并测试优化，第7-8周筹备线下展览（布展/宣传）
                
                ## ⚠️ 潜在挑战
                1. **挑战**：AI生成艺术效果未达预期 → **应对**：先小范围测试不同模型，参考艺术指导调整参数
                2. **挑战**：缺乏技术/艺术合作资源 → **应对**：在艺术社群/高校发布招募信息，优先合作学生团队降低成本
                """
            )
        )
    }
}
