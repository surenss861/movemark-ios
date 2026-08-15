//
//  FirstRunMomentPickerView.swift
//  movemork
//
//  "What are you documenting today?" — routes first run to the renter's moment.
//

import SwiftUI

struct FirstRunMomentPickerView: View {
    /// True while vaults are still loading — selecting early could create a
    /// duplicate vault for someone who already has one.
    let isPreparing: Bool
    let onSelect: (RentalMoment) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                MMRenterHeader(
                    title: MoveMarkGrowthCopy.firstRunMomentTitle,
                    subtitle: MoveMarkGrowthCopy.firstRunMomentSubtitle
                )

                VStack(spacing: 10) {
                    ForEach(RentalMoment.allCases) { moment in
                        momentRow(moment)
                    }
                }

                HStack(spacing: 8) {
                    if isPreparing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(MoveMarkTheme.Colors.textSecondary)
                    }

                    Text(
                        isPreparing
                            ? "Loading your vaults…"
                            : MoveMarkGrowthCopy.firstRunMomentFootnote
                    )
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .mmProofShellBackground(heroFocus: false, ctaBloom: false)
    }

    private func momentRow(_ moment: RentalMoment) -> some View {
        Button {
            MMHaptics.selection()
            onSelect(moment)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: moment.iconName)
                    .font(MoveMarkTheme.Typography.subtitleLarge)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(moment.title)
                        .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(moment.blurb)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.94))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(MoveMarkTheme.Typography.footnoteEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MoveMarkTheme.Colors.card.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.45), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPreparing)
        .opacity(isPreparing ? 0.55 : 1)
        .accessibilityLabel("\(moment.title). \(moment.blurb)")
    }
}
