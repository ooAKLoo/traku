//
//  SimilarInspirationView.swift
//  相似灵感展示视图 - 显示与当前灵感类似的其他条目
//

import SwiftUI
import Combine

struct SimilarInspirationView: View {
    let currentRecording: AudioRecording
    let isDarkMode: Bool
    let audioManager: AudioManagerAdapter
    let onRecordingUpdated: ((AudioRecording) -> Void)?
    
    @State private var similarRecordings: [AudioRecording] = []
    @State private var isLoading = true
    @State private var searchError: String?
    @State private var selectedRecording: AudioRecording?
    @State private var isNavigating = false
    @State private var isSelectionMode = false
    @State private var selectedInspirations: Set<UUID> = []
    @State private var showingBatchSpaceSelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Text("相似灵感")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                } else if !similarRecordings.isEmpty {
                    // 批量操作按钮
                    Button(action: {
                        toggleSelectionMode()
                    }) {
                        Text(isSelectionMode ? "取消" : "批量")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : .black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            
            if isLoading {
                // 加载状态
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        SimilarInspirationPlaceholder(isDarkMode: isDarkMode)
                    }
                }
                
            } else if let error = searchError {
                // 错误状态
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.blue)
                    
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                }
                .padding(.vertical, 20)
                
            } else if similarRecordings.isEmpty {
                // 空状态
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .gray.opacity(0.5))
                    
                    Text("暂无相似的灵感记录")
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
                                    selectedRecording = recording
                                    isNavigating = true
                                }
                            },
                            onSelectionToggle: {
                                toggleSelection(for: recording.id)
                            }
                        )
                    }
                }
            }
        }
        .background(navigationLink)
        .sheet(isPresented: $showingBatchSpaceSelection) {
            SimilarInspirationBatchView(
                recordings: selectedInspirations.compactMap { id in
                    similarRecordings.first { $0.id == id }
                },
                isDarkMode: isDarkMode,
                isPresented: $showingBatchSpaceSelection,
                onCompleted: {
                    exitSelectionMode()
                }
            )
        }
        .onAppear {
            loadSimilarInspiration()
        }
        .globalBatchSelectionToolbar(
            isPresented: $isSelectionMode,
            selectedCount: selectedInspirations.count,
            totalCount: similarRecordings.count,
            actionTitle: "添加到空间",
            actionIcon: "plus.circle.fill",
            onSelectAll: {
                selectedInspirations = Set(similarRecordings.map { $0.id })
            },
            onDeselectAll: {
                selectedInspirations.removeAll()
            },
            onAction: {
                showingBatchSpaceSelection = true
            }
        )
    }
    
    
    // MARK: - 批量操作方法
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isSelectionMode.toggle()
            if !isSelectionMode {
                selectedInspirations.removeAll()
            }
        }
    }
    
    private func exitSelectionMode() {
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
    
    // MARK: - Navigation Link
    private var navigationLink: some View {
        Group {
            if let recording = selectedRecording {
                NavigationLink(
                    destination: RecordingDetailView(
                        recording: recording,
                        audioManager: audioManager,
                        onRecordingUpdated: onRecordingUpdated
                    )
                    .navigationBarHidden(true),
                    isActive: $isNavigating
                ) {
                    EmptyView()
                }
                .hidden()
            } else {
                EmptyView()
            }
        }
    }
    
    private func loadSimilarInspiration() {
        // 获取当前记录的向量
        guard let currentEmbedding = DatabaseManager.shared.getEmbeddingVector(id: currentRecording.id) else {
            print("❌ 当前记录没有向量数据，无法进行相似度计算")
            searchError = "当前记录缺少向量数据"
            isLoading = false
            return
        }
        
        print("🔍 开始基于向量聚类搜索与'\(currentRecording.title)'相似的灵感记录...")
        let currentPreview = currentEmbedding.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", ")
        print("vectorprocess--- 📊 当前记录向量前5值: [\(currentPreview)]")
        
        DispatchQueue.global(qos: .userInitiated).async { [currentRecording] in
            // 从数据库获取所有录音记录
            let allRecordings = DatabaseManager.shared.loadRecordings()
            
            // 过滤出灵感类型且有向量数据的记录（排除当前记录）
            let inspirationRecordings = allRecordings.filter { recording in
                recording.id != currentRecording.id && 
                recording.contentType == "inspiration" &&
                DatabaseManager.shared.getEmbeddingVector(id: recording.id) != nil
            }
            
            print("📊 找到 \(inspirationRecordings.count) 个候选灵感记录进行相似度计算")
            
            var similarityResults: [(recording: AudioRecording, similarity: Float)] = []
            let cosineSimilarityCalculator = CosineSimilarityCalculator()
            
            // 计算与每个候选记录的相似度
            for recording in inspirationRecordings {
                guard let embedding = DatabaseManager.shared.getEmbeddingVector(id: recording.id) else {
                    continue
                }
                
                let similarity = cosineSimilarityCalculator.calculate(
                    vector1: currentEmbedding,
                    vector2: embedding
                )
                
                let embeddingPreview = embedding.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", ")
                print("vectorprocess--- 📝 \(recording.title) 相似度: \(String(format: "%.4f", similarity)), 向量前5值: [\(embeddingPreview)]")
                
                similarityResults.append((recording: recording, similarity: similarity))
            }
            
            // 按相似度降序排序，取前3个
            let topSimilar = similarityResults
                .sorted { $0.similarity > $1.similarity }
                .prefix(3)
                .map { $0.recording }
            
            print("🏆 相似度排序结果:")
            for (index, result) in similarityResults.sorted(by: { $0.similarity > $1.similarity }).prefix(3).enumerated() {
                print("   \(index + 1). \(result.recording.title) - 相似度: \(String(format: "%.4f", result.similarity))")
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.similarRecordings = Array(topSimilar)
                
                if self.similarRecordings.isEmpty {
                    print("ℹ️ 未找到足够相似的灵感记录")
                } else {
                    print("✅ 找到 \(self.similarRecordings.count) 个相似的灵感记录")
                }
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
    
    @State private var showingSpaceSelection = false
    
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
            
            // 添加到空间按钮（单条模式下显示）
            if !isSelectionMode {
                Button(action: {
                    showingSpaceSelection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isDarkMode ? .blue.opacity(0.8) : .blue)
                        .background(
                            Circle()
                                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white)
                                .frame(width: 28, height: 28)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 18)
                .padding(.vertical, 16)
            }
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
        .sheet(isPresented: $showingSpaceSelection) {
            SpaceSelectionView(
                recording: recording,
                isDarkMode: isDarkMode,
                isPresented: $showingSpaceSelection
            )
        }
        .onTapGesture {
            onTap()
        }
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
    
    private func formatRecordingDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: date))"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
            return formatter.string(from: date)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
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

// MARK: - FlowLayout for tags
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        let totalHeight = rows.reduce(0) { result, row in
            result + row.maxHeight + (result > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        var yOffset = bounds.minY
        
        for row in rows {
            var xOffset = bounds.minX
            for subview in row.subviews {
                subview.place(at: CGPoint(x: xOffset, y: yOffset), proposal: ProposedViewSize(width: subview.sizeThatFits(.unspecified).width, height: row.maxHeight))
                xOffset += subview.sizeThatFits(.unspecified).width + spacing
            }
            yOffset += row.maxHeight + spacing
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let containerWidth = proposal.width ?? 0
        var rows: [Row] = []
        var currentRow = Row()
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentRow.width + subviewSize.width + (currentRow.subviews.isEmpty ? 0 : spacing) <= containerWidth {
                currentRow.addSubview(subview, size: subviewSize, spacing: currentRow.subviews.isEmpty ? 0 : spacing)
            } else {
                if !currentRow.subviews.isEmpty {
                    rows.append(currentRow)
                    currentRow = Row()
                }
                currentRow.addSubview(subview, size: subviewSize, spacing: 0)
            }
        }
        
        if !currentRow.subviews.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private struct Row {
        var subviews: [LayoutSubviews.Element] = []
        var width: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        mutating func addSubview(_ subview: LayoutSubviews.Element, size: CGSize, spacing: CGFloat) {
            subviews.append(subview)
            width += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}

// MARK: - 相似灵感批量选择视图
struct SimilarInspirationBatchView: View {
    let recordings: [AudioRecording]
    let isDarkMode: Bool
    @Binding var isPresented: Bool
    let onCompleted: () -> Void
    
    @State private var spaces: [Space] = []
    @State private var selectedSpace: Space?
    @State private var categories: [Category] = []
    @State private var selectedCategory: Category?
    @State private var isLoading = false
    @State private var showingSuccessMessage = false
    @State private var successCount = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 批量预览
                batchPreview
                
                Divider()
                    .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                
                // 空间和类别选择
                selectionContent
            }
            .background(isDarkMode ? Color.black : Color.white)
            .navigationTitle("批量添加相似灵感")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        batchAddToSpace()
                    }
                    .disabled(selectedSpace == nil || isLoading || recordings.isEmpty)
                    .foregroundColor(canAdd ? (isDarkMode ? .blue.opacity(0.9) : .blue) : (isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3)))
                }
            }
        }
        .onAppear {
            loadSpaces()
        }
        .alert("批量添加完成", isPresented: $showingSuccessMessage) {
            Button("确定") {
                onCompleted()
                isPresented = false
            }
        } message: {
            Text("成功添加 \(successCount) 条相似灵感到空间")
        }
    }
    
    // MARK: - 批量预览
    private var batchPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .yellow : .orange)
                
                Text("即将批量添加 \(recordings.count) 条相似灵感")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                
                Spacer()
            }
            
            // 显示前几条相似灵感预览
            VStack(alignment: .leading, spacing: 8) {
                ForEach(recordings.prefix(2), id: \.id) { recording in
                    HStack {
                        Circle()
                            .fill(isDarkMode ? Color.blue.opacity(0.6) : Color.blue)
                            .frame(width: 6, height: 6)
                        
                        Text(recording.title)
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                
                if recordings.count > 2 {
                    HStack {
                        Circle()
                            .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))
                            .frame(width: 6, height: 6)
                        
                        Text("还有 \(recordings.count - 2) 条...")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    }
                }
            }
        }
        .padding(20)
    }
    
    // MARK: - 选择内容
    private var selectionContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 空间选择
                spaceSelectionSection
                
                // 类别选择
                if selectedSpace != nil {
                    categorySelectionSection
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - 空间选择区域
    private var spaceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择空间")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
            }
            
            if spaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                    
                    Text("暂无空间")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    
                    Text("请先创建一个空间")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(spaces) { space in
                        SpaceSelectionCard(
                            space: space,
                            isSelected: selectedSpace?.id == space.id,
                            isDarkMode: isDarkMode
                        ) {
                            selectedSpace = space
                            loadCategories(for: space)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 类别选择区域
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("选择类别")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Text("（可选）")
                    .font(.system(size: 14))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                
                Spacer()
            }
            
            if categories.isEmpty {
                VStack(spacing: 8) {
                    Text("该空间暂无类别")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                    
                    Text("灵感将被添加为未分类")
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.4) : .black.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // 未分类选项
                CategorySelectionCard(
                    title: "未分类",
                    isSelected: selectedCategory == nil,
                    isDarkMode: isDarkMode
                ) {
                    selectedCategory = nil
                }
                
                // 类别列表
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(categories) { category in
                        CategorySelectionCard(
                            title: category.name,
                            isSelected: selectedCategory?.id == category.id,
                            isDarkMode: isDarkMode
                        ) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 计算属性
    private var canAdd: Bool {
        selectedSpace != nil && !isLoading && !recordings.isEmpty
    }
    
    // MARK: - 数据加载方法
    private func loadSpaces() {
        spaces = DatabaseManager.shared.getAllSpaces()
    }
    
    private func loadCategories(for space: Space) {
        categories = DatabaseManager.shared.getCategories(for: space.id)
        selectedCategory = nil
    }
    
    // MARK: - 批量添加到空间
    private func batchAddToSpace() {
        guard let space = selectedSpace else { return }
        
        isLoading = true
        successCount = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            for recording in recordings {
                let success = DatabaseManager.shared.addRecordingToSpace(
                    recordingId: recording.id,
                    spaceId: space.id,
                    categoryId: selectedCategory?.id
                )
                
                if success {
                    successCount += 1
                }
            }
            
            DispatchQueue.main.async {
                isLoading = false
                showingSuccessMessage = true
            }
        }
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
            isDarkMode: true,
            audioManager: AudioManagerAdapter(),
            onRecordingUpdated: nil
        )
        .padding()
        .background(Color.black)
    }
}
