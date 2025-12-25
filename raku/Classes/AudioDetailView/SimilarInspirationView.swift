//
//  SimilarInspirationView.swift
//  相似内容展示视图 - 显示与当前记录相似的其他条目
//

import SwiftUI

struct SimilarInspirationView: View {
    let currentRecording: AudioRecording
    let isDarkMode: Bool

    @State private var similarRecordings: [AudioRecording] = []
    @State private var isLoading = true
    @State private var shouldHide = false
    @State private var selectedRecording: AudioRecording?
    @State private var isSelectionMode = false
    @State private var selectedInspirations: Set<UUID> = []

    var body: some View {
        Group {
            if shouldHide {
                // 没有向量数据时完全隐藏
                EmptyView()
            } else {
                contentView
            }
        }
        .sheet(item: $selectedRecording) { recording in
            SimilarRecordingPreviewSheet(
                initialRecording: recording,
                isDarkMode: isDarkMode
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            loadSimilarInspiration()
        }
        .globalBatchSelectionToolbar(
            isPresented: $isSelectionMode,
            selectedCount: selectedInspirations.count,
            totalCount: similarRecordings.count,
            actionTitle: "批量操作",
            actionIcon: "checkmark.circle.fill",
            onSelectAll: {
                selectedInspirations = Set(similarRecordings.map { $0.id })
            },
            onDeselectAll: {
                selectedInspirations.removeAll()
            },
            onAction: {
                // TODO: 批量操作逻辑
                exitSelectionMode()
            }
        )
        .onChange(of: isSelectionMode) { newValue in
            if !newValue {
                selectedInspirations.removeAll()
            }
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Text("相似内容")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                }
            }

            if isLoading {
                // 加载状态
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SimilarInspirationPlaceholder(isDarkMode: isDarkMode)
                    }
                }

            } else if similarRecordings.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .gray.opacity(0.5))

                    Text("暂无相似的内容记录")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)

            } else {
                // 相似灵感列表
                VStack(spacing: 16) {
                    ForEach(similarRecordings, id: \.id) { recording in
                        SimilarInspirationItem(
                            recording: recording,
                            isDarkMode: isDarkMode,
                            isSelectionMode: isSelectionMode,
                            isSelected: selectedInspirations.contains(recording.id),
                            onTap: {
                                if isSelectionMode {
                                    toggleSelection(for: recording.id)
                                } else {
                                    // 使用 Sheet 方式预览，避免用户在导航中迷失
                                    selectedRecording = recording
                                }
                            },
                            onSelectionToggle: {
                                toggleSelection(for: recording.id)
                            },
                            onLongPress: {
                                if !isSelectionMode {
                                    toggleSelectionMode()
                                    toggleSelection(for: recording.id)
                                }
                            },
                            onSwipeRight: {
                                if !isSelectionMode {
                                    toggleSelectionMode()
                                    toggleSelection(for: recording.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - 批量操作方法
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedInspirations.removeAll()
            }
        }

        // 立即更新浮窗数据
        if isSelectionMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let data = BatchSelectionData(
                    selectedCount: selectedInspirations.count,
                    totalCount: similarRecordings.count,
                    actionTitle: "批量操作",
                    actionIcon: "checkmark.circle.fill",
                    onSelectAll: {
                        selectedInspirations = Set(similarRecordings.map { $0.id })
                    },
                    onDeselectAll: {
                        selectedInspirations.removeAll()
                    },
                    onAction: {
                        // TODO: 批量操作逻辑
                        exitSelectionMode()
                    },
                    onDismiss: {
                        isSelectionMode = false
                    }
                )
                GlobalPopupManager.shared.batchSelectionData = data
            }
        }
    }

    private func exitSelectionMode() {
        // 立即隐藏浮窗
        GlobalPopupManager.shared.hideBatchSelectionImmediately()
        withAnimation(.easeInOut(duration: 0.25)) {
            isSelectionMode = false
            selectedInspirations.removeAll()
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedInspirations.contains(id) {
            selectedInspirations.remove(id)
        } else {
            selectedInspirations.insert(id)
        }
    }

    private func loadSimilarInspiration() {
        // 获取当前记录的向量
        let currentEmbedding = DatabaseManager.shared.getEmbeddingVector(id: currentRecording.id)

        guard let currentEmbedding = currentEmbedding else {
            // 没有向量数据时直接隐藏整个视图
            shouldHide = true
            isLoading = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [currentRecording] in
            // 从数据库获取所有录音记录
            let allRecordings = DatabaseManager.shared.loadRecordings()

            var similarityResults: [(recording: AudioRecording, similarity: Float)] = []
            let cosineSimilarityCalculator = CosineSimilarityCalculator()

            // 计算与每个候选记录的相似度（排除当前记录，且只处理有向量的记录）
            for recording in allRecordings {
                // 排除当前记录
                guard recording.id != currentRecording.id else { continue }

                // 获取向量并计算相似度（只查询一次数据库）
                guard let embedding = DatabaseManager.shared.getEmbeddingVector(id: recording.id) else {
                    continue
                }

                let similarity = cosineSimilarityCalculator.calculate(
                    vector1: currentEmbedding,
                    vector2: embedding
                )

                similarityResults.append((recording: recording, similarity: similarity))
            }

            // 按相似度降序排序，取前3个
            let topSimilar = similarityResults
                .sorted { $0.similarity > $1.similarity }
                .prefix(3)
                .map { $0.recording }

            DispatchQueue.main.async {
                self.isLoading = false
                self.similarRecordings = Array(topSimilar)
            }
        }
    }
}

// MARK: - 相似灵感条目
struct SimilarInspirationItem: View {
    let recording: AudioRecording
    let isDarkMode: Bool
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    let onTap: () -> Void
    var onSelectionToggle: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onSwipeRight: (() -> Void)?

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // 选择按钮（批量模式下显示）
            if isSelectionMode {
                Button(action: {
                    onSelectionToggle?()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .blue : (isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4)))
                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 18)
                .padding(.vertical, 16)
            }

            // 主内容
            contentView
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ?
                      (isDarkMode ? Color.blue.opacity(0.1) : Color.blue.opacity(0.05)) :
                      (isDarkMode ? Color.white.opacity(0.08) : Color(hex: "EBEBE9").opacity(0.3)))
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .contentShape(Rectangle())
        .offset(x: dragOffset)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress?()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onChanged { value in
                    // 只在明显的水平右滑手势时处理（水平位移要大于垂直位移的2倍）
                    if value.translation.width > 0 && abs(value.translation.width) > abs(value.translation.height) * 2 {
                        dragOffset = min(value.translation.width, 50)
                    }
                }
                .onEnded { value in
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }

                    // 只在明显的水平右滑手势时触发
                    if value.translation.width > 80 && abs(value.translation.width) > abs(value.translation.height) * 2 {
                        onSwipeRight?()
                    }
                }
        )
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            Text(recording.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDarkMode ? .white : .black)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // 标签显示 - 显示所有标签
            if !recording.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(recording.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(isDarkMode ? Color.blue.opacity(0.8) : Color.blue)
                                .frame(width: 4, height: 4)

                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.1))
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

// MARK: - 加载占位符
struct SimilarInspirationPlaceholder: View {
    let isDarkMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主要内容区域
            VStack(alignment: .leading, spacing: 12) {
                // 标题占位符
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDarkMode ? Color.white.opacity(0.12) : Color.gray.opacity(0.25))
                    .frame(height: 20)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 内容占位符
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.18))
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.18))
                        .frame(height: 14)
                        .frame(width: .infinity * 0.7)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDarkMode ? Color.white.opacity(0.08) : Color.gray.opacity(0.18))
                        .frame(height: 14)
                        .frame(width: .infinity * 0.5)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 底部信息栏占位符
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.15))
                    .frame(width: 60, height: 12)

                Spacer()

                // 标签占位符
                Capsule()
                    .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.12))
                    .frame(width: 50, height: 20)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ?
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.gray.opacity(0.08), Color.gray.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04), lineWidth: 0.5)
                )
        )
        .redacted(reason: .placeholder)
    }
}

// MARK: - 预览
struct SimilarInspirationView_Previews: PreviewProvider {
    static var previews: some View {
        SimilarInspirationView(
            currentRecording: AudioRecording(
                timestamp: Date(),
                duration: 120,
                transcription: "这是一个关于创新想法的灵感记录...",
                title: "创新产品想法",
                summary: "关于新产品的创意思考",
                tags: ["创新", "产品", "想法"],
                audioData: Data(),
                enrichedContent: nil,
                contentType: "inspiration"
            ),
            isDarkMode: true
        )
        .padding()
        .background(Color.black)
    }
}
