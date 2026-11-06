//
//  WelcomeEvidenceCaption.swift
//  movemork
//
//  @file Welcome-only: the example record as an archival caption set into the photograph, not a card on top
//        of it. It replaces WelcomeProofSlip (white paper card, RECORDED stamp, dashed rule, padlock).
//        - The kitchen footage stays the hero; this is typeset metadata in the darkest part of the frame.
//        - It says plainly that it is an example: nothing here is the viewer's saved evidence.
//        - Lime stays reserved for the one action below it.
//  @domain welcome
//
//  Two art directions were explored (`Style`); `.archive` is the one shipped. `.contactSheet` is kept for the
//  exploration snapshot only.
//

import SwiftUI

struct WelcomeEvidenceCaption: View {
    enum Style { case archive, contactSheet }

    var style: Style = .archive
    /// Short screens and accessibility sizes: "example" moves into the index line and the separate note goes, so
    /// the sign-in options below never leave the screen.
    var isCompact = false

    // The serif lines scale with Dynamic Type like every mmFont line, so the room name never drops below the date.
    @ScaledMetric(relativeTo: .title2) private var roomSize: CGFloat = 27
    @ScaledMetric(relativeTo: .title2) private var compactRoomSize: CGFloat = 24
    @ScaledMetric(relativeTo: .caption) private var noteSize: CGFloat = 11.5

    private static let index = "01"
    private static let room = "Kitchen"
    private static let detail = "Apr 14 · 12 photos"

    var body: some View {
        Group {
            switch style {
            case .archive: archive
            case .contactSheet: contactSheet
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 1)  // legibility over the moving footage, never a plate
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example move-in record: Kitchen, April 14, 12 photos. Illustrative, not your evidence.")
        .accessibilityIdentifier("welcome.exampleRecord")
    }

    // MARK: - A. Archive caption (shipped)

    /// A ledger margin: one hairline with index ticks, then caption type. Reads like the caption under a
    /// photograph in an inspection archive.
    private var archive: some View {
        HStack(alignment: .top, spacing: 14) {
            IndexMargin(ticks: 3)
                .stroke(.white.opacity(0.42), lineWidth: 1)
                .frame(width: 9)

            VStack(alignment: .leading, spacing: 0) {
                Text(isCompact ? "\(Self.index) / EXAMPLE RECORD" : "\(Self.index) / EXAMPLE MOVE-IN RECORD")
                    .mmFont(10.5, .semibold)
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.58))

                Text(Self.room)
                    .font(.system(size: isCompact ? compactRoomSize : roomSize, weight: .regular, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.top, isCompact ? 4 : 6)

                Text(Self.detail)
                    .mmFont(13.5, .medium)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.top, 2)

                if !isCompact {
                    Text("Illustrative · not your evidence")
                        .font(.system(size: noteSize, weight: .regular, design: .serif).italic())
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - B. Contact sheet (exploration)

    /// Twelve frame marks along a film edge, three exposed, with edge-print metadata beneath.
    private var contactSheet: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { n in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(n <= 3 ? .white.opacity(0.85) : .clear)
                        .overlay(RoundedRectangle(cornerRadius: 1.5).strokeBorder(.white.opacity(0.5), lineWidth: 1))
                        .frame(width: 14, height: 10)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Self.room.uppercased())
                    .mmFont(17, .semibold)
                    .tracking(2.2)
                    .foregroundStyle(.white)
                Text("MOVE-IN ▸ APR 14 ▸ 12 FRAMES")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))
            }
            Text("EXAMPLE CONTACT SHEET · ILLUSTRATIVE")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    /// One vertical hairline with short ticks at the top and evenly down its length, like a ruled index margin.
    private struct IndexMargin: Shape {
        var ticks: Int
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY + 2))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 2))
            for i in 0..<max(ticks, 2) {
                let y = rect.minY + 2 + (rect.height - 4) * CGFloat(i) / CGFloat(max(ticks, 2) - 1)
                p.move(to: CGPoint(x: rect.minX, y: y))
                p.addLine(to: CGPoint(x: rect.minX + (i == 0 ? rect.width : rect.width * 0.55), y: y))
            }
            return p
        }
    }
}
