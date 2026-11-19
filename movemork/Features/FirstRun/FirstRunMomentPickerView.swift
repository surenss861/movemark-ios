//
//  FirstRunMomentPickerView.swift
//  movemork
//
//  "What are you documenting?" — the stage of the rental, two paths only (moving in / moving out).
//

import SwiftUI

struct FirstRunMomentPickerView: View {
    /// True while rentals are still loading — selecting early could create a duplicate rental for someone
    /// who already has one.
    let isPreparing: Bool
    let onSelect: (RentalMoment) -> Void
    /// The way out of first run for someone who signed in to the wrong account.
    var onSignOut: (() -> Void)? = nil

    var body: some View {
        MMScreen(
            title: MoveMarkGrowthCopy.firstRunMomentTitle,
            subtitle: MoveMarkGrowthCopy.firstRunMomentSubtitle
        ) {
            VStack(spacing: 12) {
                ForEach(RentalMoment.allCases) { moment in
                    MMChoiceCard(
                        title: moment.title,
                        subtitle: moment.blurb,
                        icon: moment.iconName,
                        isDisabled: isPreparing,
                        accessibilityID: "firstRun.moment.\(moment.rawValue)"
                    ) {
                        MMHaptics.selection()
                        onSelect(moment)
                    }
                }
            }

            if isPreparing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(MMInk.secondary)
                    Text("Loading your rentals…")
                        .mmFont(13)
                        .foregroundStyle(MMInk.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 14)
                .accessibilityElement(children: .combine)
            }

            if let onSignOut {
                MMSecondaryButton(title: "Sign out", tint: MMInk.secondary, action: onSignOut)
                    .accessibilityIdentifier("firstRun.signOut")
                    .padding(.top, 18)
            }
        }
    }
}
