//
//  TagClusteringSuggestionView.swift
//  raku
//
//  Created by Assistant on 2025/9/22.
//  AI标签合并建议视图 - Linear 风格设计
//

import SwiftUI

// MARK: - AI合并建议视图

struct TagClusteringSuggestionView: View {
    let clusteringResult: TagClusteringResult?
    let isDarkMode: Bool
    let onApplyMerge: (TagCluster) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部 - Linear 风格的简洁标题
            HStack(spacing: 8) {
                // 渐变图标背景
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.51, green: 0.47, blue: 1.0),
                            Color(red: 0.67, green: 0.47, blue: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 28, height: 28)
                    .cornerRadius(7)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Suggestions")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))

                    if let result = clusteringResult, !result.clusters.isEmpty {
                        Text("\(result.clusters.count) merge opportunities")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.5) : Color(red: 0.5, green: 0.5, blue: 0.55))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 内容区域
            if let result = clusteringResult {
                if result.clusters.isEmpty {
                    // 空状态
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.2))

                        Text("All tags look good")
                            .font(.system(size: 13))
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.5) : Color(red: 0.5, green: 0.5, blue: 0.55))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    // 建议列表
                    VStack(spacing: 1) {
                        ForEach(Array(result.clusters.enumerated()), id: \.offset) { index, cluster in
                            TagClusterItemView(
                                cluster: cluster,
                                isDarkMode: isDarkMode,
                                onApply: { onApplyMerge(cluster) }
                            )

                            if index < result.clusters.count - 1 {
                                Divider()
                                    .background(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.06))
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.04) : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - 标签聚类项视图

struct TagClusterItemView: View {
    let cluster: TagCluster
    let isDarkMode: Bool
    let onApply: () -> Void
    @State private var isProcessing = false
    @State private var isCompleted = false
    @State private var isHovered = false

    var body: some View {
        if !isCompleted {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    // 左侧内容
                    VStack(alignment: .leading, spacing: 6) {
                        // 标签合并展示 - Linear 风格的流式布局
                        HStack(spacing: 6) {
                            // 目标标签 (representative)
                            Text(cluster.representative)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.1, blue: 0.12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(isDarkMode ? Color(red: 0.51, green: 0.47, blue: 1.0).opacity(0.15) : Color(red: 0.51, green: 0.47, blue: 1.0).opacity(0.1))
                                )

                            // 箭头
                            Image(systemName: "arrow.left")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.3))

                            // 源标签列表
                            ForEach(cluster.members, id: \.self) { member in
                                Text(member)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(isDarkMode ? Color.white.opacity(0.7) : Color(red: 0.4, green: 0.4, blue: 0.45))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                                    )
                            }
                        }

                        // 原因说明
                        Text(cluster.reason)
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.45) : Color(red: 0.5, green: 0.5, blue: 0.55))
                            .lineSpacing(2)
                    }

                    Spacer()

                    // 右侧操作按钮
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.51, green: 0.47, blue: 1.0)))
                            .frame(width: 56, height: 28)
                    } else {
                        Button(action: {
                            applyMerge()
                        }) {
                            Text("Merge")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.51, green: 0.47, blue: 1.0),
                                                    Color(red: 0.67, green: 0.47, blue: 1.0)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .scaleEffect(isHovered ? 1.02 : 1.0)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(
                isDarkMode ? Color.clear : Color.clear
            )
            .opacity(isProcessing ? 0.6 : 1.0)
        }
    }

    private func applyMerge() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isProcessing = true
        }

        // 执行合并操作
        onApply()

        // 处理完成后淡出
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.25)) {
                isCompleted = true
            }
        }
    }
}
