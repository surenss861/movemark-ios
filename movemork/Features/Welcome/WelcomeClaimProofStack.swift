//
//  WelcomeClaimProofStack.swift
//  movemork
//
//  Welcome-only — damage claim vs saved proof artifact. No photo-card hero.
//

import SwiftUI

struct WelcomeClaimProofStack: View {
    var thumbnailImageName: String = "welcome-kitchen-main"
    var proofVisible: Bool = true

    private let stackRadius: CGFloat = 28

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            claimSection
            sectionDivider
            proofSection
            sectionDivider
            reportSection
        }
        .background(MoveMarkTheme.Colors.evidenceCardRaised)
        .clipShape(RoundedRectangle(cornerRadius: stackRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: stackRadius, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.95), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
    }

    private var claimSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("DAMAGE CLAIM")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.semanticWarning.opacity(0.82))
                .tracking(0.6)

            Text("Kitchen cabinet damage")
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .lineLimit(2)

            Text("Potential charge · $450")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.semanticWarning.opacity(0.88))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var proofSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(thumbnailImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 108, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.9), lineWidth: 0.75)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.9))

                    Text("Already documented")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(1)
                }

                Text("Kitchen · Apr 14 · 5:42 PM")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .lineLimit(1)

                Text("12 photos attached")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .opacity(proofVisible ? 1 : 0)
        .offset(y: proofVisible ? 0 : 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.34), value: proofVisible)
    }

    private var reportSection: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.9))

            VStack(alignment: .leading, spacing: 2) {
                Text("Move-in report ready")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text("Export organized proof when you need it.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(MoveMarkTheme.Colors.cardStroke.opacity(0.55))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}
