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
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // 标题
                HStack {
                    Text(space.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDarkMode ? .white : .black)
                        .lineLimit(2)
                    
                    Spacer()
                }
                
                // 描述
                if !space.description.isEmpty {
                    Text(space.description)
                        .font(.system(size: 13))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // 底部信息
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                        
                        Text(formatDate(space.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
                    }
                    
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 120)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color(hex: "1A1A1A") : Color.white)
                    .shadow(
                        color: isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
            .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }) {}
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
