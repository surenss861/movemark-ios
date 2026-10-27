//
//  WelcomeProofSlip.swift
//  movemork
//
//  @file Welcome-only — a compact Proof Slip: the kind of dated record the renter's vault will hold. It is
//        the bridge from Welcome into the product (same paper, stamp and quiet metadata as MMProofSlip),
//        kept small so the headline stays the star. At compact heights and accessibility sizes it drops
//        the metadata lines first (MOVE-IN RECORD / Kitchen / Recorded) rather than shrinking type.
//  @domain welcome
//  @see [[MMSystem+Patterns.swift]] — MMProofSlip
//

import SwiftUI

struct WelcomeProofSlip: View {
    /// Drops the date line and the "Original files preserved" foot (short screens, AX sizes).
    var isCompact = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let paper = Color(red: 0.980, green: 0.976, blue: 0.965)   // #FAF9F6, as MMProofSlip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("MOVE-IN RECORD")
                    .mmFont(10.5, .semibold)
                    .tracking(1.0)
                    .foregroundStyle(MMInk.secondary)
                Spacer(minLength: 8)
                if !isCompact { stamp }
            }

            if dynamicTypeSize.isAccessibilitySize {
                Text("Kitchen")
                    .mmFont(isCompact ? 19 : 21, .semibold)
                    .foregroundStyle(MMInk.text)
                    .padding(.top, 6)
                if isCompact { stamp.padding(.top, 8) }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    Text("Kitchen")
                        .mmFont(isCompact ? 19 : 21, .semibold)
                        .foregroundStyle(MMInk.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if isCompact { stamp }
                }
                .padding(.top, isCompact ? 6 : 8)
            }

            if !isCompact {
                Text("Apr 14 · 12 photos")
                    .mmFont(13)
                    .monospacedDigit()
                    .foregroundStyle(MMInk.secondary)
                    .padding(.top, 2)

                DashedRule()
                    .stroke(MMInk.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
                    .padding(.vertical, 12)

                HStack(spacing: 6) {
                    Image(systemName: "lock")
                        .font(.system(size: 11, weight: .medium))
                    Text("Original files preserved")
                        .mmFont(12.5)
                }
                .foregroundStyle(MMInk.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCompact ? 13 : 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.paper, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.75))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCompact
            ? "Example record: move-in record, Kitchen, recorded."
            : "Example record: move-in record, Kitchen, April 14, 12 photos, recorded. Original files preserved.")
    }

    /// The RECORDED stamp of the Proof Slip, in its compact form.
    private var stamp: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark").font(.system(size: 9.5, weight: .bold))
            Text("Recorded").mmFont(11.5, .semibold)
        }
        .foregroundStyle(MMInk.text)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(MMInk.text, lineWidth: 1.1))
        .rotationEffect(.degrees(-2))
        .fixedSize()
    }

    private struct DashedRule: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }
}
