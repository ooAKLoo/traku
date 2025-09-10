//
//  AdaptiveTextView.swift
//  raku
//
//  Created by 杨东举 on 2025/9/9.
//

import SwiftUI

struct AdaptiveTextView: View {
    let text: String
    let maxLines: Int
    let font: Font
    let lineSpacing: CGFloat
    
    @State private var isExpanded = false
    @State private var isTruncated = false
    @State private var textHeight: CGFloat = 0
    
    init(text: String, maxLines: Int = 4, font: Font = .system(size: 17), lineSpacing: CGFloat = 0) {
        self.text = text
        self.maxLines = maxLines
        self.font = font
        self.lineSpacing = lineSpacing
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(font)
                .lineSpacing(lineSpacing)
                .lineLimit(isExpanded ? nil : maxLines)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    // 使用 ViewThatFits 来检测是否被截断
                    ViewThatFits(in: .vertical) {
                        // 先尝试完整文本
                        Text(text)
                            .font(font)
                            .lineSpacing(lineSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                            .hidden()
                            .onAppear {
                                isTruncated = false
                            }
                        
                        // 如果不适合，说明被截断了
                        Color.clear
                            .onAppear {
                                isTruncated = true
                            }
                    }
                )
                .fixedSize(horizontal: false, vertical: false)
            
            // 展开/收起按钮
            if isTruncated || isExpanded {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "收起" : "展开")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
        }
    }
}
