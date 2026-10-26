//
//  WelcomeClaimProofStack.swift
//  movemork
//
//  Welcome-only — the deposit claim and the proof that answers it, as one artifact.
//

import SwiftUI

/// A proof receipt, not a dashboard.
///
/// The claim against you, the evidence that answers it, and a quiet way through to the report. It sits
/// on the system's dark evidence surface (`MMInk.evidence`) with the evidence stroke — the same material
/// the app uses for photos — so the first impression already looks like the product.
///
/// Colour is rationed: amber means claim and risk; everything else is white at three strengths. The
/// screen's one lime belongs to the primary action below, never to this artifact.
struct WelcomeClaimProofStack: View {
    var thumbnailImageName: String = "welcome-proof-hero"
    var proofVisible: Bool = true
    /// Short iPhones get `Metrics.compact`. Set from available vertical space, never from a
    /// device name — see `WelcomeZoneLayout`.
    var compactHeight: Bool = false

    private let stackRadius: CGFloat = MMMetrics.cardRadius

    private var metrics: Metrics { compactHeight ? .compact : .regular }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One component at two densities, not two designs. Compact takes space out of padding, the
    /// thumbnail and the gaps — never out of the type.
    struct Metrics {
        let hPadding: CGFloat
        let vPadding: CGFloat
        let claimToTitle: CGFloat
        let titleToEvidence: CGFloat
        let thumbnail: CGFloat
        let footerMinHeight: CGFloat

        static let regular = Metrics(
            hPadding: 18,
            vPadding: 16,
            claimToTitle: 8,
            titleToEvidence: 14,
            thumbnail: 64,
            footerMinHeight: 44
        )

        static let compact = Metrics(
            hPadding: 16,
            vPadding: 13,
            claimToTitle: 6,
            titleToEvidence: 11,
            thumbnail: 56,
            footerMinHeight: 42
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            record
            divider
            footer
        }
        .background(
            RoundedRectangle(cornerRadius: stackRadius, style: .continuous)
                .fill(MMInk.evidence.opacity(0.92))
        )
        .clipShape(RoundedRectangle(cornerRadius: stackRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: stackRadius, style: .continuous)
                .strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75)
        )
    }

    // MARK: - Record

    private var record: some View {
        VStack(alignment: .leading, spacing: 0) {
            claimRow
                .padding(.bottom, metrics.claimToTitle)

            Text("Kitchen cabinet damage")
                .mmFont(18, .semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, metrics.titleToEvidence)

            evidenceRow
        }
        .padding(.horizontal, metrics.hPadding)
        .padding(.vertical, metrics.vPadding)
    }

    /// The label and the amount share a baseline: the amount reads as the thing at stake.
    private var claimRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("DAMAGE CLAIM")
                .mmFont(11, .semibold)
                .tracking(0.6)
                .foregroundStyle(WelcomeInk.claim.opacity(0.85))

            Spacer(minLength: 0)

            Text("$450")
                .mmFont(17, .semibold)
                .foregroundStyle(WelcomeInk.claim)
                .monospacedDigit()
        }
    }

    private var evidenceRow: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(thumbnailImageName)
                .resizable()
                .scaledToFill()
                .frame(width: metrics.thumbnail, height: metrics.thumbnail)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(MMInk.evidenceStroke, lineWidth: 0.5)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // Resolves once, a beat after the claim: the moment the artifact answers itself.
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .scaleEffect(proofVisible || reduceMotion ? 1 : 0.4)
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.7).delay(0.12),
                            value: proofVisible
                        )

                    Text("Documented")
                        .mmFont(15, .semibold)
                        .foregroundStyle(.white)
                }

                Text("12 photos · Apr 14")
                    .mmFont(13)
                    .foregroundStyle(MMInk.heroSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .opacity(proofVisible ? 1 : 0)
        .offset(y: proofVisible ? 0 : 10)
        .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: proofVisible)
    }

    // MARK: - Footer

    private var divider: some View {
        Rectangle()
            .fill(MMInk.evidenceStroke)
            .frame(height: 0.5)
    }

    /// A quiet row, not a second button: no fill, no tint, a neutral chevron. `minHeight`, so larger
    /// Dynamic Type grows the row instead of clipping the label.
    private var footer: some View {
        HStack(spacing: 6) {
            Text("Move-in report ready")
                .mmFont(14, .medium)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, metrics.hPadding)
        .padding(.vertical, 6)
        .frame(minHeight: metrics.footerMinHeight)
    }
}

/// Welcome-only ink on the dark artifact.
enum WelcomeInk {
    /// The claim amber, lifted for legibility on the dark evidence surface (`MMInk.warning` is tuned for white).
    static let claim = Color(red: 0.902, green: 0.690, blue: 0.333)   // #E6B055
}
