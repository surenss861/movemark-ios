//
//  FlowLayout.swift
//  movemork
//
//  Flow layout for tag pills and wrap-to-next-line content.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, point) in result.positions.enumerated() {
            // An item narrower than the row keeps its natural size; a clamped one is placed at the row width.
            let clamped = result.clamped[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: clamped.map { ProposedViewSize($0) } ?? .unspecified
            )
        }
    }

    private func arrange(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, positions: [CGPoint], clamped: [CGSize?]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var clamped: [CGSize?] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            // A pill wider than the whole row (long or translated text at large sizes) is offered the row's
            // width so it wraps inside itself instead of running off the screen.
            if maxWidth.isFinite, size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                clamped.append(size)
            } else {
                clamped.append(nil)
            }

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (
            CGSize(width: maxWidth, height: y + rowHeight),
            positions,
            clamped
        )
    }
}
