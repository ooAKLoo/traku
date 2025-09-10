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
    
    private var truncatedTextWithChevron: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(text)
                .font(font)
                .lineSpacing(lineSpacing)
                .lineLimit(maxLines)
                .truncationMode(.tail)
        }
    }
    
    private var expandedText: some View {
        Text(text)
            .font(font)
            .lineSpacing(lineSpacing)
            .lineLimit(isExpanded ? nil : maxLines)
    }
    
    init(text: String, maxLines: Int = 4, font: Font = .system(size: 17), lineSpacing: CGFloat = 0) {
        self.text = text
        self.maxLines = maxLines
        self.font = font
        self.lineSpacing = lineSpacing
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if isTruncated && !isExpanded {
                    truncatedTextWithChevron
                } else {
                    expandedText
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                // 检测截断
                ViewThatFits(in: .vertical) {
                    Text(text)
                        .font(font)
                        .lineSpacing(lineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onAppear { isTruncated = false }
                    
                    Color.clear
                        .onAppear { isTruncated = true }
                }
            )
        }
    }
}
