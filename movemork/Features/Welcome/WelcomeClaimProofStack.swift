//
//  WelcomeClaimProofStack.swift
//  movemork
//
//  Welcome-only — the deposit claim and the proof that answers it, as one artifact.
//

import SwiftUI

/// A proof receipt, not a dashboard.
///
/// The claim against you, the evidence that answers it, and a quiet way through to the report.
/// Everything that made earlier versions read as a miniature app screen is gone: no ruled
/// sections stacked into zones, no repeated room metadata, no shouting status caps, no heavy
/// footer band pretending to be a second button.
///
/// Colour is rationed. Amber means claim and risk, emerald means documented, and nothing else
/// on the artifact is allowed either one.
struct WelcomeClaimProofStack: View {
    var thumbnailImageName: String = "welcome-proof-hero"
    var proofVisible: Bool = true
    /// Short iPhones get `Metrics.compact`. Set from available vertical space, never from a
    /// device name — see `WelcomeZoneLayout`.
    var compactHeight: Bool = false

    private let stackRadius: CGFloat = 26

    private var metrics: Metrics { compactHeight ? .compact : .regular }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One component at two densities, not two designs.
    ///
    /// On an SE the 220pt artifact leaves nothing between card, headline and CTA. Compact takes
    /// the ~15pt back out of padding, the thumbnail and the gaps — never out of the type. Every
    /// font token, both radii and the whole colour ration are identical across the two, so
    /// hierarchy is untouched and the only thing that moves is how much of a short screen the
    /// card eats.
    ///
    /// These are visual targets at the default text size, not clamps: nothing here caps a
    /// dimension that larger Dynamic Type needs to grow, so the artifact still expands.
    struct Metrics {
        let hPadding: CGFloat
        let vPadding: CGFloat
        let claimToTitle: CGFloat
        let titleToEvidence: CGFloat
        let thumbnail: CGFloat
        let footerMinHeight: CGFloat

        /// ~220pt.
        static let regular = Metrics(
            hPadding: 20,
            vPadding: 18,
            claimToTitle: 10,
            titleToEvidence: 14,
            thumbnail: 68,
            footerMinHeight: 44
        )

        /// ~205pt.
        static let compact = Metrics(
            hPadding: 20,
            vPadding: 15,
            claimToTitle: 8,
            titleToEvidence: 12,
            thumbnail: 64,
            footerMinHeight: 42
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            record
            divider
            footer
        }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: stackRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: stackRadius, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 8)
    }

    /// Near-opaque graphite. The material underneath is deliberately weak — enough that the
    /// artifact is not cut out of the frame, not enough to read as glass. Glass belongs to the
    /// control layer; this is content.
    private var surface: some View {
        RoundedRectangle(cornerRadius: stackRadius, style: .continuous)
            .fill(MoveMarkTheme.Colors.evidenceReceipt.opacity(0.90))
            .background(
                RoundedRectangle(cornerRadius: stackRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(0.35)
            )
    }

    // MARK: - Record

    private var record: some View {
        VStack(alignment: .leading, spacing: 0) {
            claimRow
                .padding(.bottom, metrics.claimToTitle)

            Text("Kitchen cabinet damage")
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, metrics.titleToEvidence)

            evidenceRow
        }
        .padding(.horizontal, metrics.hPadding)
        .padding(.vertical, metrics.vPadding)
    }

    /// The label and the amount share a baseline. `$450` on its own line spent a whole line of
    /// the artifact on it and read as a detail; here it reads as the thing at stake.
    private var claimRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("DAMAGE CLAIM")
                .font(MoveMarkTheme.Typography.receiptLabel)
                .foregroundStyle(MoveMarkTheme.Colors.semanticWarning.opacity(0.80))
                .tracking(1.5)

            Spacer(minLength: 0)

            Text("$450")
                .font(MoveMarkTheme.Typography.receiptAmount)
                .foregroundStyle(MoveMarkTheme.Colors.semanticWarning)
                .monospacedDigit()
        }
    }

    private var evidenceRow: some View {
        HStack(alignment: .center, spacing: 14) {
            // Corner radius stays 16 at both sizes. The thumbnail loses 4pt on short screens,
            // but its corners are part of what makes this read as the same artifact, so they
            // are held rather than scaled with it.
            Image(thumbnailImageName)
                .resizable()
                .scaledToFill()
                .frame(width: metrics.thumbnail, height: metrics.thumbnail)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    // Resolves once, a beat after the claim. This is the moment the artifact
                    // answers itself, so it gets its own entrance rather than fading up with
                    // the rest of the row.
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                        .scaleEffect(proofVisible || reduceMotion ? 1 : 0.4)
                        .animation(
                            reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.55).delay(0.12),
                            value: proofVisible
                        )

                    Text("Documented")
                        .font(MoveMarkTheme.Typography.receiptStatus)
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }

                // No room and no timestamp: the title above already says what this concerns.
                Text("12 photos · Apr 14")
                    .font(MoveMarkTheme.Typography.receiptMeta)
                    .foregroundStyle(MoveMarkTheme.Colors.textBodyNeutral.opacity(0.65))
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
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
    }

    /// A quiet action row, not a second button: no fill, no tint, a neutral chevron.
    ///
    /// `minHeight`, not `height`. 44/42 is the tap-target floor and the visual target at the
    /// default text size; at larger Dynamic Type the row grows past it instead of clipping the
    /// label against the divider.
    private var footer: some View {
        HStack(spacing: 6) {
            Text("Move-in report ready")
                .font(MoveMarkTheme.Typography.receiptFooter)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.90))
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textBodyNeutral.opacity(0.45))
        }
        .padding(.horizontal, metrics.hPadding)
        .padding(.vertical, 6)
        .frame(minHeight: metrics.footerMinHeight)
    }
}
