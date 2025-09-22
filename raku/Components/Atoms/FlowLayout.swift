//
//  FlowLayout.swift
//  raku
//
//  Created by Claude on 2025/9/22.
//

import SwiftUI

// MARK: - FlowLayout for tags
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        let totalHeight = rows.reduce(0) { result, row in
            result + row.maxHeight + (result > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrangeSubviews(proposal: proposal, subviews: subviews)
        var yOffset = bounds.minY
        
        for row in rows {
            var xOffset = bounds.minX
            for subview in row.subviews {
                subview.place(at: CGPoint(x: xOffset, y: yOffset), proposal: ProposedViewSize(width: subview.sizeThatFits(.unspecified).width, height: row.maxHeight))
                xOffset += subview.sizeThatFits(.unspecified).width + spacing
            }
            yOffset += row.maxHeight + spacing
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let containerWidth = proposal.width ?? 0
        var rows: [Row] = []
        var currentRow = Row()
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            if currentRow.width + subviewSize.width + (currentRow.subviews.isEmpty ? 0 : spacing) <= containerWidth {
                currentRow.addSubview(subview, size: subviewSize, spacing: currentRow.subviews.isEmpty ? 0 : spacing)
            } else {
                if !currentRow.subviews.isEmpty {
                    rows.append(currentRow)
                    currentRow = Row()
                }
                currentRow.addSubview(subview, size: subviewSize, spacing: 0)
            }
        }
        
        if !currentRow.subviews.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    private struct Row {
        var subviews: [LayoutSubviews.Element] = []
        var width: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        mutating func addSubview(_ subview: LayoutSubviews.Element, size: CGSize, spacing: CGFloat) {
            subviews.append(subview)
            width += size.width + spacing
            maxHeight = max(maxHeight, size.height)
        }
    }
}