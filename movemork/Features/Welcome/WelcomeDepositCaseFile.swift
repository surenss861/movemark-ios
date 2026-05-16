//
//  WelcomeDepositCaseFile.swift
//  movemork
//
//  Evidence Capture — camera-proof snapshot (“before they blame you”).
//

import SwiftUI

struct WelcomeDepositCaseFile: View {
    let maxWidth: CGFloat
    let heroHeight: CGFloat
    var cardVisible: Bool = true
    var tagsVisible: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cornerRadius: CGFloat = 22
    private let proofBarHeight: CGFloat = 58

    private var photoHeight: CGFloat {
        max(heroHeight - proofBarHeight, 160)
    }

    private let issueTags: [(id: String, label: String, isPrior: Bool)] = [
        ("paint", "Chipped paint", false),
        ("stain", "Water stain", false),
        ("prior", "Already there", true)
    ]

    var body: some View {
        evidenceCaptureCard
            .frame(width: maxWidth, height: heroHeight)
            .opacity(cardVisible ? 1 : 0)
            .offset(y: cardVisible ? 0 : 14)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.48), value: cardVisible)
    }

    // MARK: - Card

    private var evidenceCaptureCard: some View {
        VStack(spacing: 0) {
            photoCaptureZone
                .frame(height: photoHeight)

            proofCaptureBar
                .frame(height: proofBarHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.98))
        )
        .overlay(cardBorder)
        .overlay(cardTopHighlight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.24), radius: 14, y: 6)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Colors.primary.opacity(0.38),
                        MoveMarkTheme.Colors.cardStroke.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var cardTopHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
            .padding(0.5)
            .mask(
                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.35)
                )
            )
    }

    // MARK: - Photo capture zone

    private var photoCaptureZone: some View {
        ZStack(alignment: .topLeading) {
            Image("welcome-kitchen-main")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .zIndex(0)

            photoBottomScrim
                .zIndex(1)

            focusBrackets
                .zIndex(2)

            photoOverlays
                .zIndex(10)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                topTrailingRadius: cornerRadius
            )
        )
    }

    private var photoBottomScrim: some View {
        VStack {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.35), Color.black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: min(photoHeight * 0.55, 120))
        }
        .allowsHitTesting(false)
    }

    private var photoOverlays: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    kitchenLabel
                    Text("Move-in proof")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                }

                Spacer(minLength: 8)

                beforeMoveInBadge
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Spacer(minLength: 0)

            issueTagsStack
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            timestampStrip
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var kitchenLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(MoveMarkTheme.Colors.primary)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))

            Text("Kitchen")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 4, y: 1)
    }

    private var beforeMoveInBadge: some View {
        Text("Before move-in")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.95))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )
    }

    private var issueTagsStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(issueTags.enumerated()), id: \.element.id) { index, tag in
                issueTag(label: tag.label, isPrior: tag.isPrior)
                    .scaleEffect(tagScale(for: index))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.78)
                            .delay(0.05 + Double(index) * 0.06),
                        value: tagsVisible
                    )
            }
        }
    }

    private func tagScale(for index: Int) -> CGFloat {
        guard !reduceMotion else { return 1 }
        return tagsVisible ? 1 : 0.88
    }

    @ViewBuilder
    private func issueTag(label: String, isPrior: Bool) -> some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if isPrior {
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                    Capsule()
                        .stroke(Color.white, lineWidth: 1.25)
                } else {
                    Capsule()
                        .fill(MoveMarkTheme.Colors.primary)
                }
            }
            .shadow(color: Color.black.opacity(0.45), radius: 5, y: 2)
    }

    private var timestampStrip: some View {
        Text("Move-in · Apr 14 · 5:42 PM")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.42))
    }

    private var focusBrackets: some View {
        let len: CGFloat = 18
        let pad: CGFloat = 12
        return ZStack {
            bracketView(length: len, corner: .topLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(pad)
            bracketView(length: len, corner: .topRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(pad)
            bracketView(length: len, corner: .bottomLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(pad)
            bracketView(length: len, corner: .bottomRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(pad)
        }
        .allowsHitTesting(false)
    }

    private func bracketView(length: CGFloat, corner: WelcomeBracketCorner) -> some View {
        WelcomeFocusBracket(length: length, corner: corner)
            .stroke(Color.white.opacity(0.58), lineWidth: 1.5)
            .frame(width: length, height: length)
    }

    // MARK: - Proof bar

    private var proofCaptureBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.divider.opacity(0.55))
                .frame(height: 1)

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary)

                Text("Saved to your vault")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Spacer(minLength: 4)

                Text("Report ready")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(MoveMarkTheme.Colors.primary.opacity(0.18))
                    )
                    .overlay(
                        Capsule()
                            .stroke(MoveMarkTheme.Colors.primary.opacity(0.5), lineWidth: 1)
                    )
            }
            .padding(.top, 8)

            Text("12 photos · 3 issues")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.85))
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MoveMarkTheme.Colors.card.opacity(0.98))
    }
}

// MARK: - Focus bracket shape

private enum WelcomeBracketCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct WelcomeFocusBracket: Shape {
    let length: CGFloat
    let corner: WelcomeBracketCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = min(length, min(rect.width, rect.height))

        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: 0, y: l))
            path.addLine(to: .zero)
            path.addLine(to: CGPoint(x: l, y: 0))
        case .topRight:
            path.move(to: CGPoint(x: rect.width - l, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: l))
        case .bottomLeft:
            path.move(to: CGPoint(x: 0, y: rect.height - l))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: l, y: rect.height))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.width, y: rect.height - l))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width - l, y: rect.height))
        }
        return path
    }
}

struct WelcomeEvidenceDeskRuledPaper: View {
    var body: some View { EmptyView() }
}
