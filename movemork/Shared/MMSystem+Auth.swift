//
//  MMSystem+Auth.swift
//  movemork
//
//  @file Building blocks the entry screens (launch, auth, first run) add to the system kit: the dark
//        launch-style wait, a single-choice row for grouped lists, and a quiet inline text action.
//  @domain design-system
//  @see [[MMSystem.swift]]
//

import SwiftUI

/// A wait on the dark launch surface — app start, or the signed-in shell fetching its first data. Dark
/// rather than the light `MMLoadingBlock` so the step between the dark launch / Welcome and the first
/// dark-headed screen never flashes a light sheet for a moment.
struct MMLaunchWait: View {
    var message: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(.white.opacity(0.7))
            if let message {
                Text(message)
                    .mmFont(14)
                    .foregroundStyle(MMInk.heroSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MMInk.hero.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message ?? "Loading")
    }
}

/// One option in a single-choice list inside an `MMGroup`: title, optional subtitle, an ink checkmark
/// when selected. Never a tinted fill.
struct MMSelectRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var isSelected = false
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(MMInk.text.opacity(0.75))
                        .frame(width: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .mmFont(16, isSelected ? .semibold : .regular)
                        .foregroundStyle(MMInk.text)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).mmFont(13).foregroundStyle(MMInk.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 2)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MMInk.text)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A quiet inline text action on the light sheet ("Forgot password?", "Sign in"): ink, semibold, no fill.
struct MMTextAction: View {
    let title: String
    var size: CGFloat = 14
    var tint: Color = MMInk.text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .mmFont(size, .semibold)
                .foregroundStyle(tint)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
    }
}
