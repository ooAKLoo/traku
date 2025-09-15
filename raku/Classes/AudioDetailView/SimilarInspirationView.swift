//
//  SimilarInspirationView.swift
//  相似灵感展示视图 - 显示与当前灵感类似的其他条目
//

import SwiftUI

struct SimilarInspirationView: View {
    let currentRecording: AudioRecording
    let isDarkMode: Bool
    
    @State private var similarRecordings: [AudioRecording] = []
    @State private var isLoading = true
    @State private var searchError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                
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
                        .foregroundColor(.orange)
                    
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
                            isDarkMode: isDarkMode
                        )
                    }
                }
            }
        }
        .onAppear {
            loadSimilarInspiration()
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题和时间
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(formatRecordingDate(recording.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .gray)
                }
                
                Spacer()
                
                // 时长
                Text(formatDuration(recording.duration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.15))
                    )
            }
            
            // 标签
            if !recording.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(recording.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isDarkMode ? Color.orange.opacity(0.2) : Color.orange.opacity(0.15))
                                )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // 转写文本预览
            if !recording.transcription.isEmpty {
                Text(recording.transcription)
                    .font(.system(size: 13))
                    .foregroundColor(isDarkMode ? .white.opacity(0.6) : .gray)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2), lineWidth: 0.5)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // 点击跳转到对应的记录详情
            // 这里可以添加导航逻辑
            print("点击查看相似灵感: \(recording.title)")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.2))
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.15))
                        .frame(height: 12)
                        .frame(width: 80)
                }
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.15))
                    .frame(width: 40, height: 20)
            }
            
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDarkMode ? Color.orange.opacity(0.1) : Color.orange.opacity(0.1))
                        .frame(width: 40, height: 16)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.02) : Color.gray.opacity(0.05))
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