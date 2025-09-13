//
//  CircularButton.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 圆形按钮基础组件
struct CircularButton: View {
    let iconName: String
    let iconColor: Color
    let backgroundColor: Color
    let size: CGFloat
    let action: () -> Void
    
    init(
        iconName: String,
        iconColor: Color = .primary,
        backgroundColor: Color = Color.white.opacity(0.9),
        size: CGFloat = 44,
        action: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.size = size
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.1), radius: 4)
                
                Image(systemName: iconName)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundColor(iconColor)
            }
        }
    }
}

// MARK: - 预览
struct CircularButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("圆形按钮组件")
                .font(.headline)
            
            HStack(spacing: 16) {
                // 播放按钮
                CircularButton(
                    iconName: "play.fill",
                    iconColor: .green,
                    action: { print("Play") }
                )
                
                // 暂停按钮
                CircularButton(
                    iconName: "pause.fill",
                    iconColor: .orange,
                    action: { print("Pause") }
                )
                
                // 停止按钮（使用自定义图标）
                Button(action: { print("Stop") }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.1), radius: 4)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            
            HStack(spacing: 16) {
                // 不同尺寸展示
                CircularButton(
                    iconName: "heart.fill",
                    iconColor: .red,
                    size: 32,
                    action: { print("Small") }
                )
                
                CircularButton(
                    iconName: "star.fill",
                    iconColor: .yellow,
                    size: 48,
                    action: { print("Medium") }
                )
                
                CircularButton(
                    iconName: "moon.fill",
                    iconColor: .blue,
                    size: 64,
                    action: { print("Large") }
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}