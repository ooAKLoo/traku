//
//  StatusIndicator.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 状态指示器基础组件
struct StatusIndicator: View {
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    let size: CGFloat
    
    init(
        isActive: Bool,
        activeColor: Color = .red,
        inactiveColor: Color = Color.black.opacity(0.5),
        size: CGFloat = 8
    ) {
        self.isActive = isActive
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(isActive ? activeColor : inactiveColor)
            .frame(width: size, height: size)
            .scaleEffect(isActive ? 1.3 : 1.0)
            .opacity(isActive ? 1.0 : 0.7)
            .animation(
                isActive ?
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true) :
                    .easeInOut(duration: 0.3),
                value: isActive
            )
    }
}

// MARK: - 预览
struct StatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            Text("状态指示器组件")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    StatusIndicator(isActive: true)
                    Text("活跃状态")
                        .font(.caption)
                }
                
                VStack(spacing: 8) {
                    StatusIndicator(isActive: false)
                    Text("非活跃状态")
                        .font(.caption)
                }
            }
            
            // 不同颜色展示
            HStack(spacing: 20) {
                StatusIndicator(
                    isActive: true,
                    activeColor: .green,
                    size: 10
                )
                
                StatusIndicator(
                    isActive: true,
                    activeColor: .blue,
                    size: 12
                )
                
                StatusIndicator(
                    isActive: true,
                    activeColor: .orange,
                    size: 14
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}