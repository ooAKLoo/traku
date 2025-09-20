//
//  ImageRenderer.swift
//  raku
//
//  Created by 杨东举 on 2025/9/10.
//

import UIKit
import SwiftUI

@MainActor
class ImageRenderer {
    func renderImage(content: AttributedString, title: String, isDarkMode: Bool) async -> UIImage {
        let width: CGFloat = 1080 // Social media friendly width
        let padding: CGFloat = 60
        let contentWidth = width - (padding * 2)
        
        // Convert AttributedString to NSAttributedString
        let initialNSAttributedString = NSAttributedString(content)
        
        // 🔧 修复：为丢失字体属性的文本添加默认字体
        let mutableString = NSMutableAttributedString(attributedString: initialNSAttributedString)
        let defaultFont = UIFont.systemFont(ofSize: 18) // 设置默认字体大小
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        // 检查并修复丢失的字体属性
        mutableString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            if attributes[.font] == nil {
                mutableString.addAttribute(.font, value: defaultFont, range: range)
                print("imagerender--- 修复：为位置 \(range) 添加默认字体")
            }
        }
        
        let nsAttributedString = mutableString as NSAttributedString
        
        // 🔍 调试：验证字体属性修复结果
        print("imagerender--- === 字体属性检查（修复后） ===")
        var hasAnyMissingFont = false
        nsAttributedString.enumerateAttributes(in: NSRange(location: 0, length: nsAttributedString.length), options: []) { attributes, range, _ in
            if let font = attributes[.font] as? UIFont {
                print("imagerender--- 字体信息: \(font.fontName), 大小: \(font.pointSize), 范围: \(range)")
            } else {
                print("imagerender--- ⚠️ 警告：第 \(range.location)-\(range.location + range.length) 位置仍然没有字体属性！")
                hasAnyMissingFont = true
            }
        }
        print("imagerender--- 总文本长度: \(nsAttributedString.length)")
        print("imagerender--- 字体修复状态: \(hasAnyMissingFont ? "❌ 仍有缺失" : "✅ 全部修复")")
        print("imagerender--- ===================")
        
        // Calculate the height needed for the text more accurately
        let textContentWidth = contentWidth - 60 // Account for inner padding
        
        // Use a more accurate text height calculation
        let textStorage = NSTextStorage(attributedString: nsAttributedString)
        let textContainer = NSTextContainer(size: CGSize(width: textContentWidth, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // Force layout and get accurate height
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let textBounds = layoutManager.usedRect(for: textContainer)
        
        // Calculate accurate text height with proper rounding and buffer
        let actualTextHeight = ceil(textBounds.height) // Round up to avoid fractional height issues
        
        let headerHeight: CGFloat = 80
        let footerHeight: CGFloat = 60
        let contentPadding: CGFloat = 40 // Top and bottom padding inside content area  
        let extraSpace: CGFloat = 100 // Increased buffer for safety margin
        let contentHeight = max(actualTextHeight + contentPadding * 2 + extraSpace, 200) // Ensure adequate space
        let totalHeight = headerHeight + contentHeight + footerHeight + (padding * 2)
        
        // Debug logging
        print("imagerender--- Text bounds: \(textBounds)")
        print("imagerender--- Actual text height: \(actualTextHeight)")
        print("imagerender--- Content height: \(contentHeight)")
        print("imagerender--- Total height: \(totalHeight)")
        print("imagerender--- NSAttributedString length: \(nsAttributedString.length)")
        print("imagerender--- Text content width: \(textContentWidth)")
        
        // Create the renderer with high quality settings
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0 // 3x scale for crisp text rendering
        format.opaque = true
        format.preferredRange = .standard
        
        // 🔍 调试：检查渲染器配置
        print("imagerender--- === 渲染器配置 ===")
        print("imagerender--- Format scale: \(format.scale)")
        print("imagerender--- 画布大小: \(width) x \(totalHeight)")
        print("imagerender--- 实际像素: \((width * format.scale)) x \((totalHeight * format.scale))")
        print("imagerender--- ================")
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight), format: format)
        
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: width, height: totalHeight)
            
            // Enable high-quality rendering
            context.cgContext.setAllowsAntialiasing(true)
            context.cgContext.setShouldAntialias(true)
            context.cgContext.setAllowsFontSmoothing(true)
            context.cgContext.setShouldSmoothFonts(true)
            context.cgContext.interpolationQuality = .high
            
            // Background
            let backgroundColor = isDarkMode ? UIColor.black : UIColor.white
            backgroundColor.setFill()
            context.fill(rect)
            
            // Add subtle gradient background
            if let gradient = createGradient(isDarkMode: isDarkMode, in: rect) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: totalHeight),
                    options: []
                )
            }
            
            // Draw header
            drawHeader(in: context, width: width, padding: padding, isDarkMode: isDarkMode)
            
            // Draw content
            let contentRect = CGRect(
                x: padding,
                y: headerHeight + padding,
                width: contentWidth,
                height: contentHeight
            )
            
            // Add content background
            let contentBackgroundColor = isDarkMode ? UIColor.white.withAlphaComponent(0.05) : UIColor.black.withAlphaComponent(0.03)
            contentBackgroundColor.setFill()
            let roundedRect = UIBezierPath(roundedRect: contentRect, cornerRadius: 20)
            roundedRect.fill()
            
            // Draw the text with padding - use the actual calculated text bounds without restrictions
            let textRect = CGRect(
                x: contentRect.minX + 30,
                y: contentRect.minY + 20,
                width: textContentWidth,
                height: actualTextHeight // Use actual text height, no max restrictions to avoid compression
            )
            
            // 🔍 调试：检查文本绘制区域
            print("imagerender--- === 文本绘制区域 ===")
            print("imagerender--- textRect: \(textRect)")
            print("imagerender--- 文本内容宽度: \(textContentWidth)")
            print("imagerender--- actualTextHeight: \(actualTextHeight)")
            print("imagerender--- ================")
            
            // Use high-quality text rendering - avoid compression by using draw(with:options:context:)
            context.cgContext.setAllowsFontSubpixelPositioning(true)
            context.cgContext.setAllowsFontSubpixelQuantization(true)
            nsAttributedString.draw(
                with: textRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )
            
            // Draw footer
            drawFooter(
                in: context,
                y: headerHeight + contentHeight + padding * 1.5,
                width: width,
                padding: padding,
                isDarkMode: isDarkMode
            )
        }
        
        // 🔍 调试：检查最终图片质量
        print("imagerender--- === 最终图片信息 ===")
        print("imagerender--- 图片大小: \(image.size)")
        print("imagerender--- 图片scale: \(image.scale)")
        print("imagerender--- 实际像素: \((image.size.width * image.scale)) x \((image.size.height * image.scale))")
        print("imagerender--- ================")
        
        return image
    }
    
    private func createGradient(isDarkMode: Bool, in rect: CGRect) -> CGGradient? {
        let colors: [CGColor] = isDarkMode ? [
            UIColor.black.cgColor,
            UIColor(white: 0.05, alpha: 1).cgColor,
            UIColor.black.cgColor
        ] : [
            UIColor.white.cgColor,
            UIColor(white: 0.97, alpha: 1).cgColor,
            UIColor.white.cgColor
        ]
        
        let locations: [CGFloat] = [0, 0.5, 1]
        return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)
    }
    
    private func drawHeader(in context: UIGraphicsImageRendererContext, width: CGFloat, padding: CGFloat, isDarkMode: Bool) {
        // Enable high-quality text rendering for header
        context.cgContext.setAllowsFontSubpixelPositioning(true)
        context.cgContext.setAllowsFontSubpixelQuantization(true)
        
        // App logo/name
        let logoAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: isDarkMode ? UIColor.white : UIColor.black
        ]
        "Raku".draw(at: CGPoint(x: padding, y: padding), withAttributes: logoAttributes)
        
        // Date
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: isDarkMode ? UIColor.white.withAlphaComponent(0.6) : UIColor.black.withAlphaComponent(0.6)
        ]
        let dateText = ""
        let dateSize = dateText.size(withAttributes: dateAttributes)
        dateText.draw(at: CGPoint(x: width - padding - dateSize.width, y: padding + 5), withAttributes: dateAttributes)
    }
    
    private func drawFooter(in context: UIGraphicsImageRendererContext, y: CGFloat, width: CGFloat, padding: CGFloat, isDarkMode: Bool) {
        // Enable high-quality text rendering for footer
        context.cgContext.setAllowsFontSubpixelPositioning(true)
        context.cgContext.setAllowsFontSubpixelQuantization(true)
        
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: isDarkMode ? UIColor.white.withAlphaComponent(0.4) : UIColor.black.withAlphaComponent(0.4)
        ]
        
        let footerText = "Generated by Raku App"
        let footerSize = footerText.size(withAttributes: footerAttributes)
        footerText.draw(
            at: CGPoint(x: (width - footerSize.width) / 2, y: y),
            withAttributes: footerAttributes
        )
    }
}
