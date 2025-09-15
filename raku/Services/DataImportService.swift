//
//  DataImportService.swift
//  raku
//
//  Created by Assistant for JSON data import functionality
//

import Foundation
import SwiftUI

// MARK: - 数据导入结果
struct DataImportResult {
    let success: Bool
    let importedCount: Int
    let skippedCount: Int
    let errorCount: Int
    let errors: [String]
    
    var message: String {
        if success {
            return "导入成功！\n成功导入: \(importedCount) 条\n跳过重复: \(skippedCount) 条"
        } else {
            return "导入失败\n错误数量: \(errorCount)\n详细错误: \(errors.joined(separator: "\n"))"
        }
    }
}

// MARK: - JSON数据导入服务
class DataImportService {
    static let shared = DataImportService()
    
    private init() {}
    
    // MARK: - 主要导入方法
    
    /// 从JSON文件导入AudioRecording数据
    /// - Parameter url: JSON文件的URL
    /// - Returns: 导入结果
    func importAudioRecordingsFromJSON(from url: URL) async -> DataImportResult {
        do {
            // 读取JSON文件
            let data = try Data(contentsOf: url)
            print("📁 成功读取JSON文件，大小: \(data.count) bytes")
            
            // 解析JSON数据
            let jsonObjects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            guard let recordingDicts = jsonObjects else {
                return DataImportResult(
                    success: false,
                    importedCount: 0,
                    skippedCount: 0,
                    errorCount: 1,
                    errors: ["JSON格式错误：根节点不是数组"]
                )
            }
            
            print("📊 JSON文件包含 \(recordingDicts.count) 条记录")
            
            // 处理每条记录
            return await processRecordings(recordingDicts)
            
        } catch {
            print("❌ 读取JSON文件失败: \(error)")
            return DataImportResult(
                success: false,
                importedCount: 0,
                skippedCount: 0,
                errorCount: 1,
                errors: ["文件读取失败: \(error.localizedDescription)"]
            )
        }
    }
    
    // MARK: - 私有处理方法
    
    /// 处理录音记录数组
    private func processRecordings(_ recordingDicts: [[String: Any]]) async -> DataImportResult {
        var importedCount = 0
        var skippedCount = 0
        var errorCount = 0
        var errors: [String] = []
        
        for (index, dict) in recordingDicts.enumerated() {
            do {
                let result = await processSingleRecording(dict, index: index)
                
                switch result {
                case .success(.imported):
                    importedCount += 1
                case .success(.skipped):
                    skippedCount += 1
                case .failure(let error):
                    errorCount += 1
                    errors.append("记录 \(index + 1): \(error.localizedDescription)")
                }
                
            } catch {
                errorCount += 1
                errors.append("记录 \(index + 1): \(error.localizedDescription)")
            }
        }
        
        let success = errorCount == 0 || (importedCount + skippedCount) > 0
        
        print("✅ 导入完成: 成功=\(importedCount), 跳过=\(skippedCount), 错误=\(errorCount)")
        
        return DataImportResult(
            success: success,
            importedCount: importedCount,
            skippedCount: skippedCount,
            errorCount: errorCount,
            errors: errors
        )
    }
    
    /// 处理单条录音记录
    private func processSingleRecording(_ dict: [String: Any], index: Int) async -> Result<ImportStatus, ImportError> {
        // 解析基本字段
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString) else {
            return .failure(.invalidID)
        }
        
        // 检查记录是否已存在
        if DatabaseManager.shared.getRecording(by: idString) != nil {
            print("⚠️ 记录已存在，跳过: \(idString)")
            return .success(.skipped)
        }
        
        guard let timestamp = dict["timestamp"] as? Double,
              let duration = dict["duration"] as? Double,
              let transcription = dict["transcription"] as? String,
              let title = dict["title"] as? String,
              let summary = dict["summary"] as? String else {
            return .failure(.missingRequiredFields)
        }
        
        // 解析可选字段
        let enrichedContent = dict["enriched_content"] as? String
        let polishedText = dict["polished_text"] as? String ?? ""
        let contentType = dict["content_type"] as? String ?? "thinking"
        
        // 解析标签
        var tags: [String] = []
        if let tagsArray = dict["tags"] as? [String] {
            tags = tagsArray
        } else if let tagsString = dict["tags"] as? String {
            // 如果tags是字符串格式（可能是JSON序列化的）
            if let tagsData = tagsString.data(using: .utf8),
               let decodedTags = try? JSONDecoder().decode([String].self, from: tagsData) {
                tags = decodedTags
            }
        }
        
        // 创建AudioRecording对象
        let recording = AudioRecording(
            id: id,
            timestamp: Date(timeIntervalSince1970: timestamp),
            duration: duration,
            transcription: transcription,
            title: title,
            summary: summary,
            tags: tags,
            audioData: nil, // JSON导入不包含音频数据
            enrichedContent: enrichedContent,
            polishedText: polishedText,
            contentType: contentType
        )
        
        // 保存到数据库
        let saveSuccess = DatabaseManager.shared.saveOrUpdateRecording(recording)
        if !saveSuccess {
            return .failure(.databaseSaveFailed)
        }
        
        // 处理embedding向量（如果存在）
        if let embeddingArray = dict["embedding_vector"] as? [Double], !embeddingArray.isEmpty {
            let embeddingVector = embeddingArray.map { Float($0) }
            let embeddingSuccess = DatabaseManager.shared.updateEmbeddingVector(
                id: id,
                embeddingVector: embeddingVector
            )
            
            if embeddingSuccess {
                print("✅ 成功导入embedding向量，维度: \(embeddingVector.count)")
            } else {
                print("⚠️ embedding向量保存失败")
            }
        } else if let embeddingArray = dict["embedding_vector"] as? [Float], !embeddingArray.isEmpty {
            let embeddingSuccess = DatabaseManager.shared.updateEmbeddingVector(
                id: id,
                embeddingVector: embeddingArray
            )
            
            if embeddingSuccess {
                print("✅ 成功导入embedding向量，维度: \(embeddingArray.count)")
            } else {
                print("⚠️ embedding向量保存失败")
            }
        }
        
        print("✅ 成功导入记录: \(title)")
        return .success(.imported)
    }
}

// MARK: - 辅助枚举和错误类型
private enum ImportStatus {
    case imported
    case skipped
}

private enum ImportError: Error, LocalizedError {
    case invalidID
    case missingRequiredFields
    case databaseSaveFailed
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidID:
            return "无效的ID字段"
        case .missingRequiredFields:
            return "缺少必需字段"
        case .databaseSaveFailed:
            return "数据库保存失败"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - 文件选择器包装器
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURL = urls.first
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - 导入进度视图
struct DataImportProgressView: View {
    let isDarkMode: Bool
    @Binding var isPresented: Bool
    @State private var progress: Double = 0.0
    @State private var statusMessage = "准备导入..."
    @State private var importResult: DataImportResult?
    @State private var isImporting = false
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    
    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    if let result = importResult {
                        // 导入完成状态
                        VStack(spacing: 20) {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(result.success ? .green : .red)
                            
                            Text(result.success ? "导入完成!" : "导入失败")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Text(result.message)
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                    } else if isImporting {
                        // 导入进行中
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Text(statusMessage)
                                .font(.system(size: 18))
                                .foregroundColor(isDarkMode ? .white : .black)
                        }
                        
                    } else {
                        // 选择文件状态
                        VStack(spacing: 25) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                            
                            Text("选择JSON文件导入")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(isDarkMode ? .white : .black)
                            
                            Text("支持包含AudioRecording数据和embedding向量的JSON文件")
                                .font(.system(size: 16))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                showingFilePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("选择文件")
                                }
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("数据导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingFilePicker) {
            DocumentPicker(selectedURL: $selectedFileURL, isPresented: $showingFilePicker)
        }
        .onChange(of: selectedFileURL) { url in
            if let url = url {
                startImport(from: url)
            }
        }
    }
    
    private func startImport(from url: URL) {
        isImporting = true
        statusMessage = "正在读取文件..."
        
        Task {
            let result = await DataImportService.shared.importAudioRecordingsFromJSON(from: url)
            
            await MainActor.run {
                self.importResult = result
                self.isImporting = false
            }
        }
    }
}