//
//  WelcomeProofPassportCard.swift
//  movemork
//
//  Iconic proof passport — one premium digital proof file.
//

import SwiftUI

struct WelcomeProofPassportCard: View {
    let width: CGFloat

    private var photoHeight: CGFloat { min(168, width * 0.48) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoSection
            proofSection
        }
        .frame(width: width)
        .background(cardSurface)
        .overlay(topHighlight)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.28), radius: 24, y: 12)
    }

    private var photoSection: some View {
        ZStack(alignment: .bottomLeading) {
            Image("welcome-kitchen-main")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: photoHeight)
                .clipped()

            LinearGradient(
                colors: [.clear, MoveMarkTheme.Colors.cardRaised.opacity(0.9)],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: photoHeight)

            Text("Kitchen")
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(MoveMarkTheme.Colors.primary.opacity(0.92))
                .clipShape(Capsule())
                .padding(16)
        }
        .frame(width: width, height: photoHeight)
    }

    private var proofSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MOVE-IN PROOF")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(MoveMarkTheme.Colors.limeAccent.opacity(0.9))

            HStack(alignment: .center, spacing: 14) {
                scoreRing
                VStack(alignment: .leading, spacing: 4) {
                    Text("Proof score")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    Text("82 · Strong")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    Text("12 photos")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    reportReadyChip
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MoveMarkTheme.Colors.cardRaised)
    }

    private var scoreRing: some View {
        ZStack {
            Circle()
                .stroke(MoveMarkTheme.Colors.surface, lineWidth: 4)
                .frame(width: 52, height: 52)
            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(MoveMarkTheme.Colors.limeAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 52, height: 52)
        }
    }

    private var reportReadyChip: some View {
        Text("Report ready")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(MoveMarkTheme.Colors.textOnPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MoveMarkTheme.Colors.primary)
            .clipShape(Capsule())
    }

    private var cardSurface: some View {
        LinearGradient(
            colors: [MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.card],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var topHighlight: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.14), Color.white.opacity(0.03), .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.4)
                ),
                lineWidth: 1.2
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.85), lineWidth: 1)
    }
}
