//
//  MMSystem+Entry.swift
//  movemork
//
//  @file Building blocks the Entry system (Welcome → account → first run) adds to the kit: a large choice
//        card for a two-path decision, and a quiet resolved state that replaces a form once its job is done
//        (e.g. "Check your email"). Built on MMSystem tokens; no new colours.
//  @domain design-system
//  @see [[MMSystem.swift]]
//

import SwiftUI

/// One of a small number of large, equal choices (first run: moving in / moving out). White card on the
/// sheet, glyph, title, one line, chevron. At accessibility sizes the card grows taller; the type never
/// shrinks and the glyph moves above the text.
struct MMChoiceCard: View {
    let title: String
    let subtitle: String
    var icon: String
    var isDisabled = false
    var accessibilityID: String? = nil
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            let isAX = dynamicTypeSize.isAccessibilitySize
            HStack(alignment: .center, spacing: 14) {
                if !isAX {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(MMInk.text.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(MMInk.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .mmFont(17, .semibold)
                        .foregroundStyle(MMInk.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .mmFont(14)
                        .foregroundStyle(MMInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                MMRowChevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous)
                .strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
            .contentShape(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
        }
        .buttonStyle(MMLightPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(accessibilityID ?? title)
    }
}

/// A form's resolved state, in place of the form (never a banner inside a live form): a quiet glyph, what
/// happened, what to do next, and one secondary action.
struct MMResolvedBlock: View {
    let icon: String
    /// Nil when the screen's header already says it (no title repeated twice).
    var title: String? = nil
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(MMInk.text.opacity(0.7))
                .accessibilityHidden(true)
            if let title {
                Text(title)
                    .mmFont(20, .semibold)
                    .foregroundStyle(MMInk.text)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 12)
            }
            Text(message)
                .mmFont(16)
                .foregroundStyle(MMInk.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, title == nil ? 12 : 6)
            if let actionTitle, let action {
                MMSecondaryButton(title: actionTitle, action: action)
                    .padding(.top, 18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
