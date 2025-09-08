//
//  TagFilterTabBar.swift
//  raku
//
//  Created by Claude on 2025/1/7.
//

import SwiftUI

// MARK: - 标签过滤 TabBar
struct TagFilterTabBar: View {
    let allRecordings: [AudioRecording]
    @Binding var selectedTag: String?
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    // 获取所有唯一标签
    private var allTags: [String] {
        let tags = Set(allRecordings.flatMap { $0.tags })
        return Array(tags).sorted()
    }
    
    // 获取标签统计
    private func getTagCount(_ tag: String) -> Int {
        return allRecordings.filter { $0.tags.contains(tag) }.count
    }
    
    var body: some View {
        if !allTags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // "全部" 选项
                    TagFilterItem(
                        title: "全部",
                        count: allRecordings.count,
                        isSelected: selectedTag == nil,
                        isDarkMode: isDarkMode
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedTag = nil
                        }
                    }
                    
                    // 各个标签选项
                    ForEach(allTags, id: \.self) { tag in
                        TagFilterItem(
                            title: tag,
                            count: getTagCount(tag),
                            isSelected: selectedTag == tag,
                            isDarkMode: isDarkMode
                        ) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(
                (isDarkMode ? Color.black : Color.white)
            )
        }
    }
}

// MARK: - 标签过滤项
struct TagFilterItem: View {
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

// MARK: - 增强版设计（可选方案）
struct TagFilterItemEnhanced: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let isDarkMode: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(
                        isSelected
                        ? .white
                        : (isDarkMode ? Color.white.opacity(0.7) : Color(hex: "667085"))
                    )
                
                if isSelected {
                    // 选中时使用实心点分隔
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 2.5, height: 2.5)
                    
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    // 未选中时简洁显示
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(
                            isDarkMode
                            ? Color.white.opacity(0.4)
                            : Color(hex: "98A2B3")
                        )
                }
            }
            .padding(.horizontal, isSelected ? 16 : 14)
            .padding(.vertical, isSelected ? 8 : 7)
            .background(
                Group {
                    if isSelected {
                        // 选中时使用渐变背景，更有质感
                        LinearGradient(
                            colors: isDarkMode
                                ? [Color(hex: "FFFFFF"), Color(hex: "F5F5F7")]
                                : [Color(hex: "1A1A1C"), Color(hex: "2C2C2E")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        // 未选中时使用纯色
                        Color(isDarkMode
                            ? Color.white.opacity(0.06)
                            : Color(hex: "F9FAFB")
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            )
            // 选中时添加边框光晕效果
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected
                            ? (isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                            : Color.clear,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected
                    ? (isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.1))
                    : Color.clear,
                radius: isSelected ? 6 : 0,
                x: 0,
                y: isSelected ? 2 : 0
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: isSelected)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
