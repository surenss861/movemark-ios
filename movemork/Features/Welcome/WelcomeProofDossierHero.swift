//
//  WelcomeProofDossierHero.swift
//  movemork
//
//  Premium proof dossier — layered vault file.
//

import SwiftUI

struct WelcomeProofDossierHero: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            depositSlab
            reportPaperLayer
            proofFileCard
        }
        .frame(width: width, height: 272)
    }

    private var depositSlab: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(MoveMarkTheme.Colors.surface.opacity(0.65))
            .frame(width: width * 0.66, height: 104)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.subtleStroke.opacity(0.5), lineWidth: 1)
            )
            .offset(x: width * 0.24, y: 14)
            .allowsHitTesting(false)
    }

    private var reportPaperLayer: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(MoveMarkTheme.Colors.paperSurface.opacity(0.07))
            .frame(width: width * 0.88, height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.paperSurface.opacity(0.12), lineWidth: 1)
            )
            .rotationEffect(.degrees(4))
            .offset(x: 18, y: -8)
            .allowsHitTesting(false)
    }

    private var proofFileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBlock
            photoStrip
            scoreRow
        }
        .padding(20)
        .frame(width: width, alignment: .leading)
        .background(fileGradient)
        .overlay(diagonalHighlight)
        .overlay(innerShadowMask)
        .overlay(fileTopHighlight)
        .overlay(fileBorder)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.24), radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.12), .clear],
                        startPoint: .bottom,
                        endPoint: UnitPoint(x: 0.5, y: 0.55)
                    )
                )
                .allowsHitTesting(false)
        )
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MOVE-IN PROOF")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(MoveMarkTheme.Colors.limeAccent.opacity(0.92))
                Spacer()
                timestampBadge
            }

            Text("Kitchen")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("12 photos saved")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
        }
    }

    private var timestampBadge: some View {
        Text("Timestamped")
            .font(.system(size: 9, weight: .medium))
            .tracking(0.5)
            .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.55))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(MoveMarkTheme.Colors.surface.opacity(0.45))
            .clipShape(Capsule())
    }

    private var photoStrip: some View {
        HStack(spacing: 7) {
            thumb("welcome-kitchen-main")
            thumb("welcome-kitchen-2")
            thumb("welcome-kitchen-3")
        }
    }

    private func thumb(_ name: String) -> some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.limeAccent.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 6, y: 3)
    }

    private var scoreRow: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .stroke(MoveMarkTheme.Colors.surface, lineWidth: 4)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: 0.82)
                    .stroke(MoveMarkTheme.Colors.limeAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 50, height: 50)
                Text("82")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Strong")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Text("Proof score")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }

            Spacer(minLength: 0)

            stampedReadyChip
        }
    }

    private var stampedReadyChip: some View {
        Text("Report ready")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(MoveMarkTheme.Colors.textOnPrimary.opacity(0.95))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(MoveMarkTheme.Colors.primary.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.limeAccent.opacity(0.22), lineWidth: 0.8)
            )
    }

    private var diagonalHighlight: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.12),
                Color.white.opacity(0.04),
                .clear,
                .clear
            ],
            startPoint: UnitPoint(x: 0.1, y: 0),
            endPoint: UnitPoint(x: 0.9, y: 0.55)
        )
        .allowsHitTesting(false)
    }

    private var innerShadowMask: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .stroke(Color.black.opacity(0.18), lineWidth: 1)
            .blur(radius: 2)
            .offset(y: 2)
            .mask(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
            )
            .allowsHitTesting(false)
    }

    private var fileGradient: some View {
        LinearGradient(
            colors: [MoveMarkTheme.Colors.cardRaised, MoveMarkTheme.Colors.card, MoveMarkTheme.Colors.surface.opacity(0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var fileTopHighlight: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.2), Color.white.opacity(0.04), .clear],
                    startPoint: .topLeading,
                    endPoint: UnitPoint(x: 0.6, y: 0.5)
                ),
                lineWidth: 1.2
            )
    }

    private var fileBorder: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Colors.limeAccent.opacity(0.35),
                        MoveMarkTheme.Colors.cardStroke
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
    }
}
