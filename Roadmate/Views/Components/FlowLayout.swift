//
//  FlowLayout.swift
//  Roadmate
//
//  Created by Lakshya Agarwal on 1/10/26.
//


import SwiftUI

/// A wrapping "chip" layout that is safe on macOS SwiftUI.
/// Key detail: if the width proposal is nil (unspecified), we pick a conservative width
/// so we never under-report height (which causes bleeding outside the card).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // Measure subviews once
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }

        // ✅ Critical: If width is unspecified, use a conservative width:
        // the max single-item width, so we won't underestimate height.
        let maxItemWidth = sizes.map(\.width).max() ?? 0
        let maxWidth = proposal.width ?? maxItemWidth

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for size in sizes {
            // Wrap if next item would overflow
            if x > 0, x + size.width > maxWidth {
                usedWidth = max(usedWidth, x - spacing) // last row width
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        usedWidth = max(usedWidth, x > 0 ? (x - spacing) : 0)

        // If proposal.width was nil, report our measured width; otherwise respect proposal width.
        let finalWidth = proposal.width ?? usedWidth
        let finalHeight = y + rowHeight

        return CGSize(width: finalWidth, height: finalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for s in subviews {
            let size = s.sizeThatFits(.unspecified)

            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            s.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
