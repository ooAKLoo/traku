//
//  TagClusteringSuggestionView.swift
//  raku
//
//  Created by Assistant on 2025/9/22.
//  AI标签合并建议视图
//

import SwiftUI

// MARK: - AI合并建议视图

struct TagClusteringSuggestionView: View {
    let clusteringResult: TagClusteringResult?
    let isDarkMode: Bool
    let onApplyMerge: (TagCluster) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20))
                    .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    .frame(width: 30)
                
                Text("AI合并建议")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white : .black)
                
                Spacer()
            }
            
            if let result = clusteringResult {
                if result.clusters.isEmpty {
                    Text("未发现可合并的标签组")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
                        .padding(.horizontal)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(result.clusters.enumerated()), id: \.offset) { index, cluster in
                                TagClusterItemView(
                                    cluster: cluster,
                                    index: index + 1,
                                    isDarkMode: isDarkMode,
                                    onApply: { onApplyMerge(cluster) }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.05) : Color.white)
        )
    }
}

// MARK: - 标签聚类项视图

struct TagClusterItemView: View {
    let cluster: TagCluster
    let index: Int
    let isDarkMode: Bool
    let onApply: () -> Void
    @State private var isProcessing = false
    @State private var isCompleted = false
    
    var body: some View {
        if !isCompleted {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(index). \(cluster.representative) ← \(cluster.members.joined(separator: ", "))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Spacer()
                    
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Button("应用") {
                            applyMerge()
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    }
                }
                
                Text(cluster.reason)
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDarkMode ? Color.white.opacity(0.03) : Color.white.opacity(0.7))
            )
            .opacity(isProcessing ? 0.7 : 1.0)
        }
    }
    
    private func applyMerge() {
        isProcessing = true
        
        // 执行合并操作
        onApply()
        
        // 模拟处理延迟后完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                isCompleted = true
            }
        }
    }
}
