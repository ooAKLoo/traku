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
            // 增加基础字体大小，提升可读性
            FontSize(.em(0.95))
        }
        .paragraph { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(0.95))
                }
                // 增加段落间距，提升呼吸感
                .markdownMargin(top: .em(0.75), bottom: .em(1.25))
                // 增加行高，提升可读性
                .relativeLineSpacing(.em(0.4))  // 增加行间距
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.6))  // 增大标题尺寸
                    FontWeight(.bold)
                }
                // 增加顶部和底部间距
                .markdownMargin(top: .em(2), bottom: .em(1.25))
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.35))
                    FontWeight(.semibold)
                }
                .markdownMargin(top: .em(1.75), bottom: .em(1))
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.15))
                    FontWeight(.medium)
                }
                .markdownMargin(top: .em(1.25), bottom: .em(0.75))
        }
        .strong {
            FontWeight(.bold)  // 使用semibold而不是bold，更优雅
            FontSize(.em(1.02))
        }
        .emphasis {
            FontStyle(.italic)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(Color.gray.opacity(0.1))
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .padding(20)  // 增加内边距
                    .relativeLineSpacing(.em(0.3))
            }
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
            .markdownMargin(top: .em(1), bottom: .em(1.5))
        }
        .blockquote { configuration in
            configuration.label
                .padding(.leading, 20)  // 增加左边距
                .padding(.vertical, 12)  // 增加上下内边距
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4)
                        .cornerRadius(2)
                }
                .markdownTextStyle {
                    FontStyle(.italic)
                    ForegroundColor(.secondary)
                }
                .relativeLineSpacing(.em(0.35))
                .markdownMargin(top: .em(1), bottom: .em(1.25))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.4))  // 增加列表项间距
                .relativeLineSpacing(.em(0.35))
        }
        .table { configuration in
            configuration.label
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.gray.opacity(0.05), Color.clear)
                )
                .markdownTableBorderStyle(.init(color: .gray.opacity(0.2)))
                .markdownMargin(top: .em(1), bottom: .em(1.5))
        }
        // 移除或修正 thematicBreak
        .thematicBreak {
            Divider()
                .overlay(Color.gray.opacity(0.3))
                .markdownMargin(top: .em(2), bottom: .em(2))
        }
}

// 创建一个更高级的主题变体 - 适合阅读长文
extension Theme {
    static let premium = Theme()
        .text {
            FontSize(.em(1.05))  // 稍大的基础字体
        }
        .paragraph { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.05))
                }
                .markdownMargin(top: .em(1), bottom: .em(1.5))
                .relativeLineSpacing(.em(0.5))  // 更宽松的行距
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.8))
                    FontWeight(.bold)
                }
                .markdownMargin(top: .em(2.5), bottom: .em(1.5))
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.5))
                    FontWeight(.semibold)
                }
                .markdownMargin(top: .em(2), bottom: .em(1.2))
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.25))
                    FontWeight(.medium)
                }
                .markdownMargin(top: .em(1.5), bottom: .em(1))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.5))
                .relativeLineSpacing(.em(0.4))
        }
        .blockquote { configuration in
            configuration.label
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.05))
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 4)
                        .padding(.leading, 4)
                }
                .markdownTextStyle {
                    FontStyle(.italic)
                    ForegroundColor(.secondary)
                }
                .relativeLineSpacing(.em(0.4))
                .markdownMargin(top: .em(1.25), bottom: .em(1.5))
        }
        .thematicBreak {
            Divider()
                .overlay(Color.gray.opacity(0.3))
                .markdownMargin(top: .em(2), bottom: .em(2))
        }
}

// 为中文内容创建专门的主题
extension Theme {
    static let chinese = Theme()
        .text {
            FontSize(.em(1.05))
        }
        .paragraph { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.05))
                }
                // 中文需要更大的段落间距
                .markdownMargin(top: .em(1.2), bottom: .em(1.8))
                // 中文需要更大的行间距
                .relativeLineSpacing(.em(0.6))
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.75))
                    FontWeight(.bold)
                }
                .markdownMargin(top: .em(2.5), bottom: .em(1.5))
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.45))
                    FontWeight(.semibold)
                }
                .markdownMargin(top: .em(2), bottom: .em(1.2))
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(.em(1.2))
                    FontWeight(.medium)
                }
                .markdownMargin(top: .em(1.5), bottom: .em(1))
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: .em(0.6))
                .relativeLineSpacing(.em(0.5))
        }
        .strong {
            FontWeight(.semibold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.9))
            BackgroundColor(Color.gray.opacity(0.1))
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .padding(24)
                    .relativeLineSpacing(.em(0.35))
            }
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
            .markdownMargin(top: .em(1.2), bottom: .em(1.8))
        }
        .blockquote { configuration in
            configuration.label
                .padding(.leading, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.06))
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: 4)
                        .padding(.leading, 4)
                }
                .markdownTextStyle {
                    FontStyle(.italic)
                    ForegroundColor(.secondary)
                }
                .relativeLineSpacing(.em(0.5))
                .markdownMargin(top: .em(1.5), bottom: .em(1.8))
        }
}
