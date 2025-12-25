//
//  SimilarRecordingPreviewSheet.swift
//  raku
//
//  相似内容预览 Sheet - 点击相似内容时以 Sheet 方式预览，避免用户迷失路径
//

import SwiftUI
import MarkdownUI

struct SimilarRecordingPreviewSheet: View {
    let initialRecording: AudioRecording
    let isDarkMode: Bool

    @Environment(\.dismiss) private var dismiss

    // 当前显示的记录
    @State private var currentRecording: AudioRecording
    // 浏览历史栈 - 用于返回上一个预览
    @State private var historyStack: [AudioRecording] = []
    @State private var similarRecordings: [AudioRecording] = []
    @State private var isLoadingSimilar = true

    // AI 分析内容解析
    @State private var headings: [HeadingNode] = []

    init(initialRecording: AudioRecording, isDarkMode: Bool) {
        self.initialRecording = initialRecording
        self.isDarkMode = isDarkMode
        self._currentRecording = State(initialValue: initialRecording)
    }

    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                (isDarkMode ? Color.black : Color.white)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 浏览路径指示器 - 固定在顶部
                    if !historyStack.isEmpty {
                        breadcrumbView
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 标题区域
                            titleSection
                                .padding(.horizontal, 20)
                                .padding(.top, 16)

                            // 转写内容
                            transcriptionSection
                                .padding(.horizontal, 20)
                                .padding(.top, 24)

                            // AI 分析内容
                            if let enrichedContent = currentRecording.enrichedContent, !enrichedContent.isEmpty {
                                aiAnalysisSection(content: enrichedContent)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 32)
                            }

                            // 相似内容
                            similarContentSection
                                .padding(.horizontal, 20)
                                .padding(.top, 32)
                                .padding(.bottom, 60)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: handleBack) {
                        HStack(spacing: 4) {
                            Image(systemName: historyStack.isEmpty ? "xmark" : "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            if !historyStack.isEmpty {
                                Text("返回")
                                    .font(.system(size: 15))
                            }
                        }
                        .foregroundColor(isDarkMode ? .white : .black)
                    }
                }
            }
        }
        .onAppear {
            loadSimilarRecordings()
            parseHeadings()
        }
        .onChange(of: currentRecording.id) { _ in
            loadSimilarRecordings()
            parseHeadings()
        }
    }

    // MARK: - 面包屑导航
    private var breadcrumbView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(historyStack.enumerated()), id: \.element.id) { index, recording in
                        Button(action: {
                            navigateToHistory(at: index)
                        }) {
                            HStack(spacing: 4) {
                                Text(truncateTitle(recording.title))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5))
                                    .lineLimit(1)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.25))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // 当前项（高亮）
                    Text(truncateTitle(currentRecording.title))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .lineLimit(1)
                        .id("current_breadcrumb")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                )
            }
            .onAppear {
                proxy.scrollTo("current_breadcrumb", anchor: .trailing)
            }
            .onChange(of: currentRecording.id) { _ in
                withAnimation {
                    proxy.scrollTo("current_breadcrumb", anchor: .trailing)
                }
            }
        }
    }

    // MARK: - 标题区域
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(currentRecording.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(isDarkMode ? .white : .black)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                // 时间
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(formatDate(currentRecording.timestamp))
                        .font(.system(size: 12))
                }
                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.4))

                // 时长
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 11))
                    Text(formatDuration(currentRecording.duration))
                        .font(.system(size: 12))
                }
                .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.4))
            }

            // 标签
            if !currentRecording.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(currentRecording.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                            Text(tag)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.12))
                        )
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                    }
                }
            }
        }
    }

    // MARK: - 转写内容
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("转写内容")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5))

            HStack(alignment: .top, spacing: 8) {
                Text("\u{201C}")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(isDarkMode ? Color.white.opacity(0.12) : Color.gray.opacity(0.18))
                    .offset(y: -8)

                Text(getDisplayTranscription())
                    .font(.system(size: 15))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.65))
                    .italic()
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - AI 分析内容
    private func aiAnalysisSection(content: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 分析")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5))

            Markdown(content)
                .markdownTheme(.customCompact)
                .markdownTextStyle {
                    FontSize(15)
                }
        }
    }

    // MARK: - 相似内容区域
    private var similarContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("相似内容")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)

                Spacer()

                if isLoadingSimilar {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if isLoadingSimilar {
                // 加载占位符
                ForEach(0..<2, id: \.self) { index in
                    similarItemPlaceholder
                }
            } else if similarRecordings.isEmpty {
                // 空状态
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(isDarkMode ? .white.opacity(0.25) : .gray.opacity(0.4))
                    Text("暂无相似内容")
                        .font(.system(size: 13))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .gray.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // 相似内容列表
                ForEach(similarRecordings) { recording in
                    similarItemView(recording: recording)
                        .onTapGesture {
                            navigateToSimilar(recording)
                        }
                }
            }
        }
    }

    // MARK: - 相似内容项
    private func similarItemView(recording: AudioRecording) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recording.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
                .lineLimit(2)

            if !recording.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(recording.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.1))
                            )
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color(hex: "F5F5F3"))
        )
        .contentShape(Rectangle())
    }

    // MARK: - 加载占位符
    private var similarItemPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2))
                .frame(height: 18)
                .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.12))
                    .frame(width: 50, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.12))
                    .frame(width: 40, height: 14)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.04) : Color.gray.opacity(0.08))
        )
        .redacted(reason: .placeholder)
    }

    // MARK: - 导航逻辑

    /// 点击相似内容，进入新的预览（将当前内容推入历史栈）
    private func navigateToSimilar(_ recording: AudioRecording) {
        withAnimation(.easeInOut(duration: 0.25)) {
            historyStack.append(currentRecording)
            currentRecording = recording
        }

        // 触觉反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    /// 返回按钮处理
    private func handleBack() {
        if historyStack.isEmpty {
            // 没有历史，关闭 Sheet
            dismiss()
        } else {
            // 返回上一个内容
            withAnimation(.easeInOut(duration: 0.25)) {
                currentRecording = historyStack.removeLast()
            }
        }
    }

    /// 点击面包屑导航到历史中的某一项
    private func navigateToHistory(at index: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentRecording = historyStack[index]
            // 移除该索引之后的所有历史
            historyStack = Array(historyStack.prefix(index))
        }
    }

    // MARK: - 数据加载

    private func loadSimilarRecordings() {
        isLoadingSimilar = true

        let currentEmbedding = DatabaseManager.shared.getEmbeddingVector(id: currentRecording.id)

        guard let currentEmbedding = currentEmbedding else {
            isLoadingSimilar = false
            similarRecordings = []
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let allRecordings = DatabaseManager.shared.loadRecordings()
            var similarityResults: [(recording: AudioRecording, similarity: Float)] = []
            let calculator = CosineSimilarityCalculator()

            // 排除当前记录和历史栈中的记录
            let excludeIds = Set([currentRecording.id] + historyStack.map { $0.id })

            for recording in allRecordings {
                guard !excludeIds.contains(recording.id) else { continue }
                guard let embedding = DatabaseManager.shared.getEmbeddingVector(id: recording.id) else { continue }

                let similarity = calculator.calculate(vector1: currentEmbedding, vector2: embedding)
                similarityResults.append((recording: recording, similarity: similarity))
            }

            let topSimilar = similarityResults
                .sorted { $0.similarity > $1.similarity }
                .prefix(3)
                .map { $0.recording }

            DispatchQueue.main.async {
                self.isLoadingSimilar = false
                self.similarRecordings = Array(topSimilar)
            }
        }
    }

    private func parseHeadings() {
        if let content = currentRecording.enrichedContent {
            let tree = MarkdownHeadingParser.parseHeadings(from: content)
            headings = tree.flatList
        } else {
            headings = []
        }
    }

    // MARK: - 辅助方法

    private func getDisplayTranscription() -> String {
        // 优先显示润色后的文本
        if !currentRecording.polishedText.isEmpty {
            return currentRecording.polishedText
        }
        return currentRecording.transcription
    }

    private func truncateTitle(_ title: String, maxLength: Int = 8) -> String {
        if title.count <= maxLength {
            return title
        }
        return String(title.prefix(maxLength)) + "..."
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 预览
struct SimilarRecordingPreviewSheet_Previews: PreviewProvider {
    static var previews: some View {
        SimilarRecordingPreviewSheet(
            initialRecording: AudioRecording(
                timestamp: Date(),
                duration: 120,
                transcription: "这是一段测试转写内容...",
                title: "测试录音",
                summary: "测试摘要",
                tags: ["测试", "预览"],
                audioData: Data(),
                enrichedContent: "## 测试标题\n这是测试内容"
            ),
            isDarkMode: false
        )
    }
}
