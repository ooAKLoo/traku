//
//  SpaceCard.swift
//  raku
//
//  Created by Assistant on 2025/9/15.
//

import SwiftUI

// MARK: - 空间卡片组件
struct SpaceCard: View {
    let space: Space
    let isDarkMode: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDragStateChanged: (Bool) -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var showingDeleteConfirmation = false
    
    private let cardHeight: CGFloat = 120
    private let deleteThreshold: CGFloat = -100
    
    var body: some View {
        ZStack {
            // 背景删除区域
            deleteBackground
            
            // 主卡片
            mainCard
                .offset(dragOffset)
                .scaleEffect(isDragging ? 0.95 : 1.0)
                .gesture(dragGesture)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragOffset)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
        }
        .frame(height: cardHeight)
        .confirmationDialog("删除空间", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除空间「\(space.name)」吗？此操作不可撤销。")
        }
    }
    
    // MARK: - 删除背景
    private var deleteBackground: some View {
        HStack {
            Spacer()
            
            VStack {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("删除")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.trailing, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red)
        )
        .opacity(dragOffset.width < deleteThreshold ? 1 : 0)
    }
    
    // MARK: - 主卡片
    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(space.name)
                    .font(.headline)
                    .foregroundColor(isDarkMode ? .white : .black)
                    .lineLimit(1)
                
                Spacer()
                
                // 文章数量标识
                articleCountBadge
            }
            
            if !space.description.isEmpty {
                Text(space.description)
                    .font(.caption)
                    .foregroundColor(isDarkMode ? .gray : .secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack {
                Text("创建于 \(formatDate(space.createdAt))")
                    .font(.caption2)
                    .foregroundColor(isDarkMode ? .gray : .secondary)
                
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color.gray.opacity(0.2) : Color.white)
                .shadow(
                    color: isDarkMode ? .clear : .black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isDarkMode ? Color.gray.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - 文章数量标识
    private var articleCountBadge: some View {
        Text("\(getArticleCount())")
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue)
            )
    }
    
    // MARK: - 拖动手势
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                
                if !isDragging {
                    isDragging = true
                    onDragStateChanged(true)
                }
            }
            .onEnded { value in
                if dragOffset.width < deleteThreshold {
                    showingDeleteConfirmation = true
                }
                
                // 重置拖动状态
                dragOffset = .zero
                isDragging = false
                onDragStateChanged(false)
            }
    }
    
    // MARK: - Helper Methods
    
    private func getArticleCount() -> Int {
        // 从数据库获取文章数量
        let articles = DatabaseManager.shared.getArticlesForSpace(space.id)
        return articles.count
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct SpaceCard_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSpace = Space(
            name: "示例空间",
            description: "这是一个示例空间的描述信息"
        )
        
        VStack(spacing: 20) {
            SpaceCard(
                space: sampleSpace,
                isDarkMode: false,
                onTap: { },
                onDelete: { },
                onDragStateChanged: { _ in }
            )
            
            SpaceCard(
                space: sampleSpace,
                isDarkMode: true,
                onTap: { },
                onDelete: { },
                onDragStateChanged: { _ in }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}