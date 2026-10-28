//
//  WelcomeProofSlip.swift
//  movemork
//
//  @file Welcome-only — a compact Proof Slip: the kind of dated record the renter's vault will hold. It is
//        the bridge from Welcome into the product (same paper, stamp and quiet metadata as MMProofSlip),
//        kept small so the headline stays the star. It supports, never competes: when space runs short it
//        drops its lowest-value metadata first (the "Original files preserved" foot, then the date line)
//        rather than shrinking any type on the screen.
//  @domain welcome
//  @see [[MMSystem+Patterns.swift]] — MMProofSlip
//

import SwiftUI

struct WelcomeProofSlip: View {
    enum Density {
        /// Everything: MOVE-IN RECORD, Kitchen, Apr 14 · 12 photos, Recorded, Original files preserved.
        case regular
        /// Short screens (SE): drops the "Original files preserved" foot.
        case compact
        /// Accessibility sizes: also drops the date line; the stamp drops under the title.
        case minimal
    }

    var density: Density = .regular

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let paper = Color(red: 0.980, green: 0.976, blue: 0.965)   // #FAF9F6, as MMProofSlip

    private var showsDate: Bool { density != .minimal }
    private var showsFoot: Bool { density == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("MOVE-IN RECORD")
                    .mmFont(10, .semibold)
                    .tracking(1.0)
                    .foregroundStyle(MMInk.secondary)
                Spacer(minLength: 8)
                if !dynamicTypeSize.isAccessibilitySize { stamp }
            }

            Text("Kitchen")
                .mmFont(19, .semibold)
                .foregroundStyle(MMInk.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .padding(.top, 4)

            if dynamicTypeSize.isAccessibilitySize {
                stamp.padding(.top, 6)
            }

            if showsDate {
                Text("Apr 14 · 12 photos")
                    .mmFont(12.5)
                    .monospacedDigit()
                    .foregroundStyle(MMInk.secondary)
                    .padding(.top, 1)
            }

            if showsFoot {
                DashedRule()
                    .stroke(MMInk.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
                    .padding(.vertical, 9)

                HStack(spacing: 5) {
                    Image(systemName: "lock")
                        .font(.system(size: 10.5, weight: .medium))
                    Text("Original files preserved")
                        .mmFont(12)
                }
                .foregroundStyle(MMInk.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.paper, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.75))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch density {
        case .regular: "Example record: move-in record, Kitchen, April 14, 12 photos, recorded. Original files preserved."
        case .compact: "Example record: move-in record, Kitchen, April 14, 12 photos, recorded."
        case .minimal: "Example record: move-in record, Kitchen, recorded."
        }
    }

    /// The RECORDED stamp of the Proof Slip, in its compact form.
    private var stamp: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
            Text("Recorded").mmFont(11, .semibold)
        }
        .foregroundStyle(MMInk.text)
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
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
