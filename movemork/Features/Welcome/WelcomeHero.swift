//
//  WelcomeHero.swift
//  movemork
//
//  @file Welcome-only: the Proof Aperture, the moment between the copy and the actions. Not a card and not a
//        sample record: the room itself becomes the evidence. The cut-out eases the grade and veil inside the
//        frame, so the live footage there shows the room in true colour. There is no second video and no
//        continuous effect: one brief reveal, then the composition is static (and simply static under Reduce
//        Motion). First Frame and Documentary Margin were rendered and rejected.
//  @domain welcome
//

import SwiftUI

/// Full-screen rects reported by the hero to the screen, which eases its grade and veil inside them.
struct WelcomeCutoutKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

struct WelcomeHero: View {
    var isCompact: Bool
    /// 0 → 1 once on appear (immediately 1 under Reduce Motion).
    var reveal: CGFloat
    /// The screen's named coordinate space the cut-outs are measured in.
    var coordinateSpace: String

    @ScaledMetric(relativeTo: .body) private var lineSize: CGFloat = 15
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        aperture
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Move-in: before anything changes.")
    }

    // MARK: - Aperture

    /// Caption beside the photograph, like a magazine detail: the editorial line sits on the dark left of the frame,
    /// the aperture frames the room on the right. Inside it the grade and veil ease, so the room appears in its
    /// true colour while everything around it stays cinematic. That difference is the whole idea: what MoveMark
    /// records is the room as it really was.
    private var aperture: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Accessibility sizes: the caption takes the full width above the frame and grows freely; the
                // side-by-side column would truncate and break words.
                VStack(alignment: .leading, spacing: 12) {
                    apertureCaption
                    apertureFrame.frame(height: 120)
                }
            } else {
                HStack(alignment: .bottom, spacing: 16) {
                    apertureCaption
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                    apertureFrame
                        .containerRelativeFrame(.horizontal) { w, _ in w * 0.54 }
                }
                .frame(height: isCompact ? 100 : 128)
            }
        }
    }

    private var apertureCaption: some View {
        VStack(alignment: .leading, spacing: 5) {
            // A short index that never wraps in the caption column; the serif line carries the meaning.
            Text("01 — MOVE-IN")
                .mmFont(10.5, .semibold)
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.82))
            Text("Before anything changes.")
                .font(.system(size: lineSize, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)
        }
        .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
        .opacity(reveal)
    }

    private var apertureFrame: some View {
        ZStack {
            cutout(revealFromCentre: true)
            RegistrationMarks(length: 12)
                .stroke(.white.opacity(0.85), lineWidth: 1)
                .opacity(reveal)
        }
    }

    // MARK: - Shared

    /// Reports this view's frame as a cut-out; the reveal opens it from its centre line (or fades it, for frames).
    private func cutout(revealFromCentre: Bool) -> some View {
        GeometryReader { geo in
            let f = geo.frame(in: .named(coordinateSpace))
            let r = revealFromCentre
                ? f.insetBy(dx: 0, dy: f.height * (1 - reveal) / 2)
                : f
            Color.clear.preference(key: WelcomeCutoutKey.self, value: reveal > 0.01 ? [r] : [])
        }
    }
}

/// Four L-shaped corner marks, like registration marks on a print.
private struct RegistrationMarks: Shape {
    var length: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = length
        for (corner, dx, dy) in [(CGPoint(x: r.minX, y: r.minY), 1.0, 1.0), (CGPoint(x: r.maxX, y: r.minY), -1.0, 1.0),
                                 (CGPoint(x: r.minX, y: r.maxY), 1.0, -1.0), (CGPoint(x: r.maxX, y: r.maxY), -1.0, -1.0)] {
            p.move(to: CGPoint(x: corner.x + l * dx, y: corner.y))
            p.addLine(to: corner)
            p.addLine(to: CGPoint(x: corner.x, y: corner.y + l * dy))
        }
        return p
    }
}
