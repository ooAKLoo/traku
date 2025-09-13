//
//  TimeDisplay.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 时间显示基础组件
struct TimeDisplay: View {
    let time: TimeInterval
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let textColor: Color
    
    init(
        time: TimeInterval,
        fontSize: CGFloat = 18,
        fontWeight: Font.Weight = .semibold,
        textColor: Color = .black
    ) {
        self.time = time
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.textColor = textColor
    }
    
    var body: some View {
        Text(FormatHelper.formatDurationWithDecimal(time))
            .font(.system(size: fontSize, weight: fontWeight, design: .monospaced))
            .foregroundColor(textColor)
    }
}

// MARK: - 预览
struct TimeDisplay_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("时间显示组件")
                .font(.headline)
            
            VStack(spacing: 16) {
                TimeDisplay(time: 0)
                TimeDisplay(time: 65.5)
                TimeDisplay(time: 3665.8)
            }
            
            // 不同样式展示
            VStack(spacing: 12) {
                TimeDisplay(
                    time: 125.3,
                    fontSize: 14,
                    fontWeight: .regular,
                    textColor: .gray
                )
                
                TimeDisplay(
                    time: 125.3,
                    fontSize: 20,
                    fontWeight: .bold,
                    textColor: .blue
                )
                
                TimeDisplay(
                    time: 125.3,
                    fontSize: 24,
                    fontWeight: .heavy,
                    textColor: .red
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .previewLayout(.sizeThatFits)
    }
}