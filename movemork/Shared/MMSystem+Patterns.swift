//
//  MMSystem+Patterns.swift
//  movemork
//
//  @file The evidence patterns of the MoveMark system — the vocabulary the Proof screen established, made
//        reusable so Maintenance, Move-out, Disputes, the evidence viewer and Welcome speak it too:
//        Proof Slip (an archival record), Evidence Tile (a photo with quiet caption), Case Card (a structured
//        record), Timeline Row (chronology), Progress Strip (quiet completion), Comparison Pair (before/after).
//  @domain design-system
//  @see [[MMSystem.swift]]
//

import SwiftUI

// MARK: - Proof Slip

/// An archival record of something MoveMark recorded: kind, subject, when, what, a RECORDED stamp and a
/// reference. Paper on dark, or paper on the light sheet. Technical metadata stays small and quiet.
struct MMProofSlip: View {
    var kind: String                 // "MOVE-IN RECORD"
    var subject: String              // "Kitchen"
    var timestamp: String            // "Oct 24 · 3:18 PM"
    var lines: [String] = []         // "12 photos", "2 issues documented"
    var stamp: String = "RECORDED"
    var reference: String? = nil     // "MM-28412"

    private static let paper = Color(red: 0.980, green: 0.976, blue: 0.965)   // #FAF9F6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kind.uppercased())
                .mmFont(10.5, .semibold)
                .tracking(1.0)
                .foregroundStyle(MMInk.secondary)
            Text(subject)
                .mmFont(24, .semibold)
                .foregroundStyle(MMInk.text)
                .lineLimit(2)
                .padding(.top, 10)
            Text(timestamp)
                .mmFont(13)
                .monospacedDigit()
                .foregroundStyle(MMInk.secondary)
                .padding(.top, 3)
            if !lines.isEmpty {
                dashed.padding(.vertical, 14)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines, id: \.self) { Text($0).mmFont(14).foregroundStyle(MMInk.text) }
                }
            }
            dashed.padding(.vertical, 14)
            HStack(alignment: .center) {
                Text(stamp.uppercased())
                    .mmFont(11, .bold)
                    .tracking(1.2)
                    .foregroundStyle(MMInk.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(MMInk.text, lineWidth: 1.25))
                    .rotationEffect(.degrees(-3))
                Spacer()
                if let reference {
                    Text("REF \(reference)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MMInk.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.paper, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.75))
        .accessibilityElement(children: .combine)
    }

    private var dashed: some View {
        Line().stroke(MMInk.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path(); p.move(to: CGPoint(x: 0, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p
        }
    }
}

// MARK: - Evidence Tile

/// A photo inside its own clipped frame with a quiet caption underneath — evidence never draws outside its
/// tile. Pass the photo (usually MMEvidenceImage) as content; the tile fixes its size.
struct MMEvidenceTile<Photo: View>: View {
    var caption: String?
    var meta: String? = nil
    var size: CGSize
    var onDark = false
    @ViewBuilder var photo: () -> Photo

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            photo()
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if caption != nil || meta != nil {
                VStack(alignment: .leading, spacing: 1) {
                    if let caption {
                        Text(caption).mmFont(12.5, .medium).foregroundStyle(onDark ? .white : MMInk.text).lineLimit(1)
                    }
                    if let meta {
                        Text(meta).mmFont(11.5).foregroundStyle(onDark ? MMInk.heroSecondary : MMInk.secondary).lineLimit(1)
                    }
                }
                .frame(width: size.width, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Case Card

/// A structured record (a maintenance case, a dispute): eyebrow, title, a quiet status, a grid of facts,
/// then whatever evidence or actions belong to it. White on the light sheet; one per screen top.
struct MMCaseCard<Content: View>: View {
    struct Fact: Identifiable { var id: String { label }; let label: String; let value: String }
    enum Status { case open, resolved, draft, neutral }

    var eyebrow: String              // "MAINTENANCE CASE"
    var title: String
    var status: (String, Status)? = nil
    var facts: [Fact] = []
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow.uppercased()).mmFont(11, .semibold).tracking(0.6).foregroundStyle(MMInk.secondary)
                Spacer()
                if let status { statusMark(status.0, status.1) }
            }
            Text(title)
                .mmFont(22, .semibold)
                .foregroundStyle(MMInk.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            if !facts.isEmpty {
                let columns = dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())]
                    : [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(facts) { fact in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fact.label).mmFont(12).foregroundStyle(MMInk.secondary)
                            Text(fact.value).mmFont(14.5, .medium).foregroundStyle(MMInk.text).fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.top, 16)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous).strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
    }

    private func statusMark(_ text: String, _ status: Status) -> some View {
        HStack(spacing: 6) {
            switch status {
            case .resolved: Circle().fill(MMInk.limeMark).frame(width: 7, height: 7)
            case .open: Circle().strokeBorder(MMInk.warning, lineWidth: 1.5).frame(width: 8, height: 8)
            case .draft, .neutral: Circle().strokeBorder(MMInk.secondary, lineWidth: 1.5).frame(width: 8, height: 8)
            }
            Text(text).mmFont(12.5, .medium).foregroundStyle(MMInk.text)
        }
        .accessibilityElement(children: .combine)
    }
}

extension MMCaseCard where Content == EmptyView {
    init(eyebrow: String, title: String, status: (String, Status)? = nil, facts: [Fact] = []) {
        self.init(eyebrow: eyebrow, title: title, status: status, facts: facts, content: { EmptyView() })
    }
}

// MARK: - Timeline Row

/// One dated event in a chronology: a fixed date column, a thin rail with a mark, the event and a quiet line.
/// Stack them inside an MMPanel; the rail joins between rows.
struct MMTimelineRow: View {
    let date: String                 // "Oct 24"
    let title: String                // "Issue recorded"
    var detail: String? = nil
    var isFirst = false
    var isLast = false
    var isPending = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(date)
                .mmFont(12.5, .medium)
                .monospacedDigit()
                .foregroundStyle(MMInk.secondary)
                .frame(width: 58, alignment: .leading)
                .padding(.top, 1)
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : MMInk.separator).frame(width: 1.5, height: 6)
                Circle()
                    .fill(isPending ? MMInk.card : MMInk.text)
                    .overlay(Circle().strokeBorder(isPending ? MMInk.secondary : MMInk.text, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                Rectangle().fill(isLast ? Color.clear : MMInk.separator).frame(width: 1.5).frame(maxHeight: .infinity)
            }
            .frame(width: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).mmFont(15, isPending ? .regular : .medium).foregroundStyle(isPending ? MMInk.secondary : MMInk.text)
                if let detail { Text(detail).mmFont(13).foregroundStyle(MMInk.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            .padding(.bottom, isLast ? 0 : 16)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Progress Strip

/// Quiet completion, as the Proof header shows it: a label, the count, a thin line. Light or dark.
struct MMProgressStrip: View {
    let label: String                // "Move-out proof"
    let done: Int
    let total: Int
    var unit: String = "rooms"
    var onDark = false

    var body: some View {
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).mmFont(13, .medium).foregroundStyle(onDark ? .white : MMInk.text)
                Spacer()
                Text("\(done) of \(total) \(unit)").mmFont(13).monospacedDigit()
                    .foregroundStyle(onDark ? MMInk.heroSecondary : MMInk.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(onDark ? Color.white.opacity(0.16) : MMInk.separator)
                    Capsule().fill(onDark ? MMInk.limeMark : MMInk.text)
                        .frame(width: done == 0 ? 0 : max(geo.size.width * fraction, 4))
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(done) of \(total) \(unit)")
    }
}

// MARK: - Comparison Pair

/// Before beside after: move-in on the left, move-out on the right, each with its note and date, and the
/// change stated plainly above. Reads as "what existed before vs what exists now", never as a collage.
struct MMComparisonPair<Before: View, After: View>: View {
    enum Change { case unchanged, changed, newIssue, missingAfter }

    let title: String                // "Living Room"
    let change: Change
    var beforeNote: String?
    var beforeDate: String?
    var afterNote: String?
    var afterDate: String?
    var photoHeight: CGFloat = 150
    @ViewBuilder var before: () -> Before
    @ViewBuilder var after: () -> After

    private var changeLabel: (String, Color) {
        switch change {
        case .unchanged: ("Unchanged", MMInk.secondary)
        case .changed: ("Changed", MMInk.warning)
        case .newIssue: ("New issue", MMInk.warning)
        case .missingAfter: ("Move-out proof missing", MMInk.secondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).mmFont(17, .semibold).foregroundStyle(MMInk.text)
                Spacer()
                Text(changeLabel.0).mmFont(12.5, .medium).foregroundStyle(changeLabel.1)
            }
            HStack(alignment: .top, spacing: 10) {
                side("MOVE-IN", note: beforeNote, date: beforeDate, content: before)
                side("MOVE-OUT", note: afterNote, date: afterDate, content: after)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func side<V: View>(_ label: String, note: String?, date: String?, @ViewBuilder content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).mmFont(10.5, .semibold).tracking(0.8).foregroundStyle(MMInk.secondary)
            content()
                .frame(maxWidth: .infinity)
                .frame(height: photoHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            if let note { Text(note).mmFont(13).foregroundStyle(MMInk.text).fixedSize(horizontal: false, vertical: true) }
            if let date { Text(date).mmFont(12).monospacedDigit().foregroundStyle(MMInk.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The empty side of a comparison (no move-out photo yet): a quiet dashed frame, never a fake image.
struct MMMissingPhotoFrame: View {
    var label: String = "Not captured yet"
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(MMInk.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .background(MMInk.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { Text(label).mmFont(12.5).foregroundStyle(MMInk.secondary) }
    }
}
