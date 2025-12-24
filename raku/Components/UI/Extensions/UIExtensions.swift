//
//  UIExtensions.swift
//  raku
//
//  UI相关的扩展
//

import SwiftUI

// MARK: - 全局 UI 常量
/// 统一管理所有页面的间距、尺寸等设计规范
enum UIConstants {
    // MARK: - 水平边距（所有组件统一使用）
    /// 页面内容的标准水平边距 (20pt)
    static let horizontalPadding: CGFloat = 20

    // MARK: - 标签过滤器
    enum TagFilter {
        /// 标签之间的间距
        static let tagSpacing: CGFloat = 10
        /// 垂直内边距
        static let verticalPadding: CGFloat = 12
        /// 展开按钮渐变宽度
        static let gradientWidth: CGFloat = 16
        /// 展开按钮区域宽度
        static let expandButtonWidth: CGFloat = 20
        /// 展开按钮总占用宽度（渐变 + 按钮）
        static let expandAreaWidth: CGFloat = gradientWidth + expandButtonWidth
    }

    // MARK: - 内容列表
    enum ContentList {
        /// 卡片之间的垂直间距
        static let cardSpacing: CGFloat = 15
        /// 列表顶部间距
        static let topPadding: CGFloat = 6
        /// 列表底部间距（为悬浮按钮留空间）
        static let bottomPadding: CGFloat = 120
    }

    // MARK: - 头部导航
    enum Header {
        /// 顶部间距
        static let topPadding: CGFloat = 16
        /// 底部间距
        static let bottomPadding: CGFloat = 8
        /// 元素之间的间距
        static let elementSpacing: CGFloat = 16
    }
}

// MARK: - Color 扩展
extension Color {
    /// 使用十六进制字符串初始化颜色
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
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// 应用专用的背景颜色
//    static let appBackground = Color(hex: "F5F5F5")
    static let appBackground = Color.white
}
