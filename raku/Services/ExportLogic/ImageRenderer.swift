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
        let nsAttributedString = NSAttributedString(content)
        
        // Calculate the height needed for the text
        let textBounds = nsAttributedString.boundingRect(
            with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        let headerHeight: CGFloat = 80
        let footerHeight: CGFloat = 60
        let contentHeight = textBounds.height + 40 // Extra padding for content
        let totalHeight = headerHeight + contentHeight + footerHeight + (padding * 2)
        
        // Create the renderer
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight))
        
        let image = renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: width, height: totalHeight)
            
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
            
            // Draw the text with padding
            let textRect = CGRect(
                x: contentRect.minX + 30,
                y: contentRect.minY + 20,
                width: contentRect.width - 60,
                height: contentRect.height - 40
            )
            nsAttributedString.draw(in: textRect)
            
            // Draw footer
            drawFooter(
                in: context,
                y: headerHeight + contentHeight + padding * 1.5,
                width: width,
                padding: padding,
                isDarkMode: isDarkMode
            )
        }
        
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