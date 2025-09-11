//
//  ExportOptionsSheet.swift
//  raku
//
//  Created by 杨东举 on 2025/9/10.
//

import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

enum ExportFormat {
    case text
    case pdf
    case image
}

struct ExportOptionsSheet: View {
    @Binding var isPresented: Bool
    let recording: AudioRecording
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var selectedFormat: ExportFormat?
    @State private var showDestinationView = false
    
    var body: some View {
        ZStack {
            // 第一页：导出格式选择
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text("导出选项")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                // 导出选项列表
                VStack(spacing: 12) {
                    ExportOptionRow(
                        icon: "doc.text",
                        title: "文本格式",
                        description: "导出为纯文本文件",
                        isDarkMode: isDarkMode,
                        action: { 
                            selectedFormat = .text
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showDestinationView = true
                            }
                        }
                    )
                    
                    ExportOptionRow(
                        icon: "doc.richtext",
                        title: "PDF文档",
                        description: "导出为PDF格式，包含完整排版",
                        isDarkMode: isDarkMode,
                        action: { 
                            selectedFormat = .pdf
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showDestinationView = true
                            }
                        }
                    )
                    
                    ExportOptionRow(
                        icon: "photo",
                        title: "图像格式",
                        description: "导出为PNG图片，便于分享",
                        isDarkMode: isDarkMode,
                        action: { 
                            selectedFormat = .image
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showDestinationView = true
                            }
                        }
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                Spacer()
            }
            .background(isDarkMode ? Color.black : Color.white)
            .offset(x: showDestinationView ? -UIScreen.main.bounds.width : 0)
            
            // 第二页：目标位置选择
            ExportDestinationViewEmbedded(
                isPresented: $isPresented,
                exportFormat: selectedFormat ?? .text,
                recording: recording,
                showDestinationView: $showDestinationView,
                selectedFormat: $selectedFormat
            )
            .offset(x: showDestinationView ? 0 : UIScreen.main.bounds.width)
            .opacity(selectedFormat != nil ? 1 : 0)
        }
        .clipped()
    }
}

// MARK: - Export Option Row
struct ExportOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let isDarkMode: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Embedded Export Destination View
struct ExportDestinationViewEmbedded: View {
    @Binding var isPresented: Bool
    let exportFormat: ExportFormat
    let recording: AudioRecording
    @Binding var showDestinationView: Bool
    @Binding var selectedFormat: ExportFormat?
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var showingExporter = false
    @State private var exportDocument: ExportDocument?
    @State private var exportFileName = ""
    
    var formatName: String {
        switch exportFormat {
        case .text:
            return "文本文件"
        case .pdf:
            return "PDF文档"
        case .image:
            return "PNG图片"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDestinationView = false 
                    }
                    // 延迟重置以避免影响动画
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedFormat = nil
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                }
                
                Spacer()
                
                Text("选择保存位置")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                // 占位符，保持标题居中
                Color.clear
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            // 格式提示
            HStack {
                Image(systemName: iconForFormat(exportFormat))
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                Text("将导出为\(formatName)")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            
            // 目标选项
            VStack(spacing: 12) {
                DestinationOptionRow(
                    icon: "folder",
                    title: "保存到文件",
                    description: "保存到iCloud云盘或本地存储",
                    isDarkMode: isDarkMode,
                    action: { 
                        exportTo(.files)
                    }
                )
                
                DestinationOptionRow(
                    icon: "square.and.arrow.up",
                    title: "分享",
                    description: "通过其他应用分享",
                    isDarkMode: isDarkMode,
                    action: { exportTo(.share) }
                )
                
                if exportFormat == .text {
                    DestinationOptionRow(
                        icon: "doc.on.clipboard",
                        title: "复制到剪贴板",
                        description: "复制内容以便粘贴",
                        isDarkMode: isDarkMode,
                        action: { exportTo(.copyToClipboard) }
                    )
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(isDarkMode ? Color.black : Color.white)
        .overlay(
            Group {
                if isExporting {
                    ExportProgressView(progress: $exportProgress, isDarkMode: isDarkMode)
                        .transition(.opacity)
                }
            }
        )
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: contentTypeForFormat(exportFormat),
            defaultFilename: exportFileName
        ) { (result: Result<URL, Error>) in
            switch result {
            case .success(let url):
                print("export--- File successfully exported to: \(url)")
                ToastManager.shared.showSuccess("已保存到文件")
                isPresented = false
            case .failure(let error):
                print("export--- Export failed: \(error.localizedDescription)")
                ToastManager.shared.showError("导出失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 复制所有必要的方法从ExportDestinationView
    private func contentTypeForFormat(_ format: ExportFormat) -> UTType {
        switch format {
        case .text:
            return .plainText
        case .pdf:
            return .pdf
        case .image:
            return .png
        }
    }
    
    private func iconForFormat(_ format: ExportFormat) -> String {
        switch format {
        case .text:
            return "doc.text"
        case .pdf:
            return "doc.richtext"
        case .image:
            return "photo"
        }
    }
    
    private func exportTo(_ destination: ExportDestination) {
        print("export--- Starting export to destination: \(destination)")
        isExporting = true
        exportProgress = 0
        
        Task {
            do {
                print("export--- Generating file for format: \(exportFormat)")
                let fileURL = try await generateFile()
                print("export--- File generated at: \(fileURL.path)")
                
                // 验证文件是否存在并有内容
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("export--- File exists with size: \(fileSize) bytes")
                } else {
                    print("export--- ERROR: Generated file does not exist!")
                }
                
                await MainActor.run {
                    isExporting = false
                    
                    switch destination {
                    case .files:
                        print("export--- Preparing file exporter")
                        prepareFileExporter(fileURL)
                    case .share:
                        print("export--- Sharing file")
                        shareFile(fileURL)
                    case .copyToClipboard:
                        print("export--- Copying to clipboard")
                        copyToClipboard(fileURL)
                    }
                }
            } catch {
                print("export--- ERROR during export: \(error)")
                await MainActor.run {
                    isExporting = false
                    ToastManager.shared.showError("导出失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func generateFile() async throws -> URL {
        switch exportFormat {
        case .text:
            return try await exportAsText()
        case .pdf:
            return try await exportAsPDF()
        case .image:
            return try await exportAsImage()
        }
    }
    
    // MARK: - Export Functions
    
    private func exportAsText() async throws -> URL {
        print("export--- Starting text export")
        await updateProgress(0.2)
        
        let content = buildTextContent()
        print("export--- Text content length: \(content.count) characters")
        let fileName = "\(recording.title)_\(recording.timestamp.fileFormatted).txt"
        
        await updateProgress(0.6)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        print("export--- Writing text to: \(tempURL.path)")
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        
        // 验证写入
        let writtenContent = try String(contentsOf: tempURL, encoding: .utf8)
        print("export--- Verified written content length: \(writtenContent.count) characters")
        
        await updateProgress(1.0)
        
        return tempURL
    }
    
    private func exportAsPDF() async throws -> URL {
        print("export--- Starting PDF export")
        await updateProgress(0.1)
        
        let pdfRenderer = PDFRenderer()
        let content = buildFormattedContent()
        print("export--- Built formatted content")
        
        await updateProgress(0.3)
        
        let pdfData = await pdfRenderer.renderPDF(
            content: content,
            title: recording.title,
            isDarkMode: isDarkMode
        )
        print("export--- PDF data size: \(pdfData.count) bytes")
        
        await updateProgress(0.7)
        
        let fileName = "\(recording.title)_\(recording.timestamp.fileFormatted).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        print("export--- Writing PDF to: \(tempURL.path)")
        try pdfData.write(to: tempURL)
        
        // 验证写入
        let fileSize = try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64 ?? 0
        print("export--- Verified PDF file size: \(fileSize) bytes")
        
        await updateProgress(1.0)
        
        return tempURL
    }
    
    private func exportAsImage() async throws -> URL {
        print("export--- Starting image export")
        await updateProgress(0.1)
        
        let imageRenderer = ImageRenderer()
        let content = buildFormattedContent()
        print("export--- Built formatted content for image")
        
        await updateProgress(0.3)
        
        let image = await imageRenderer.renderImage(
            content: content,
            title: recording.title,
            isDarkMode: isDarkMode
        )
        print("export--- Image rendered")
        
        await updateProgress(0.7)
        
        guard let pngData = image.pngData() else {
            print("export--- ERROR: Failed to generate PNG data")
            throw ExportError.imageGenerationFailed
        }
        print("export--- PNG data size: \(pngData.count) bytes")
        
        let fileName = "\(recording.title)_\(recording.timestamp.fileFormatted).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        print("export--- Writing PNG to: \(tempURL.path)")
        try pngData.write(to: tempURL)
        
        // 验证写入
        let fileSize = try FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int64 ?? 0
        print("export--- Verified PNG file size: \(fileSize) bytes")
        
        await updateProgress(1.0)
        
        return tempURL
    }
    
    // MARK: - Destination Actions
    
    private func prepareFileExporter(_ url: URL) {
        print("export--- Preparing file exporter for URL: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            print("export--- Loaded data size: \(data.count) bytes")
            
            // 设置文件名
            exportFileName = url.lastPathComponent
            print("export--- Export filename: \(exportFileName)")
            
            // 创建导出文档
            exportDocument = ExportDocument(data: data)
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: url)
            print("export--- Temporary file cleaned up")
            
            // 显示文件导出器
            showingExporter = true
        } catch {
            print("export--- ERROR: Failed to load file data: \(error)")
            ToastManager.shared.showError("准备导出失败")
        }
    }
    
    private func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        activityVC.completionWithItemsHandler = { _, completed, _, _ in
            // 清理临时文件
            try? FileManager.default.removeItem(at: url)
            if completed {
                ToastManager.shared.showSuccess("分享成功")
                isPresented = false
            }
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func copyToClipboard(_ url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            UIPasteboard.general.string = content
            try? FileManager.default.removeItem(at: url)
            ToastManager.shared.showSuccess("已复制到剪贴板")
            isPresented = false
        } catch {
            ToastManager.shared.showError("复制失败")
        }
    }
    
    // MARK: - Helper Functions
    
    private func buildTextContent() -> String {
        var content = """
        标题: \(recording.title)
        时间: \(recording.timestamp.smartFormatted)
        标签: \(recording.tags.joined(separator: ", "))
        
        ---
        
        转写内容:
        \(recording.transcription)
        
        """
        
        if !recording.polishedText.isEmpty {
            content += """
            
            ---
            
            润色版本:
            \(recording.polishedText)
            
            """
        }
        
        if let enrichedContent = recording.enrichedContent {
            content += """
            
            ---
            
            AI总结:
            \(enrichedContent)
            """
        }
        
        return content
    }
    
    private func buildFormattedContent() -> AttributedString {
        var attributedString = AttributedString()
        
        // 标题
        var titleText = AttributedString(recording.title)
        titleText.font = .system(size: 24, weight: .bold)
        attributedString.append(titleText)
        attributedString.append(AttributedString("\n\n"))
        
        // 元数据
        var metaText = AttributedString("\(recording.timestamp.smartFormatted) • \(recording.tags.joined(separator: ", "))")
        metaText.font = .system(size: 14)
        metaText.foregroundColor = .gray
        attributedString.append(metaText)
        attributedString.append(AttributedString("\n\n"))
        
        // 转写内容
        var transcriptionTitle = AttributedString("转写内容")
        transcriptionTitle.font = .system(size: 18, weight: .semibold)
        attributedString.append(transcriptionTitle)
        attributedString.append(AttributedString("\n"))
        
        var transcriptionText = AttributedString(recording.transcription)
        transcriptionText.font = .system(size: 16)
        attributedString.append(transcriptionText)
        attributedString.append(AttributedString("\n\n"))
        
        // 润色版本（如果有）
        if !recording.polishedText.isEmpty {
            var polishedTitle = AttributedString("润色版本")
            polishedTitle.font = .system(size: 18, weight: .semibold)
            attributedString.append(polishedTitle)
            attributedString.append(AttributedString("\n"))
            
            var polishedText = AttributedString(recording.polishedText)
            polishedText.font = .system(size: 16)
            attributedString.append(polishedText)
            attributedString.append(AttributedString("\n\n"))
        }
        
        // AI总结（如果有）
        if let enrichedContent = recording.enrichedContent {
            var aiTitle = AttributedString("AI总结")
            aiTitle.font = .system(size: 18, weight: .semibold)
            attributedString.append(aiTitle)
            attributedString.append(AttributedString("\n"))
            
            var aiText = AttributedString(enrichedContent)
            aiText.font = .system(size: 16)
            attributedString.append(aiText)
        }
        
        return attributedString
    }
    
    private func updateProgress(_ value: Double) async {
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                exportProgress = value
            }
        }
    }
}


