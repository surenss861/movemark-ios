//
//  ProofCaseCard.swift
//  movemork
//

import SwiftUI

enum ProofCaseCardStyle {
    case standard
    case marketing
}

struct ProofCaseCard<Content: View, Footer: View>: View {
    var style: ProofCaseCardStyle = .standard
    var cornerRadius: CGFloat = MoveMarkTheme.Spacing.cornerRadius
    var header: ProofCaseHeader?
    var contentPadding: CGFloat = 0
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        ZStack(alignment: .leading) {
            if let header, header.accentRail != .none {
                ProofCaseAccentRailOverlay(rail: header.accentRail, cornerRadius: cornerRadius)
            }
            VStack(spacing: 0) {
                if let header {
                    ProofCaseMetadataRow(
                        eyebrow: header.eyebrow,
                        statusLabel: header.statusLabel,
                        statusTone: header.statusTone
                    )
                    ProofCaseDivider()
                }
                content()
                    .padding(contentPadding)
                footer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardOverlay)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: style == .marketing ? Color.black.opacity(0.2) : .clear, radius: 12, y: 5)
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(style == .standard ? MoveMarkTheme.Colors.cardRaised : MoveMarkTheme.Colors.card.opacity(0.98))
    }

    @ViewBuilder
    private var cardOverlay: some View {
        switch style {
        case .standard:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
        case .marketing:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            MoveMarkTheme.Colors.primary.opacity(0.28),
                            MoveMarkTheme.Colors.cardStroke.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

extension ProofCaseCard where Footer == EmptyView {
    init(
        style: ProofCaseCardStyle = .standard,
        cornerRadius: CGFloat = MoveMarkTheme.Spacing.cornerRadius,
        header: ProofCaseHeader? = nil,
        contentPadding: CGFloat = 0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(style: style, cornerRadius: cornerRadius, header: header, contentPadding: contentPadding, content: content) {
            EmptyView()
        }
    }
}
