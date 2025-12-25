//
//  RecordingDetailViewModel.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import Foundation
import Combine
import UIKit
import SwiftUI

// MARK: - 录音详情页面ViewModel
@MainActor
class RecordingDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recording: AudioRecording
    @Published var editableTags: [String]
    @Published var playProgress: Double = 0
    @Published var isTagEditModalPresented = false
    @Published var headings: [HeadingNode] = []
    @Published var selectedHeadingId: String? = nil
    @Published var isEditingSectionPresented = false
    @Published var editingSectionIndex: Int = 0
    @Published var editingSectionContent: String = ""
    @Published var modifiedEnrichedContent: String = ""
    @Published var currentTranscriptionPage: Int = 0
    @Published var originalTranscription: String = ""
    @Published var polishedTranscription: String = ""
    @Published var hasPolishedText: Bool = false
    @Published var showingFullTranscription = false
    @Published var isPresented = false
    @Published var isGeneratingEnrichedContent = false
    
    // MARK: - Internal Properties
    let audioManager = AudioRecordingService.shared
    private let store = RecordingStore.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks
    var onRecordingUpdated: ((AudioRecording) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Initialization
    init(recording: AudioRecording, onRecordingUpdated: ((AudioRecording) -> Void)? = nil) {
        self.recording = recording
        self.onRecordingUpdated = onRecordingUpdated
        self.editableTags = recording.tags

        setupTranscriptionContent()
        setupEnrichedContent()
        observeUpdates()
    }
    
    // MARK: - Setup Methods
    private func setupTranscriptionContent() {
        originalTranscription = recording.transcription
        hasPolishedText = !recording.polishedText.isEmpty
        
        if hasPolishedText {
            polishedTranscription = recording.polishedText
        }
    }
    
    private func setupEnrichedContent() {
        if let enrichedContent = recording.enrichedContent, !enrichedContent.isEmpty {
            modifiedEnrichedContent = enrichedContent
            updateHeadings()
        }
    }
    
    private func observeUpdates() {
        store.$recordings
            .receive(on: DispatchQueue.main)
            .compactMap { [weak self] (recordings: [AudioRecording]) -> AudioRecording? in
                guard let self = self else { return nil }
                return recordings.first { $0.id == self.recording.id }
            }
            .sink { [weak self] (updatedRecording: AudioRecording) in
                guard let self = self else { return }

                // 只更新本地状态，不调用 onRecordingUpdated 回调
                // 避免与 Store 形成循环更新
                self.recording = updatedRecording
                self.editableTags = updatedRecording.tags
                self.setupTranscriptionContent()

                if let enrichedContent = updatedRecording.enrichedContent, !enrichedContent.isEmpty {
                    self.modifiedEnrichedContent = enrichedContent
                    self.updateHeadings()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func onViewAppear() {
            isPresented = true
    }
    
    func updateTitle(_ newTitle: String) {
        recording.title = newTitle
        onRecordingUpdated?(recording)
        print("标题已保存: \(newTitle)")
    }
    
    func toggleTranscriptionPage() {
        guard hasPolishedText else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTranscriptionPage = currentTranscriptionPage == 0 ? 1 : 0
        }
    }
    
    func selectHeading(at index: Int) {
        selectedHeadingId = "\(index)"
    }

    // MARK: - AI 深度分析手动触发

    /// 检查是否有深度分析内容
    var hasEnrichedContent: Bool {
        guard let enrichedContent = recording.enrichedContent else { return false }
        return !enrichedContent.isEmpty
    }

    /// 手动触发生成深度分析内容（第二阶段）
    func generateEnrichedContent() async {
        guard !isGeneratingEnrichedContent else { return }

        // 获取用于生成的文本（优先使用润色文本）
        let textForAnalysis = recording.polishedText.isEmpty ? recording.transcription : recording.polishedText
        guard !textForAnalysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ToastManager.shared.showWarning("没有可分析的文本内容")
            return
        }

        isGeneratingEnrichedContent = true

        do {
            // 根据 contentType 确定 thoughtType
            let thoughtType: FlashThoughtType
            switch recording.contentType {
            case "inspiration":
                thoughtType = .insight
            case "thinking":
                thoughtType = .reflection
            default:
                thoughtType = .unknown
            }

            // 使用 ContentEnricher 生成 enrichedContent
            let contentEnricher = ContentEnricher()
            let enrichedContent = try await contentEnricher.analyze((textForAnalysis, thoughtType))

            // 更新录音记录
            var updatedRecording = recording
            updatedRecording.enrichedContent = enrichedContent
            recording = updatedRecording

            // 更新本地状态
            modifiedEnrichedContent = enrichedContent
            updateHeadings()

            // 同步到 Store
            store.updateRecording(updatedRecording)
            onRecordingUpdated?(updatedRecording)

            print("✅ 深度分析生成成功")

        } catch {
            print("❌ 深度分析生成失败: \(error.localizedDescription)")
            ToastManager.shared.showError("生成失败，请重试")
        }

        isGeneratingEnrichedContent = false
    }
    
    func editSection(at index: Int, content: String) {
        editingSectionIndex = index
        editingSectionContent = content
        isEditingSectionPresented = true
    }
    
    func deleteSection(at index: Int) {
        guard !modifiedEnrichedContent.isEmpty else { return }
        
        print("🗑️ deleteSection: 开始删除section \(index)")
        
        let parser = MarkdownSectionParser(content: modifiedEnrichedContent)
        var sections = parser.parseSections()
        
        print("🗑️ deleteSection: 解析出 \(sections.count) 个段落")
        
        guard index < sections.count else {
            print("❌ deleteSection: index \(index) 超出范围 (总共 \(sections.count) 个段落)")
            return
        }
        
        let deletedContent = sections[index]
        sections.remove(at: index)
        print("🗑️ deleteSection: 删除了段落: \(deletedContent.prefix(50))...")
        
        modifiedEnrichedContent = sections.joined(separator: "\n\n")
        print("🗑️ deleteSection: 重新组合后的内容长度: \(modifiedEnrichedContent.count)")
        
        if saveModifiedContentWithResult() {
            updateHeadings()
            ToastManager.shared.showSuccess("段落已删除")
        } else {
            if let enrichedContent = recording.enrichedContent {
                modifiedEnrichedContent = enrichedContent
                updateHeadings()
            }
            ToastManager.shared.showError("删除失败，请重试")
        }
    }
    
    func updateSection(at index: Int, with newContent: String) {
        guard !modifiedEnrichedContent.isEmpty else { return }
        
        let parser = MarkdownSectionParser(content: modifiedEnrichedContent)
        var sections = parser.parseSections()
        
        guard index < sections.count else { return }
        sections[index] = newContent
        
        modifiedEnrichedContent = sections.joined(separator: "\n\n")
        saveModifiedContent()
        updateHeadings()
        ToastManager.shared.showSuccess("段落已更新")
    }
    
    // MARK: - Audio Control Methods
    func togglePlayback() {
        if audioManager.isPlaying {
            audioManager.stopPlaying()
        } else {
            // 如果audioData为空，先从数据库加载
            if recording.audioData == nil {
                recording.audioData = DatabaseManager.shared.getAudioData(for: recording.audioDataId)
            }
            
            if let audioData = recording.audioData {
                if MockDataService.shared.isMockAudioData(audioData) {
                    showMockDataAlert()
                } else {
                    audioManager.playRecording(recording)
                }
            } else {
                print("⚠️ 无法获取音频数据，录音ID: \(recording.audioDataId)")
                showErrorAlert(message: "无法获取音频数据，请重试")
            }
        }
    }
    
    private func showMockDataAlert() {
        audioManager.isPlaying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.audioManager.isPlaying = false
        }
    }
    
    // MARK: - File Operation Methods
    func shareRecording() {
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
        
        presentViewController(activityVC)
    }
    
    func exportRecording() {
        copySummary()
    }
    
    func deleteRecording() {
        onDismiss?()
    }
    
    func downloadAudio() {
        // 如果audioData为空，先从数据库加载
        if recording.audioData == nil {
            recording.audioData = DatabaseManager.shared.getAudioData(for: recording.audioDataId)
        }
        
        guard let audioData = recording.audioData else {
            print("没有音频数据可供下载")
            showErrorAlert(message: "没有可用的音频数据")
            return
        }
        
        if MockDataService.shared.isMockAudioData(audioData) {
            print("检测到模拟音频数据，无法下载")
            showErrorAlert(message: MockDataService.shared.demoModeMessage + "，无法下载音频")
            return
        }
        
        let wavHeaderBytes = [UInt8](audioData.prefix(4))
        let isWAV = wavHeaderBytes == [0x52, 0x49, 0x46, 0x46]
        
        if !isWAV {
            print("音频数据格式无效，不是有效的WAV文件")
            showErrorAlert(message: "音频数据格式无效")
            return
        }
        
        if audioData.count < 44 {
            print("音频数据太小，无效的WAV文件: \(audioData.count) bytes")
            showErrorAlert(message: "音频数据无效")
            return
        }
        
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
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try audioData.write(to: fileURL)
            print("音频文件已保存到: \(fileURL)")
            print("文件大小: \(audioData.count) bytes")
            
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("临时文件已清理")
                } catch {
                    print("清理临时文件失败: \(error)")
                }
            }
            
            presentViewController(activityVC)
        } catch {
            print("保存音频文件失败: \(error)")
            showErrorAlert(message: "保存音频文件失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    private func extractTitle(from summary: String) -> String {
        let sentences = summary.components(separatedBy: CharacterSet(charactersIn: "。！？"))
        if let firstSentence = sentences.first, !firstSentence.isEmpty {
            if firstSentence.count > 30 {
                return String(firstSentence.prefix(30)) + "..."
            }
            return firstSentence
        }
        return "录音记录"
    }
    
    private func copySummary() {
        let fullContent = """
        \(recording.transcription)
        
        ---
        
        \(recording.summary)
        """
        UIPasteboard.general.string = fullContent
    }
    
    private func updateHeadings() {
        let headingTree = MarkdownHeadingParser.parseHeadings(from: modifiedEnrichedContent)
        withAnimation(.easeInOut(duration: 0.3)) {
            self.headings = headingTree.flatList
            if !headingTree.flatList.isEmpty && selectedHeadingId == nil {
                self.selectedHeadingId = "0"
            }
        }
    }
    
    private func saveModifiedContent() {
        _ = saveModifiedContentWithResult()
    }
    
    private func saveModifiedContentWithResult() -> Bool {
        var updatedRecording = recording
        updatedRecording.enrichedContent = modifiedEnrichedContent

        recording = updatedRecording
        store.updateRecording(updatedRecording)
        onRecordingUpdated?(updatedRecording)
        print("✅ saveModifiedContent: 数据已同步更新")
        return true
    }
    
    private func presentViewController(_ viewController: UIViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = viewController.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(viewController, animated: true)
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "提示",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        presentViewController(alert)
    }
}

// MARK: - Markdown段落解析器
private class MarkdownSectionParser {
    let content: String
    
    init(content: String) {
        self.content = content
    }
    
    func parseSections() -> [String] {
        var sections: [String] = []
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        var currentSection: [String] = []
        
        for line in lines {
            if isHeadingLine(line) && !currentSection.isEmpty {
                sections.append(currentSection.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
                currentSection = [line]
            } else {
                currentSection.append(line)
            }
        }
        
        if !currentSection.isEmpty {
            let sectionContent = currentSection.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !sectionContent.isEmpty {
                sections.append(sectionContent)
            }
        }
        
        return sections
    }
    
    private func isHeadingLine(_ line: String) -> Bool {
        let pattern = "^#{1,6}\\s+.+$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        let range = NSRange(location: 0, length: line.utf16.count)
        return regex.firstMatch(in: line, options: [], range: range) != nil
    }
}
