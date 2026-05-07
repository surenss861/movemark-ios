//
//  VaultCoverBottomBand.swift
//  movemork
//
//  Featured: property → proof workspace headline → metrics → next step + CTA.
//  Non-featured: compact summary row + Open (quiet secondary vault).
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

    /// When we don't show a separate workflow headline, primary line is next action or status.
    private var fallbackPrimaryLine: String {
        if let next = nextAction, !next.isEmpty { return next }
        return statusLine
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isEmphasized ? 7 : 4) {
            if isEmphasized {
                Capsule()
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.58))
                    .frame(width: 30, height: 2)
                    .padding(.bottom, 1)
            }

            titleLabel

            if !city.isEmpty {
                Text(city)
                    .font(.system(size: isEmphasized ? 11.5 : 11, weight: .regular))
                    .foregroundStyle(.white.opacity(isEmphasized ? 0.72 : 0.60))
                    .lineLimit(1)
            }

            if let headline = workflowHeadline, !headline.isEmpty {
                Text(headline)
                    .font(.system(size: isEmphasized ? 14 : 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(isEmphasized ? 0.96 : 0.86))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            if let metrics = proofMetricsLine, !metrics.isEmpty {
                Text(metrics)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(
                        isEmphasized
                            ? MoveMarkTheme.Colors.primary.opacity(0.88)
                            : .white.opacity(0.7)
                    )
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
        .background(bandGradient)
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
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.92))
                    .frame(width: 4, height: 4)
                    .padding(.top, 5)

                Text(line)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
        } else {
            Text(fallbackPrimaryLine)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var ctaView: some View {
        Text(ctaTitle ?? "Open")
            .font(.system(size: isEmphasized ? 12.5 : 11, weight: .semibold))
            .foregroundStyle(isEmphasized ? .white.opacity(0.98) : .white.opacity(0.9))
            .padding(.horizontal, isEmphasized ? 14 : 10)
            .padding(.vertical, isEmphasized ? 7 : 5)
            .background(
                Capsule()
                    .fill(ctaFill)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isEmphasized
                            ? MoveMarkTheme.Colors.primary.opacity(0.14)
                            : Color.white.opacity(0.1),
                        lineWidth: 0.75
                    )
            )
            .scaleEffect(isPressed && isEmphasized ? 0.985 : 1.0)
    }

    private var ctaFill: Color {
        if isEmphasized && !isPressed { return MoveMarkTheme.Colors.primary.opacity(0.11) }
        if isEmphasized && isPressed { return MoveMarkTheme.Colors.primary.opacity(0.18) }
        if isPressed { return Color.white.opacity(0.16) }
        return Color.white.opacity(0.1)
    }

    private var bandGradient: some View {
        LinearGradient(
            colors: isEmphasized
                ? [
                    .clear,
                    .black.opacity(0.28),
                    .black.opacity(0.78),
                    .black.opacity(0.96)
                ]
                : [
                    .clear,
                    .black.opacity(0.2),
                    .black.opacity(0.68),
                    .black.opacity(0.92)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var titleLabel: some View {
        let text = Text(title)
            .font(.system(size: isEmphasized ? 17.5 : 14, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(isEmphasized ? 2 : 1)

        if let ns = namespace, let id = vaultId {
            text.matchedGeometryEffect(id: "vault-title-\(id.uuidString)", in: ns, isSource: true)
        } else {
            text
        }
    }
}
