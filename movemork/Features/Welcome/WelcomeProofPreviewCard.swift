//
//  WelcomeProofPreviewCard.swift
//  movemork
//
//  Welcome-only saved proof preview — simpler than in-app ProofArtifactCard.
//

import SwiftUI

struct WelcomeProofPreviewCard: View {
    var imageName: String = "welcome-kitchen-main"
    var photoHeight: CGFloat = 160
    var cornerRadius: CGFloat = 20
    var tagsVisible: Bool = true

    private let issueTags = ["Already there", "Chipped paint"]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            photoPane
            receiptFooter
        }
        .background(MoveMarkTheme.Colors.evidenceCard)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("MOVE-IN PROOF")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("SAVED")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.95))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary.opacity(0.16))
                )
                .overlay(
                    Capsule()
                        .stroke(MoveMarkTheme.Colors.primary.opacity(0.48), lineWidth: 0.85)
                )
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var photoPane: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                VStack {
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.42)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 56)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if tagsVisible {
                HStack(spacing: 6) {
                    ForEach(Array(issueTags.enumerated()), id: \.offset) { index, tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Color.black.opacity(0.72),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                            .scaleEffect(reduceMotion ? 1 : (tagsVisible ? 1 : 0.92))
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.34).delay(Double(index) * 0.04),
                                value: tagsVisible
                            )
                    }
                }
                .padding(.leading, 12)
                .padding(.bottom, 12)
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: photoHeight)
        .padding(.horizontal, 14)
    }

    private var receiptFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.cardStroke.opacity(0.65))
                .frame(height: 1)
                .padding(.top, 12)

            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.95))

                Text("Kitchen documented")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.top, 10)

            Text("12 photos · Verified Apr 14")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}
