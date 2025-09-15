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
    
    private let cardHeight: CGFloat = 120
    
    var body: some View {
        Button(action: onTap) {
            mainCard
        }
        .buttonStyle(PlainButtonStyle())
        .frame(height: cardHeight)
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
    
    // MARK: - Helper Methods
    
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
                onDelete: { }
            )
            
            SpaceCard(
                space: sampleSpace,
                isDarkMode: true,
                onTap: { },
                onDelete: { }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}