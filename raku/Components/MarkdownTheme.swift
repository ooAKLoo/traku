//
//  MarkdownTheme.swift
//  raku
//
//  Created by 杨东举 on 2025/9/6.
//

import SwiftUI
import MarkdownUI

extension Theme {
    static let customCompact = Theme.docC
        .text {
            FontSize(.em(0.85))
        }
        .paragraph { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(0.85))
                }
                .markdownMargin(top: 4, bottom: 8)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.4))
                    FontWeight(.bold)
                }
                .markdownMargin(top: 24, bottom: 12)
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.2))
                    FontWeight(.semibold)
                }
                .markdownMargin(top: 18, bottom: 10)
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.1))
                    FontWeight(.medium)
                }
                .markdownMargin(top: 14, bottom: 8)
        }
        .blockquote { configuration in
                    configuration.label
                        .padding(.leading, 16)  // 添加左边距
                        .overlay(alignment: .leading) {
                            // 添加左边的竖线
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 3)
                        }
                        .markdownTextStyle {
                            // 保持引用文字的样式
                            FontStyle(.italic)
                            ForegroundColor(.secondary)
                        }
                        .relativeLineSpacing(.em(0.25))
                        .markdownMargin(top: 8, bottom: 12)
                }
}