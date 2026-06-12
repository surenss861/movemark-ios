//
//  WelcomeEvidenceStack.swift
//  movemork
//
//  Welcome-only hero — saved evidence on a subtle report sheet.
//

import SwiftUI

struct WelcomeEvidenceStack: View {
    var imageName: String = "welcome-kitchen-main"
    var photoHeight: CGFloat = 196
    var tagsVisible: Bool = true

    private let issueCallouts = ["Already there", "Chipped paint"]
    private let sheetOffset: CGFloat = 10
    private let cardRadius: CGFloat = 28
    private let photoRadius: CGFloat = 23

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            reportSheetLayer
            evidenceCard
        }
    }

    /// Neutral paper sheet — charcoal, not green; slight offset behind evidence.
    private var reportSheetLayer: some View {
        RoundedRectangle(cornerRadius: cardRadius - 2, style: .continuous)
            .fill(MoveMarkTheme.Colors.paperSurface.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: cardRadius - 2, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.35), lineWidth: 0.75)
            )
            .padding(.top, sheetOffset + 6)
            .padding(.leading, sheetOffset + 4)
            .padding(.trailing, 2)
            .padding(.bottom, 2)
    }

    private var evidenceCard: some View {
        VStack(spacing: 0) {
            photoPane
            receiptFooter
        }
        .background(MoveMarkTheme.Colors.evidenceCard)
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 6)
    }

    private var photoPane: some View {
        ZStack(alignment: .topLeading) {
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                VStack {
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.34)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 48)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: photoRadius, style: .continuous))

            Text("Kitchen · Apr 14 · 5:42 PM")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Color.black.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .padding(.leading, 12)
                .padding(.top, 12)

            if tagsVisible {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(issueCallouts.enumerated()), id: \.offset) { index, label in
                        Text(label)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Color.black.opacity(0.62),
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                            )
                            .scaleEffect(reduceMotion ? 1 : (tagsVisible ? 1 : 0.94))
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.32).delay(Double(index) * 0.05),
                                value: tagsVisible
                            )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 12)
                .padding(.bottom, 12)
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: photoHeight)
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private var receiptFooter: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.85))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("Saved proof record")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text("12 photos attached · Move-in inspection")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Text("Report-ready")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.85))
                .lineLimit(1)
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(MoveMarkTheme.Colors.fieldFill.opacity(0.38))
    }
}
