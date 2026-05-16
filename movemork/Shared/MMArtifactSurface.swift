//
//  MMArtifactSurface.swift
//  movemork
//
//  Muted document preview on emerald — lease/report artifact tiles.
//

import SwiftUI

struct MMArtifactSurface<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MoveMarkTheme.Colors.artifactPaper.opacity(0.88))
                .overlay { ruledLines }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MoveMarkTheme.Colors.cardRaised.opacity(0.35))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
                .offset(x: 4, y: 5)

            content
                .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.55), lineWidth: 0.75)
        )
    }

    private var ruledLines: some View {
        Canvas { context, size in
            let spacing: CGFloat = 11
            var y: CGFloat = 16
            while y < size.height - 10 {
                var path = Path()
                path.move(to: CGPoint(x: 14, y: y))
                path.addLine(to: CGPoint(x: size.width - 14, y: y))
                context.stroke(
                    path,
                    with: .color(MoveMarkTheme.Colors.cardStroke.opacity(0.22)),
                    lineWidth: 0.4
                )
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
