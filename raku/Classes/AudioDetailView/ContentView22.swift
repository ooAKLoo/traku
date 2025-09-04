//
//  ContentView.swift
//  raku
//
//  Created by 杨东举 on 2025/9/3.
//

import MarkdownUI
import SwiftUI

struct ContentView22: View {
    var body: some View {
        Markdown("""
            ## Try MarkdownUI
            **MarkdownUI** is a native
            Markdown renderer for
            SwiftUI compatible with
            the [GitHub Flavored Markdown
            Spec](https://github.github.com/gfm/).

            1. item one
            2. item two
               - sublist
               - sublist
            """
        )
        .padding() // 增加内边距避免内容贴边
    }
}

// MARK: - 预览
struct ContentView22_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iPhone 预览（浅色模式）
            ContentView22()
                .previewDevice("iPhone 15 Pro")
                .previewDisplayName("iPhone (Light)")
            
            // iPhone 预览（深色模式）
            ContentView22()
                .previewDevice("iPhone 15 Pro")
                .preferredColorScheme(.dark)
                .previewDisplayName("iPhone (Dark)")
            
            // iPad 预览（浅色模式）
            ContentView22()
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
                .previewDisplayName("iPad (Light)")
            
            // iPad 预览（深色模式）
            ContentView22()
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
                .preferredColorScheme(.dark)
                .previewDisplayName("iPad (Dark)")
        }
    }
}
