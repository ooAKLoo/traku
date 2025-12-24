//
//  FilterTagButton.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 过滤标签按钮基础组件
struct FilterTagButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    @State private var isHovered = false

    private var textColor: Color {
        if isSelected {
            return isDarkMode ? .white : .black
        } else if isHovered {
            return isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8)
        } else {
            return isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5)
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)

                // 底部指示线
                ZStack {
                    // 背景透明线条（占位）
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 2)

                    // 实际显示的线条
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isDarkMode ? Color.white : Color.black).opacity(0.8),
                                    (isDarkMode ? Color.white : Color.black)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 24, height: 2)
                        .cornerRadius(1)
                        .scaleEffect(x: isSelected ? 1 : 0, y: 1)
                        .opacity(isSelected ? 1 : 0)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: isSelected)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 预览
struct FilterTagButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("过滤标签按钮组件")
                .font(.headline)
            
            VStack(spacing: 16) {
                // 浅色模式
                HStack(spacing: 10) {
                    FilterTagButton(
                        title: "全部",
                        count: 25,
                        isSelected: true,
                        isDarkMode: false,
                        onTap: { print("Selected All") }
                    )
                    
                    FilterTagButton(
                        title: "工作",
                        count: 8,
                        isSelected: false,
                        isDarkMode: false,
                        onTap: { print("Selected Work") }
                    )
                    
                    FilterTagButton(
                        title: "学习",
                        count: 12,
                        isSelected: false,
                        isDarkMode: false,
                        onTap: { print("Selected Study") }
                    )
                }
                .padding()
                .background(Color.appBackground)
                
                // 深色模式
                HStack(spacing: 10) {
                    FilterTagButton(
                        title: "全部",
                        count: 25,
                        isSelected: false,
                        isDarkMode: true,
                        onTap: { print("Selected All") }
                    )
                    
                    FilterTagButton(
                        title: "工作",
                        count: 8,
                        isSelected: true,
                        isDarkMode: true,
                        onTap: { print("Selected Work") }
                    )
                    
                    FilterTagButton(
                        title: "学习",
                        count: 12,
                        isSelected: false,
                        isDarkMode: true,
                        onTap: { print("Selected Study") }
                    )
                }
                .padding()
                .background(Color.black)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}