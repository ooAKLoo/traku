//
//  MarkdownParser.swift
//  raku
//
//  Created by 杨东举 on 2025/9/20.
//

import Foundation
import SwiftUI

class MarkdownParser {
    
    /// Converts markdown text to AttributedString with basic formatting
    /// - Parameter markdown: The markdown text to parse
    /// - Returns: Formatted AttributedString
    static func parseToAttributedString(_ markdown: String) -> AttributedString {
        return parseToAttributedString(markdown, optimizeForImage: false)
    }
    
    /// Converts markdown text to AttributedString optimized for image export
    /// - Parameter markdown: The markdown text to parse
    /// - Returns: Formatted AttributedString with better spacing for images
    static func parseToAttributedStringForImage(_ markdown: String) -> AttributedString {
        return parseToAttributedString(markdown, optimizeForImage: true)
    }
    
    /// Internal method to parse markdown with optional image optimization
    /// - Parameters:
    ///   - markdown: The markdown text to parse
    ///   - optimizeForImage: Whether to optimize spacing for image export
    /// - Returns: Formatted AttributedString
    private static func parseToAttributedString(_ markdown: String, optimizeForImage: Bool) -> AttributedString {
        var attributedString = AttributedString()
        
        let lines = markdown.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.isEmpty {
                // Empty line - add appropriate spacing
                let spacing = optimizeForImage ? "\n\n" : "\n"
                attributedString.append(AttributedString(spacing))
            } else if let headerLevel = getHeaderLevel(trimmedLine) {
                // Header (H1-H6)
                let headerText = String(trimmedLine.dropFirst(headerLevel + 1)) // +1 for the space
                var header = AttributedString(headerText)
                
                // Apply appropriate font based on header level - all headers are bold
                switch headerLevel {
                case 1:
                    header.font = .system(size: 20, weight: .bold)
                case 2:
                    header.font = .system(size: 18, weight: .bold)
                case 3:
                    header.font = .system(size: 16, weight: .bold)
                case 4:
                    header.font = .system(size: 15, weight: .bold)
                case 5:
                    header.font = .system(size: 14, weight: .bold)
                case 6:
                    header.font = .system(size: 13, weight: .bold)
                default:
                    header.font = .system(size: 16, weight: .bold)
                }
                
                attributedString.append(header)
                // Add extra spacing after headers for image optimization
                let headerSpacing = optimizeForImage ? "\n\n\n" : "\n\n"
                attributedString.append(AttributedString(headerSpacing))
            } else if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") {
                // List item
                let listText = String(trimmedLine.dropFirst(2))
                let formattedListText = parseBoldAndItalic(listText, optimizeForImage: optimizeForImage)
                var listItem = AttributedString("• ")
                listItem.append(formattedListText)
                attributedString.append(listItem)
                // Add extra spacing between list items for image optimization
                let listSpacing = optimizeForImage ? "\n\n" : "\n"
                attributedString.append(AttributedString(listSpacing))
            } else if let match = trimmedLine.range(of: #"^(\d+)\.\s"#, options: .regularExpression) {
                // Numbered list item
                let listText = String(trimmedLine[match.upperBound...])
                let formattedListText = parseBoldAndItalic(listText, optimizeForImage: optimizeForImage)
                let number = String(trimmedLine[..<match.upperBound])
                var listItem = AttributedString(number)
                listItem.append(formattedListText)
                attributedString.append(listItem)
                // Add extra spacing between list items for image optimization
                let listSpacing = optimizeForImage ? "\n\n" : "\n"
                attributedString.append(AttributedString(listSpacing))
            } else {
                // Regular paragraph
                let formattedText = parseBoldAndItalic(trimmedLine, optimizeForImage: optimizeForImage)
                attributedString.append(formattedText)
                // Add spacing after paragraphs for better readability
                let paragraphSpacing = optimizeForImage ? "\n\n" : "\n"
                attributedString.append(AttributedString(paragraphSpacing))
            }
        }
        
        return attributedString
    }
    
    /// Determines the header level (1-6) from a markdown line
    /// - Parameter line: The trimmed line to check
    /// - Returns: Header level (1-6) if it's a header, nil otherwise
    private static func getHeaderLevel(_ line: String) -> Int? {
        // Check for headers from H1 to H6
        if line.hasPrefix("# ") {
            return 1
        } else if line.hasPrefix("## ") {
            return 2
        } else if line.hasPrefix("### ") {
            return 3
        } else if line.hasPrefix("#### ") {
            return 4
        } else if line.hasPrefix("##### ") {
            return 5
        } else if line.hasPrefix("###### ") {
            return 6
        }
        return nil
    }
    
    /// Parses bold (**text**) and italic (*text*) formatting
    /// - Parameters:
    ///   - text: The text to parse
    ///   - optimizeForImage: Whether to optimize for image export
    /// - Returns: AttributedString with formatting applied
    private static func parseBoldAndItalic(_ text: String, optimizeForImage: Bool = false) -> AttributedString {
        var result = AttributedString()
        var currentPosition = text.startIndex
        
        // Find all bold text patterns
        let boldPattern = #"\*\*(.*?)\*\*"#
        let regex = try! NSRegularExpression(pattern: boldPattern, options: [])
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            // Add text before the bold part
            let beforeRange = Range(NSRange(location: text.distance(from: text.startIndex, to: currentPosition), 
                                         length: match.range.location - text.distance(from: text.startIndex, to: currentPosition)), in: text)
            if let beforeRange = beforeRange {
                let beforeText = String(text[beforeRange])
                var beforeAttributed = AttributedString(beforeText)
                beforeAttributed.font = .system(size: 16)
                result.append(beforeAttributed)
            }
            
            // Add the bold text
            if let boldRange = Range(match.range(at: 1), in: text) {
                let boldText = String(text[boldRange])
                var boldAttributed = AttributedString(boldText)
                boldAttributed.font = .system(size: 16, weight: .bold)
                result.append(boldAttributed)
            }
            
            // Update current position
            if let matchRange = Range(match.range, in: text) {
                currentPosition = matchRange.upperBound
            }
        }
        
        // Add any remaining text after the last match
        if currentPosition < text.endIndex {
            let remainingText = String(text[currentPosition...])
            var remainingAttributed = AttributedString(remainingText)
            remainingAttributed.font = .system(size: 16)
            result.append(remainingAttributed)
        }
        
        // If no matches found, return the original text with regular formatting
        if matches.isEmpty {
            var attributed = AttributedString(text)
            attributed.font = .system(size: 16)
            return attributed
        }
        
        return result
    }
}

// MARK: - String Extension for Markdown Processing
extension String {
    /// Converts markdown text to plain text for text exports
    /// - Returns: Plain text with basic formatting preserved
    func markdownToPlainText() -> String {
        var result = self
        
        // Convert headers (H1-H6) - process from most specific to least specific
        result = result.replacingOccurrences(of: #"^###### (.+)$"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^##### (.+)$"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^#### (.+)$"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^### (.+)$"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^## (.+)$"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^# (.+)$"#, with: "$1", options: .regularExpression)
        
        // Convert bold text
        result = result.replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "$1", options: .regularExpression)
        
        // Convert italic text
        result = result.replacingOccurrences(of: #"\*(.*?)\*"#, with: "$1", options: .regularExpression)
        
        // Keep list formatting
        result = result.replacingOccurrences(of: "- ", with: "• ")
        result = result.replacingOccurrences(of: "* ", with: "• ")
        
        return result
    }
}