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
                            onTap: {
                                selectedRecording = recording
                                isNavigating = true
                            }
                        )
                    }
                }
            }
        }
        .background(navigationLink)
        .onAppear {
            loadSimilarInspiration()
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
    let onTap: () -> Void
    
    var body: some View {
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color(hex: "EBEBE9").opacity(0.3))
        )
        .contentShape(Rectangle())
        .scaleEffect(1.0) // 为后续交互动画预留
        .onTapGesture {
            onTap()
        }
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
