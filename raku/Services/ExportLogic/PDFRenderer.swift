//
//  PDFRenderer.swift
//  raku
//
//  Created by 杨东举 on 2025/9/10.
//

import PDFKit
import UIKit
import SwiftUI
import CoreText

@MainActor
class PDFRenderer {
    func renderPDF(content: AttributedString, title: String, isDarkMode: Bool) async -> Data {
        let pageWidth: CGFloat = 612 // Letter size width
        let pageHeight: CGFloat = 792 // Letter size height
        let margin: CGFloat = 50
        let headerHeight: CGFloat = 40
        let footerHeight: CGFloat = 40
        
        let pdfMetaData = [
            kCGPDFContextCreator: "Raku App",
            kCGPDFContextTitle: title,
            kCGPDFContextAuthor: "Raku User"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            // Convert AttributedString to NSAttributedString
            let nsAttributedString = NSAttributedString(content)
            
            // Calculate available content area per page
            let contentWidth = pageWidth - (margin * 2)
            let contentHeight = pageHeight - margin - headerHeight - footerHeight - margin
            
            // Create framesetter for text layout
            let framesetter = CTFramesetterCreateWithAttributedString(nsAttributedString as CFAttributedString)
            
            var currentPage = 1
            var currentLocation = 0
            let textLength = nsAttributedString.length
            
            while currentLocation < textLength {
                context.beginPage()
                
                // Add background color if dark mode
                if isDarkMode {
                    UIColor.white.setFill()
                    context.fill(pageRect)
                }
                
                // Create path for text frame
                let textRect = CGRect(
                    x: margin,
                    y: margin + headerHeight,
                    width: contentWidth,
                    height: contentHeight
                )
                
                // Create frame for current page
                let range = CFRangeMake(currentLocation, 0)
                let path = UIBezierPath(rect: textRect)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    range,
                    path.cgPath,
                    nil
                )
                
                // Get the range that was actually laid out
                let visibleRange = CTFrameGetVisibleStringRange(frame)
                currentLocation += visibleRange.length
                
                // Draw the text content
                // UIGraphicsPDFRenderer uses UIKit coordinates, but CTFrameDraw expects flipped coordinates
                // So we need to flip just for drawing the text
                context.cgContext.saveGState()
                
                // Flip the coordinate system for Core Text
                context.cgContext.translateBy(x: 0, y: textRect.origin.y + textRect.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                
                // Adjust the drawing position
                context.cgContext.translateBy(x: 0, y: -textRect.origin.y)
                
                // Draw the text frame
                CTFrameDraw(frame, context.cgContext)
                
                context.cgContext.restoreGState()
                
                // Draw header and footer after text (so they appear on top)
                drawHeader(context: context, pageWidth: pageWidth, margin: margin, headerHeight: headerHeight)
                drawFooter(context: context, pageWidth: pageWidth, pageHeight: pageHeight,
                          margin: margin, footerHeight: footerHeight, pageNumber: currentPage)
                
                currentPage += 1
            }
        }
        
        return data
    }
    
    private func drawHeader(context: UIGraphicsPDFRendererContext, pageWidth: CGFloat,
                           margin: CGFloat, headerHeight: CGFloat) {
        // Draw white background for header area to ensure it's visible
        UIColor.white.setFill()
        let headerBackground = CGRect(x: 0, y: 0, width: pageWidth, height: margin + headerHeight)
        context.fill(headerBackground)
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ]
        let headerText = "Raku - \(Date().formatted())"
        headerText.draw(at: CGPoint(x: margin, y: margin / 2), withAttributes: headerAttributes)
        
        // Draw a separator line
        UIColor.lightGray.setStroke()
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: margin + headerHeight - 10))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: margin + headerHeight - 10))
        linePath.lineWidth = 0.5
        linePath.stroke()
    }
    
    private func drawFooter(context: UIGraphicsPDFRendererContext, pageWidth: CGFloat,
                           pageHeight: CGFloat, margin: CGFloat, footerHeight: CGFloat,
                           pageNumber: Int) {
        // Draw white background for footer area to ensure it's visible
        UIColor.white.setFill()
        let footerBackground = CGRect(x: 0, y: pageHeight - margin - footerHeight,
                                     width: pageWidth, height: margin + footerHeight)
        context.fill(footerBackground)
        
        // Draw separator line
        UIColor.lightGray.setStroke()
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: pageHeight - margin - footerHeight + 10))
        linePath.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - margin - footerHeight + 10))
        linePath.lineWidth = 0.5
        linePath.stroke()
        
        // Draw page number
        let pageNumberAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let pageNumberText = "第 \(pageNumber) 页"
        let pageNumberSize = pageNumberText.size(withAttributes: pageNumberAttributes)
        pageNumberText.draw(
            at: CGPoint(x: (pageWidth - pageNumberSize.width) / 2,
                       y: pageHeight - margin / 2 - pageNumberSize.height),
            withAttributes: pageNumberAttributes
        )
    }
}
