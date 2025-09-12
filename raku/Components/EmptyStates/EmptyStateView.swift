//
//  EmptyStateView.swift
//  raku
//
//  Created by Claude on 2025/1/12.
//

import SwiftUI

/// 通用的空状态视图组件 - 更有温度和设计感
struct EmptyStateView: View {
    let config: EmptyStateConfig
    let isDarkMode: Bool
    @State private var isAnimating = false
    @State private var iconRotation: Double = 0
    
    /// 便捷初始化方法
    init(
        icon: String,
        title: String,
        isDarkMode: Bool,
        iconSize: CGFloat = 72,
        iconWeight: Font.Weight = .ultraLight
    ) {
        self.config = EmptyStateConfig(
            icon: icon,
            title: title,
            iconSize: iconSize,
            iconWeight: iconWeight
        )
        self.isDarkMode = isDarkMode
    }
    
    /// 使用配置初始化
    init(config: EmptyStateConfig, isDarkMode: Bool) {
        self.config = config
        self.isDarkMode = isDarkMode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            
            // 装饰性圆圈背景
            ZStack {
                // 外层圆圈
                Circle()
                    .fill(iconBackgroundGradient)
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                    .opacity(0.3)
                    .scaleEffect(isAnimating ? 1.1 : 0.95)
                    .animation(
                        .easeInOut(duration: 3)
                        .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                // 内层圆圈
                Circle()
                    .fill(iconBackgroundGradient)
                    .frame(width: 100, height: 100)
                    .opacity(0.1)
                
                // 空状态图标
                Image(systemName: config.icon)
                    .font(.system(size: config.iconSize, weight: config.iconWeight))
                    .foregroundStyle(iconGradient)
                    .rotationEffect(.degrees(iconRotation))
                    .scaleEffect(isAnimating ? 1.0 : 0.9)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8),
                        value: isAnimating
                    )
            }
            .padding(.bottom, 36)
            
            // 主标题
            Text(config.title)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.85))
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 10)
                .animation(
                    .easeOut(duration: 0.6).delay(0.2),
                    value: isAnimating
                )
            
            
            
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
        .onAppear {
            withAnimation {
                isAnimating = true
            }
            // 特殊图标的微动画
            if config.shouldAnimateIcon {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    iconRotation = 360
                }
            }
        }
    }
    
    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: isDarkMode ? [
                Color(red: 0.6, green: 0.8, blue: 1.0),
                Color(red: 0.9, green: 0.7, blue: 1.0)
            ] : [
                Color(red: 0.3, green: 0.5, blue: 0.8),
                Color(red: 0.6, green: 0.4, blue: 0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var iconBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: isDarkMode ? [
                Color.blue.opacity(0.4),
                Color.purple.opacity(0.3)
            ] : [
                Color.blue.opacity(0.3),
                Color.purple.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
}

/// 空状态配置
struct EmptyStateConfig {
    let icon: String
    let title: String
    let iconSize: CGFloat
    let iconWeight: Font.Weight
    let shouldAnimateIcon: Bool
    
    init(
        icon: String,
        title: String,
        iconSize: CGFloat = 72,
        iconWeight: Font.Weight = .ultraLight,
        shouldAnimateIcon: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.iconSize = iconSize
        self.iconWeight = iconWeight
        self.shouldAnimateIcon = shouldAnimateIcon
    }
}

// MARK: - 预定义的空状态配置（优化文案）
extension EmptyStateConfig {
    /// 录音列表空状态
    static let noRecordings = EmptyStateConfig(
        icon: "waveform.circle",
        title: "声音的记忆，从这里开始"
    )
    
    /// 搜索无结果
    static let noSearchResults = EmptyStateConfig(
        icon: "sparkle.magnifyingglass",
        title: "哎呀，什么都没找到",
        shouldAnimateIcon: true
    )
    
    /// 标签为空
    static let noTags = EmptyStateConfig(
        icon: "tag.circle",
        title: "标签会在这里生长",
        iconSize: 68
    )
    
    /// 网络错误
    static let networkError = EmptyStateConfig(
        icon: "wifi.exclamationmark",
        title: "网络开小差了"
    )
    
    /// 加载失败
    static let loadingError = EmptyStateConfig(
        icon: "exclamationmark.bubble",
        title: "哦不，出了点小问题"
    )
    
    /// 收藏夹空状态
    static let noFavorites = EmptyStateConfig(
        icon: "star.circle",
        title: "还没有收藏的瞬间",
        shouldAnimateIcon: true
    )
    
    /// 今日无录音
    static let noRecordingsToday = EmptyStateConfig(
        icon: "sun.max",
        title: "今天还很安静",
        iconSize: 76
    )
    
    /// 垃圾箱空状态
    static let emptyTrash = EmptyStateConfig(
        icon: "trash.circle",
        title: "垃圾箱是空的",
        iconWeight: .thin
    )
}

// MARK: - 预览
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 录音空状态 - 浅色
            EmptyStateView(
                config: .noRecordings,
                isDarkMode: false
            )
            .previewDisplayName("No Recordings - Light")
            
            // 录音空状态 - 深色
            EmptyStateView(
                config: .noRecordings,
                isDarkMode: true
            )
            .background(Color.black)
            .previewDisplayName("No Recordings - Dark")
            
            // 搜索无结果
            EmptyStateView(
                config: .noSearchResults,
                isDarkMode: false
            )
            .previewDisplayName("No Search Results")
            
            // 网络错误
            EmptyStateView(
                config: .networkError,
                isDarkMode: true
            )
            .background(Color.black)
            .previewDisplayName("Network Error - Dark")
            
            // 今日无录音
            EmptyStateView(
                config: .noRecordingsToday,
                isDarkMode: false
            )
            .previewDisplayName("No Recordings Today")
        }
        .previewLayout(.fixed(width: 375, height: 667))
    }
}
