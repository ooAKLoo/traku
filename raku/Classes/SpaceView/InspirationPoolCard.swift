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
    @State private var inspirations: [InspirationData] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 导航栏
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(isDarkMode ? .white : .black)
                    }
                    
                    Spacer()
                    
                    Text("灵感资源池")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Spacer()
                    
                    // 占位符保持对称
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(isDarkMode ? Color.black : Color.white)
                
                Divider()
                    .background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                
                // 灵感列表
                if inspirations.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundColor(isDarkMode ? .white.opacity(0.3) : .black.opacity(0.3))
                        
                        Text("暂无灵感")
                            .font(.system(size: 16))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(inspirations, id: \.id) { inspiration in
                                InspirationRowView(inspiration: inspiration, isDarkMode: isDarkMode)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(isDarkMode ? Color.black : Color(UIColor.systemGray6))
            .navigationBarHidden(true)
        }
        .onAppear {
            loadInspirations()
        }
    }
    
    private func loadInspirations() {
        // 从数据库加载实际的灵感数据
        inspirations = DatabaseManager.shared.loadInspirations()
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
    let inspiration: InspirationData
    let isDarkMode: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 灵感文本
            Text(inspiration.polishedText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDarkMode ? .white : .black)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // 标签和时间
            HStack {
                // 标签
                HStack(spacing: 6) {
                    ForEach(inspiration.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 12))
                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                            )
                    }
                }
                
                Spacer()
                
                // 时间
                Text(formatDate(inspiration.createdAt))
                    .font(.system(size: 12))
                    .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDarkMode ? Color.white.opacity(0.08) : Color.white)
        )
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