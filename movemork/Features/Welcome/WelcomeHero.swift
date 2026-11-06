//
//  WelcomeHero.swift
//  movemork
//
//  @file Welcome-only: the moment between the copy and the actions. Not a card and not a sample record: the
//        room itself becomes the evidence. Three studies were rendered on the real footage with identical text
//        and action positions (`Style`); see the exploration goldens. The cut-outs ease the grade and veil
//        inside a precise frame, so the live footage there reads clearer. There is no second video and no
//        continuous effect: one brief reveal, then the composition is static (and simply static under Reduce
//        Motion).
//  @domain welcome
//

import SwiftUI

enum WelcomeHeroStyle: CaseIterable {
    /// One framed region of the room reads clearer, with fine registration marks and one editorial line.
    case aperture
    /// A short documentary sequence: one large frame and two partial frames running off the edge.
    case firstFrame
    /// The photograph untouched; a fine marginal rule with scale ticks and one line of copy.
    case margin
}

/// Full-screen rects reported by the hero to the screen, which eases its grade and veil inside them.
struct WelcomeCutoutKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

struct WelcomeHero: View {
    var style: WelcomeHeroStyle
    var isCompact: Bool
    /// 0 → 1 once on appear (immediately 1 under Reduce Motion).
    var reveal: CGFloat
    /// The screen's named coordinate space the cut-outs are measured in.
    var coordinateSpace: String

    @ScaledMetric(relativeTo: .body) private var lineSize: CGFloat = 15
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            switch style {
            case .aperture: aperture
            case .firstFrame: firstFrame
            case .margin: margin
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Move-in: a moment worth documenting.")
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
            Text("A moment worth documenting.")
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

    // MARK: - First frame

    private var firstFrame: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width
                let big = w * 0.6
                let small = w * 0.3
                HStack(spacing: 8) {
                    frame(index: "01", width: big)
                    frame(index: "02", width: small)
                    frame(index: "03", width: small)  // runs off the edge: the sequence continues
                }
            }
            .frame(height: isCompact ? 88 : 112)
            Text("Before you unpack. Frame by frame.")
                .font(.system(size: lineSize, weight: .regular, design: .serif).italic())
                .foregroundStyle(.white.opacity(0.9))
                .opacity(reveal)
        }
    }

    private func frame(index: String, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            cutout(revealFromCentre: false)
            RegistrationMarks(length: 8)
                .stroke(.white.opacity(0.7), lineWidth: 1)
            Text(index)
                .mmFont(10, .semibold)
                .tracking(1)
                .foregroundStyle(.white.opacity(0.85))
                .padding(6)
        }
        .frame(width: width)
        .opacity(reveal)
    }

    // MARK: - Margin

    private var margin: some View {
        HStack(alignment: .bottom, spacing: 14) {
            ScaleRule(ticks: isCompact ? 7 : 9)
                .stroke(.white.opacity(0.5), lineWidth: 1)
                .frame(width: 10)
                .opacity(reveal)
            VStack(alignment: .leading, spacing: 4) {
                Text("BEFORE YOU UNPACK.")
                    .mmFont(10.5, .semibold)
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Every room, on the record.")
                    .font(.system(size: lineSize, weight: .regular, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.92))
            }
            .shadow(color: .black.opacity(0.45), radius: 6, y: 1)
            .opacity(reveal)
        }
        .frame(height: isCompact ? 84 : 112, alignment: .bottomLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// A vertical hairline with evenly spaced scale ticks, every fourth one longer.
private struct ScaleRule: Shape {
    var ticks: Int
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        let n = max(ticks, 2)
        for i in 0..<n {
            let y = r.minY + r.height * CGFloat(i) / CGFloat(n - 1)
            p.move(to: CGPoint(x: r.minX, y: y))
            p.addLine(to: CGPoint(x: r.minX + (i % 4 == 0 ? r.width : r.width * 0.5), y: y))
        }
        return p
    }
}
