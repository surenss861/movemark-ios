//
//  WelcomeProofReceiptCard.swift
//  movemork
//
//  Welcome-only saved proof receipt — photo-first, no report peek.
//

import SwiftUI

struct WelcomeProofReceiptCard: View {
    var imageName: String = "welcome-kitchen-main"
    var photoHeight: CGFloat = 186
    var cornerRadius: CGFloat = 28
    var tagsVisible: Bool = true

    private let issueTags = ["Already there", "Chipped paint"]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            photoPane
            receiptStrip
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
                .tracking(0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("SAVED")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.88))
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
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
                        colors: [.clear, Color.black.opacity(0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 52)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

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
                            .background(tagBackground(for: index))
                            .scaleEffect(reduceMotion ? 1 : (tagsVisible ? 1 : 0.92))
                            .animation(
                                reduceMotion ? nil : .easeOut(duration: 0.34).delay(Double(index) * 0.04),
                                value: tagsVisible
                            )
                    }
                }
                .padding(.leading, 14)
                .padding(.bottom, 14)
                .padding(.trailing, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: photoHeight)
        .padding(.horizontal, 14)
    }

    @ViewBuilder
    private func tagBackground(for index: Int) -> some View {
        if index == 0 {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MoveMarkTheme.Colors.primary.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.primary.opacity(0.32), lineWidth: 0.5)
                )
        }
    }

    private var receiptStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.cardStroke.opacity(0.55))
                .frame(height: 1)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Kitchen documented")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text("12 photos · Verified Apr 14")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 76)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MoveMarkTheme.Colors.fieldFill.opacity(0.45))
    }
}
