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
        MMScreen(
            title: MoveMarkGrowthCopy.firstRunMomentTitle,
            subtitle: MoveMarkGrowthCopy.firstRunMomentSubtitle
        ) {
            MMGroup {
                ForEach(Array(RentalMoment.allCases.enumerated()), id: \.element) { index, moment in
                    if index > 0 { MMRowDivider(leading: 52) }
                    momentRow(moment)
                }
            }

            HStack(spacing: 8) {
                if isPreparing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MMInk.secondary)
                }

                Text(
                    isPreparing
                        ? "Loading your vaults…"
                        : MoveMarkGrowthCopy.firstRunMomentFootnote
                )
                .mmFont(13)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private func momentRow(_ moment: RentalMoment) -> some View {
        MMRow(
            title: moment.title,
            subtitle: moment.blurb,
            icon: moment.iconName,
            isDisabled: isPreparing
        ) {
            MMHaptics.selection()
            onSelect(moment)
        }
        .accessibilityLabel("\(moment.title). \(moment.blurb)")
    }
}
