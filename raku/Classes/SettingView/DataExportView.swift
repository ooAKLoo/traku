//
//  DataExportView.swift
//  raku
//
//  Created by Assistant on 2025/9/22.
//  数据导出视图
//

import SwiftUI
import UniformTypeIdentifiers

struct DataExportView: View {
    let isDarkMode: Bool
    @Binding var isPresented: Bool
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var exportStatus = ""
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var exportError: String?

    private let databaseManager = DatabaseManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                (isDarkMode ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    // 导出图标和说明
                    VStack(spacing: 20) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("数据导出")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(isDarkMode ? .white : .black)

                        Text("导出所有录音记录、标签和分析数据到JSON文件")
                            .font(.body)
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if isExporting {
                        // 导出进度
                        VStack(spacing: 15) {
                            ProgressView(value: exportProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .frame(height: 8)
                                .padding(.horizontal, 40)

                            Text(exportStatus)
                                .font(.system(size: 14))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                        }
                    } else {
                        // 导出按钮
                        Button(action: startExport) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 20))
                                Text("开始导出")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 30)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.blue)
                            )
                        }
                    }

                    // 错误信息
                    if let error = exportError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // 导出说明
                    VStack(alignment: .leading, spacing: 8) {
                        Text("导出内容包括：")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : .black)

                        VStack(alignment: .leading, spacing: 4) {
                            exportInfoRow("• 所有录音记录和转录文本")
                            exportInfoRow("• 标签和分类信息")
                            exportInfoRow("• AI分析结果和摘要")
                            exportInfoRow("• 录音元数据和时间戳")
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
                    )
                    .padding(.horizontal)
                }
                .padding(.top, 20)
            }
            .navigationTitle("数据导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white : .black)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private func exportInfoRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
    }

    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        exportError = nil
        exportStatus = "准备导出数据..."

        Task {
            do {
                // 第一步：获取所有数据
                await updateProgress(0.1, "获取录音记录...")
                let recordings = databaseManager.loadRecordings()

                // 第二步：构建导出数据
                await updateProgress(0.5, "构建导出数据...")
                let exportData = ExportData(
                    exportDate: Date(),
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                    recordings: recordings.map { ExportRecording(from: $0) },
                    totalRecordings: recordings.count
                )

                // 第三步：转换为JSON
                await updateProgress(0.7, "生成JSON文件...")
                let jsonData = try JSONEncoder().encode(exportData)

                // 第四步：保存文件
                await updateProgress(0.9, "保存文件...")
                let fileName = "RakuData_\(DateFormatter.yyyyMMddHHmmss.string(from: Date())).json"
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsPath.appendingPathComponent(fileName)

                try jsonData.write(to: fileURL)

                await updateProgress(1.0, "导出完成!")

                // 延迟一下显示完成状态
                try await Task.sleep(nanoseconds: 500_000_000)

                await MainActor.run {
                    exportedFileURL = fileURL
                    isExporting = false
                    showingShareSheet = true
                }

            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = "导出失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updateProgress(_ progress: Double, _ status: String) async {
        await MainActor.run {
            exportProgress = progress
            exportStatus = status
        }
    }
}

// MARK: - 导出数据模型

struct ExportData: Codable {
    let exportDate: Date
    let appVersion: String
    let recordings: [ExportRecording]
    let totalRecordings: Int
}

struct ExportRecording: Codable {
    let id: String
    let timestamp: Date
    let duration: TimeInterval
    let transcription: String
    let title: String
    let summary: String
    let tags: [String]
    let enrichedContent: String?
    let polishedText: String?
    let contentType: String

    init(from recording: AudioRecording) {
        self.id = recording.id.uuidString
        self.timestamp = recording.timestamp
        self.duration = recording.duration
        self.transcription = recording.transcription
        self.title = recording.title
        self.summary = recording.summary
        self.tags = recording.tags
        self.enrichedContent = recording.enrichedContent
        self.polishedText = recording.polishedText
        self.contentType = recording.contentType
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let yyyyMMddHHmmss: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
