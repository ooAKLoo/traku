//
//  TagView.swift
//  raku
//
//  Created by 杨东举 on 2025/8/26.
//

import SwiftUI

// MARK: - 标签视图
struct TagView: View {
    let text: String
    let isDarkMode: Bool
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(isDarkMode ? .white.opacity(0.5) : .black.opacity(0.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
    }
}

// MARK: - Preview
struct TagView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 10) {
                TagView(text: "SwiftUI", isDarkMode: false)
                TagView(text: "iOS开发", isDarkMode: false)
                TagView(text: "学习", isDarkMode: false)
            }
            .padding()
            .background(Color(white: 0.95))
            .previewDisplayName("Light Mode")
            
            VStack(spacing: 10) {
                TagView(text: "SwiftUI", isDarkMode: true)
                TagView(text: "iOS开发", isDarkMode: true)
                TagView(text: "学习", isDarkMode: true)
            }
            .padding()
            .background(Color.black)
            .previewDisplayName("Dark Mode")
        }
    }
}