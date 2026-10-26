//
//  MMSystem+Property.swift
//  movemork
//
//  @file The rental and its rooms in the final system: native grouped rows for rooms, records and the proof
//        trail, a thin ink progress line, and the small one-word action a record row carries. Built on
//        MMSystem (tokens, MMGroup, MMRowDivider); used by the rental detail and the room list.
//  @domain design-system
//  @see [[MMSystem.swift]]
//

import SwiftUI

/// What a row's status says, and how loudly: done is ink, needed / next is amber, failed is red.
enum MMRowStatusTone {
    case done, needed, next, failed, neutral

    var color: Color {
        switch self {
        case .done: MMInk.text
        case .needed, .next: MMInk.warning
        case .failed: MMInk.danger
        case .neutral: MMInk.secondary
        }
    }
}

/// Evidence completeness on the light sheet: a thin ink line on a quiet track.
struct MMProgressLine: View {
    let fraction: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(1, max(0, fraction)) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(MMInk.separator)
                Capsule().fill(MMInk.text)
                    .frame(width: clamped == 0 ? 0 : max(geo.size.width * clamped, 4))
                    .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clamped)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// The one-word action a record row carries (View, Add, Upload): quiet filled capsule, ink text.
struct MMRowActionLabel: View {
    let title: String
    var isBusy = false

    var body: some View {
        HStack(spacing: 6) {
            if isBusy { ProgressView().controlSize(.mini).tint(MMInk.secondary) }
            Text(isBusy ? "Saving…" : title).lineLimit(1)
        }
        .fixedSize()
        .mmFont(14, .semibold)
        .foregroundStyle(MMInk.text)
        .padding(.horizontal, 12)
        .frame(minHeight: 30)
        .background(MMInk.field, in: Capsule())
        .contentShape(Capsule())
    }
}

/// A grouped row with a status: icon, title, subtitle, status word, and a trailing control or chevron.
/// `isHighlighted` marks the row that just changed (a quiet fill, never a colour wash).
struct MMStatusRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var status: String? = nil
    var tone: MMRowStatusTone = .neutral
    var isHighlighted = false
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isAX = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: 12) {
            if let icon, !isAX {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MMInk.text.opacity(0.75))
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).mmFont(16).foregroundStyle(MMInk.text)
                    .lineLimit(isAX ? 4 : 2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).mmFont(13).foregroundStyle(MMInk.secondary)
                        .lineLimit(isAX ? 5 : 2)
                }
                if isAX, let status { statusLabel(status) }
            }
            Spacer(minLength: 8)
            if !isAX, let status { statusLabel(status) }
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight, alignment: .leading)
        .background(MMRowHighlight(isOn: isHighlighted))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.22), value: isHighlighted)
    }

    private func statusLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            if tone == .done {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
            }
            Text(text)
        }
        .mmFont(13, .medium)
        .foregroundStyle(tone.color)
        .lineLimit(1)
        .fixedSize()
    }
}

extension MMStatusRow where Trailing == MMRowChevron {
    init(title: String, subtitle: String? = nil, icon: String? = nil, status: String? = nil,
         tone: MMRowStatusTone = .neutral, isHighlighted: Bool = false) {
        self.init(title: title, subtitle: subtitle, icon: icon, status: status, tone: tone,
                  isHighlighted: isHighlighted, trailing: { MMRowChevron() })
    }
}

/// The row that just changed: a quiet inset fill inside the group, never past its rounded corners.
struct MMRowHighlight: View {
    let isOn: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isOn ? MMInk.field : Color.clear)
            .padding(4)
    }
}

struct MMRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
            .foregroundStyle(MMInk.secondary.opacity(0.6))
    }
}

/// A room in a list: its kind's glyph, name, what it holds, and its state. The next room carries "Next";
/// a documented room an ink check; the rest stay quiet.
struct MMRoomRow: View {
    enum RoomState { case documented, next, todo }

    let name: String
    let detail: String
    let state: RoomState
    var isHighlighted = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isAX = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: 12) {
            if !isAX {
                Image(systemName: RoomGlyph.symbol(for: name))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MMInk.text.opacity(state == .todo ? 0.5 : 0.75))
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .mmFont(16, state == .next ? .semibold : .regular)
                    .foregroundStyle(MMInk.text)
                    .lineLimit(isAX ? 4 : 2)
                Text(detail).mmFont(13).foregroundStyle(MMInk.secondary).lineLimit(isAX ? 4 : 1)
            }
            Spacer(minLength: 8)
            switch state {
            case .documented:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(MMInk.text)
                    .accessibilityLabel("Documented")
            case .next:
                Text("Next").mmFont(13, .semibold).foregroundStyle(MMInk.warning)
            case .todo:
                EmptyView()
            }
            MMRowChevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight, alignment: .leading)
        .background(MMRowHighlight(isOn: isHighlighted))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.22), value: isHighlighted)
    }
}

/// One step of the proof trail: a status glyph, what happened or is missing, when.
struct MMTrailRow: View {
    let icon: String
    let title: String
    let message: String
    var timestamp: String? = nil
    var tone: MMRowStatusTone = .done
    var isHighlighted = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isAX = dynamicTypeSize.isAccessibilitySize
        HStack(alignment: .top, spacing: 12) {
            if !isAX {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(tone == .done ? MMInk.text.opacity(0.75) : tone.color)
                    .frame(width: 24)
                    .padding(.top, 1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).mmFont(15.5).foregroundStyle(MMInk.text).fixedSize(horizontal: false, vertical: true)
                Text(message).mmFont(13).foregroundStyle(MMInk.secondary).fixedSize(horizontal: false, vertical: true)
                if isAX, let timestamp, !timestamp.isEmpty {
                    Text(timestamp).mmFont(12.5).foregroundStyle(MMInk.secondary)
                }
            }
            Spacer(minLength: 8)
            if !isAX, let timestamp, !timestamp.isEmpty {
                Text(timestamp).mmFont(12.5).monospacedDigit().foregroundStyle(MMInk.secondary).fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MMRowHighlight(isOn: isHighlighted))
        .accessibilityElement(children: .combine)
        .animation(.easeInOut(duration: 0.22), value: isHighlighted)
    }
}

extension MMProofTimelineRow.Status {
    /// The trail's status in the final system's tones (no green).
    var rowTone: MMRowStatusTone {
        switch self {
        case .done: .done
        case .next: .next
        case .missing: .needed
        case .failed: .failed
        }
    }
}

/// The "Opening…" overlay while a record is fetched for preview: a dim, and one small white panel.
struct MMBusyOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView().controlSize(.regular).tint(MMInk.secondary)
                Text(message).mmFont(14).foregroundStyle(MMInk.text)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
            .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
            .environment(\.colorScheme, .light)
        }
        .accessibilityElement(children: .combine)
    }
}
