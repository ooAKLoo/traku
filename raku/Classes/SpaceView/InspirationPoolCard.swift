//
//  InspirationPoolCard.swift
//  raku
//
//  Created by Claude on 2025/1/15.
//

import SwiftUI

// MARK: - 灵感资源池卡片
struct InspirationPoolCard: View {
    let isDarkMode: Bool
    let onTap: () -> Void
    
    @State private var inspirationCount: Int = 0
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // 图标
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isDarkMode ? .yellow : .orange)
                
                // 标题
                VStack(alignment: .leading, spacing: 4) {
                    Text("灵感资源池")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text("共 \(inspirationCount) 条灵感")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                }
                
                Spacer()
                
                // 箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    isDarkMode ? Color.yellow.opacity(0.3) : Color.orange.opacity(0.3),
                                    isDarkMode ? Color.orange.opacity(0.3) : Color.yellow.opacity(0.3)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: (isDarkMode ? Color.white : Color.black).opacity(0.05), radius: 8, x: 0, y: 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadInspirationCount()
        }
    }
    
    // 从数据库加载灵感数量
    private func loadInspirationCount() {
        // 从数据库查询实际的灵感数量
        inspirationCount = DatabaseManager.shared.getInspirationCount()
    }
}

// MARK: - 灵感列表视图
struct InspirationListView: View {
    let isDarkMode: Bool
    @Environment(\.presentationMode) var presentationMode
    @State private var inspirations: [AudioRecording] = []
    @State private var stats: (used: Int, unused: Int) = (0, 0)
    
    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部拖拽指示器
                dragIndicator
                
                // 标题区域
                headerSection
                
                // 内容区域
                contentSection
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(isDarkMode ? Color.black : Color.white)
        .onAppear {
            loadInspirations()
        }
    }
    
    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                isDarkMode ? Color.black : Color.white,
                isDarkMode ? Color.gray.opacity(0.1) : Color.gray.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - 拖拽指示器
    private var dragIndicator: some View {
        VStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.2))
                .frame(width: 36, height: 5)
                .shadow(color: isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), radius: 1, y: 1)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
    
    // MARK: - 标题区域
    private var headerSection: some View {
        VStack(spacing: 24) {
            // 主标题
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(isDarkMode ? .yellow : .orange)
                        .scaleEffect(1.1)
                    
                    Text("灵感资源池")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .tracking(-0.5)
                }
                
                Text("收集与整理你的思维火花")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(isDarkMode ? Color.white.opacity(0.6) : Color.black.opacity(0.5))
            }
            
            // 统计信息
            HStack(spacing: 20) {
                StatCard(
                    title: "已使用",
                    value: "\(stats.used)",
                    icon: "checkmark.circle.fill",
                    color: isDarkMode ? .green : .green,
                    isDarkMode: isDarkMode
                )
                
                StatCard(
                    title: "未使用",
                    value: "\(stats.unused)",
                    icon: "circle.fill",
                    color: isDarkMode ? .orange : .orange,
                    isDarkMode: isDarkMode
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - 内容区域
    private var contentSection: some View {
        Group {
            if inspirations.isEmpty {
                emptyStateView
            } else {
                inspirationListContent
            }
        }
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.08))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                }
                
                VStack(spacing: 8) {
                    Text("暂无灵感记录")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                    
                    Text("开始录制你的第一个想法吧")
                        .font(.system(size: 14))
                        .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 灵感列表内容
    private var inspirationListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(inspirations, id: \.id) { inspiration in
                    InspirationRowView(inspiration: inspiration, isDarkMode: isDarkMode)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        }
        .animation(.easeInOut(duration: 0.3), value: inspirations.count)
    }
    
    private func loadInspirations() {
        // 从数据库加载实际的灵感数据
        inspirations = DatabaseManager.shared.getInspirationRecordings()
        // 加载优化的统计信息
        stats = DatabaseManager.shared.getInspirationUsageStats()
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isDarkMode: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
                
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isDarkMode ? .white : .black)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.06) : Color.gray.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: color.opacity(isDarkMode ? 0.1 : 0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 灵感项数据模型
struct InspirationItem: Identifiable {
    let id: String
    let originalText: String
    let polishedText: String
    let tags: [String]
    let createdAt: Date
    
    static let mockData = [
        InspirationItem(
            id: UUID().uuidString,
            originalText: "找合作伙伴不等于找朋友",
            polishedText: "找合作伙伴不等于找朋友",
            tags: ["商业", "合作"],
            createdAt: Date()
        ),
        InspirationItem(
            id: UUID().uuidString,
            originalText: "人生得意须尽欢，莫使金樽空对月",
            polishedText: "人生得意须尽欢，莫使金樽空对月",
            tags: ["诗词", "人生"],
            createdAt: Date().addingTimeInterval(-3600)
        ),
        InspirationItem(
            id: UUID().uuidString,
            originalText: "大道至简",
            polishedText: "大道至简",
            tags: ["哲学", "智慧"],
            createdAt: Date().addingTimeInterval(-7200)
        )
    ]
}

// MARK: - 灵感行视图
struct InspirationRowView: View {
    let inspiration: AudioRecording
    let isDarkMode: Bool
    
    var body: some View {
        contentView
    }
    
    // MARK: - 主内容
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspirationText
            tagsAndTime
        }
        .padding(16)
        .background(cardBackground)
    }
    
    // MARK: - 灵感文本
    private var inspirationText: some View {
        Text(inspiration.polishedText)
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isDarkMode ? .white : .black)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
    }
    
    // MARK: - 标签和时间
    private var tagsAndTime: some View {
        HStack {
            tagsView
            Spacer()
            timeView
        }
    }
    
    // MARK: - 标签视图
    private var tagsView: some View {
        HStack(spacing: 6) {
            ForEach(inspiration.tags, id: \.self) { tag in
                tagItem(tag)
            }
        }
    }
    
    // MARK: - 单个标签
    private func tagItem(_ tag: String) -> some View {
        Text(tag)
            .font(.system(size: 12))
            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tagItemBackground)
    }
    
    // MARK: - 标签背景
    private var tagItemBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
    }
    
    // MARK: - 时间视图
    private var timeView: some View {
        Text(formatDate(inspiration.timestamp))
            .font(.system(size: 12))
            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
    }
    
    // MARK: - 卡片背景
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview
struct InspirationPoolCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 浅色模式
            InspirationPoolCard(isDarkMode: false) {
                print("Tapped inspiration pool")
            }
            .padding(20)
            .background(Color.gray.opacity(0.1))
            .previewDisplayName("Light Mode")
            
            // 深色模式
            InspirationPoolCard(isDarkMode: true) {
                print("Tapped inspiration pool")
            }
            .padding(20)
            .background(Color.black)
            .previewDisplayName("Dark Mode")
            
            // 列表视图
            InspirationListView(isDarkMode: true)
                .previewDisplayName("Inspiration List")
        }
    }
}