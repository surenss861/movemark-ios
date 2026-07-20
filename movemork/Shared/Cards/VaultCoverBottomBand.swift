//
//  VaultCoverBottomBand.swift
//  movemork
//
//  Property summary band — light panel on cover cards.
//

import SwiftUI

struct VaultCoverBottomBand: View {
    let title: String
    let city: String
    let statusLine: String
    var workflowHeadline: String? = nil
    var proofMetricsLine: String? = nil
    let nextAction: String?
    var ctaTitle: String? = nil
    let isPressed: Bool
    var isEmphasized: Bool = false
    var namespace: Namespace.ID? = nil
    var vaultId: UUID? = nil

    private var fallbackPrimaryLine: String {
        if let next = nextAction, !next.isEmpty { return next }
        return statusLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isEmphasized ? 7 : 4) {
            if isEmphasized {
                Capsule()
                    .fill(MoveMarkTheme.Colors.primary)
                    .frame(width: 30, height: 2)
                    .padding(.bottom, 1)
            }

            titleLabel

            if !city.isEmpty {
                Text(city)
                    .font(MoveMarkTheme.Typography.tiny)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            if let headline = workflowHeadline, !headline.isEmpty {
                Text(headline)
                    .font(isEmphasized ? MoveMarkTheme.Typography.detailEmphasis : MoveMarkTheme.Typography.captionEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            if let metrics = proofMetricsLine, !metrics.isEmpty {
                Text(metrics)
                    .font(MoveMarkTheme.Typography.tinyMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
                    .lineLimit(2)
            }

            HStack(alignment: .center, spacing: 10) {
                nextStepRow
                Spacer(minLength: 6)
                ctaView
            }
            .padding(.top, isEmphasized ? 3 : 0)
        }
        .padding(.horizontal, isEmphasized ? 17 : 14)
        .padding(.top, isEmphasized ? 14 : 8)
        .padding(.bottom, isEmphasized ? 14 : 8)
        .background(bandBackground)
        .offset(y: isPressed ? -1 : 0)
        .animation(MMMotion.press, value: isPressed)
    }

    @ViewBuilder
    private var nextStepRow: some View {
        if isEmphasized {
            let line: String = {
                if let next = nextAction, !next.isEmpty { return next }
                return fallbackPrimaryLine
            }()

            HStack(alignment: .top, spacing: 7) {
                Circle()
                    .fill(MoveMarkTheme.Colors.primary)
                    .frame(width: 4, height: 4)
                    .padding(.top, 5)

                Text(line)
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
        } else {
            Text(fallbackPrimaryLine)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var ctaView: some View {
        Text(ctaTitle ?? "Open")
            .font(isEmphasized ? MoveMarkTheme.Typography.footnoteEmphasis : MoveMarkTheme.Typography.tinyEmphasis)
            .foregroundStyle(isEmphasized ? MoveMarkTheme.Colors.textOnPrimary : MoveMarkTheme.Colors.textDarkGreen)
            .padding(.horizontal, isEmphasized ? 14 : 10)
            .padding(.vertical, isEmphasized ? 7 : 5)
            .background(
                Capsule()
                    .fill(ctaFill)
            )
            .overlay(
                Capsule()
                    .stroke(ctaStroke, lineWidth: 0.75)
            )
            .scaleEffect(isPressed && isEmphasized ? 0.985 : 1.0)
    }

    private var ctaFill: Color {
        if isEmphasized { return MoveMarkTheme.Colors.primary }
        return MoveMarkTheme.Colors.cardRaised.opacity(0.7)
    }

    private var ctaStroke: Color {
        isEmphasized ? MoveMarkTheme.Colors.primary.opacity(0.2) : MoveMarkTheme.Colors.cardStroke
    }

    private var bandBackground: some View {
        MoveMarkTheme.Colors.cardRaised
            .opacity(0.98)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(MoveMarkTheme.Colors.cardStroke.opacity(0.7))
                    .frame(height: 0.5)
            }
    }

    @ViewBuilder
    private var titleLabel: some View {
        let text = Text(title)
            .font(.system(size: isEmphasized ? 17.5 : 14, weight: .bold))
            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            .lineLimit(isEmphasized ? 2 : 1)

        if let ns = namespace, let id = vaultId {
            text.matchedGeometryEffect(id: "vault-title-\(id.uuidString)", in: ns, isSource: true)
        } else {
            text
        }
    }
}
