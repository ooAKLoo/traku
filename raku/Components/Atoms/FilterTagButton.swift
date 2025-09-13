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
    
    // 定义更精致的颜色方案
    private var backgroundColor: Color {
        if isSelected {
            // 选中状态：深色主题色
            return isDarkMode ? Color.white : Color(red: 0.1, green: 0.1, blue: 0.12)
        } else {
            // 未选中状态：更轻的背景
            return isDarkMode ? Color.white.opacity(0.08) : Color(red: 0.96, green: 0.96, blue: 0.97)
        }
    }
    
    private var textColor: Color {
        if isSelected {
            // 选中状态：高对比度文字
            return isDarkMode ? Color.black : Color.white
        } else {
            // 未选中状态：柔和的文字颜色
            return isDarkMode ? Color.white.opacity(0.65) : Color(red: 0.4, green: 0.4, blue: 0.45)
        }
    }
    
    private var countBackgroundColor: Color {
        if isSelected {
            // 选中状态：使用纯色而非透明度，避免"脏"的感觉
            return isDarkMode
                ? Color(red: 0.92, green: 0.92, blue: 0.93)  // 浅灰色
                : Color(red: 0.25, green: 0.25, blue: 0.28)  // 深灰色
        } else {
            // 未选中状态
            return isDarkMode
                ? Color.white.opacity(0.1)
                : Color(red: 0.88, green: 0.88, blue: 0.9)
        }
    }
    
    private var countTextColor: Color {
        if isSelected {
            // 选中状态：确保清晰的对比度
            return isDarkMode
                ? Color(red: 0.2, green: 0.2, blue: 0.22)  // 深灰色文字
                : Color(red: 0.85, green: 0.85, blue: 0.87)  // 浅灰色文字
        } else {
            // 未选中状态
            return isDarkMode
                ? Color.white.opacity(0.5)
                : Color(red: 0.55, green: 0.55, blue: 0.6)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                
                // 数量标签 - 优化设计
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(countTextColor)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(countBackgroundColor)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
                    // 选中时添加细微阴影增加层次感
                    .shadow(
                        color: isSelected
                            ? Color.black.opacity(0.08)
                            : Color.clear,
                        radius: 4,
                        x: 0,
                        y: 2
                    )
            )
            // 选中时轻微放大
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSelected)
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