//
//  MMSystem+Maintenance.swift
//  movemork
//
//  @file The maintenance case-file vocabulary on top of the evidence patterns: a case header (eyebrow, title,
//        quiet line, REPORTED label + value, calm status) over the light sheet, the lead evidence photo with its
//        strip, a case chronology row (event over its date and time), a case status mark and the case row the
//        log lists. A documented case with a chronology — never a ticket.
//  @domain design-system
//  @see [[MMSystem+Patterns.swift]]
//

import SwiftUI

// MARK: - Dates

/// Case dates as the record stores them (ISO timestamps, sometimes date-only), shown as "Oct 26 · 8:42 AM".
enum MMCaseDate {
    struct Value { let date: Date; let hasTime: Bool }

    static func parse(_ raw: String?) -> Value? {
        guard let raw, !raw.isEmpty else { return nil }
        let full = ISO8601DateFormatter()
        if let date = full.date(from: raw) { return Value(date: date, hasTime: true) }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return Value(date: date, hasTime: true) }
        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.dateFormat = "yyyy-MM-dd"
        if let date = dayOnly.date(from: String(raw.prefix(10))) { return Value(date: date, hasTime: false) }
        return nil
    }

    static func text(_ date: Date, time: Bool = true) -> String {
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        guard time else { return day }
        return "\(day) · \(date.formatted(date: .omitted, time: .shortened))"
    }

    static func text(_ raw: String?) -> String? {
        parse(raw).map { text($0.date, time: $0.hasTime) }
    }
}

// MARK: - Status

/// A calm case status: a hollow ring while open, a lime dot once resolved. Never red, never a filled pill.
struct MMCaseStatusMark: View {
    enum State { case open, followUp, resolved }
    let state: State
    var onDark = false

    private var label: String {
        switch state {
        case .open: "Open"
        case .followUp: "Follow-up"
        case .resolved: "Resolved"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if state == .resolved {
                Circle().fill(MMInk.limeMark).frame(width: 7, height: 7)
            } else {
                Circle().strokeBorder(onDark ? Color.white.opacity(0.7) : MMInk.secondary, lineWidth: 1.5).frame(width: 8, height: 8)
            }
            Text(label).mmFont(12.5, .medium).foregroundStyle(onDark ? Color.white.opacity(0.85) : MMInk.text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status: \(label)")
    }
}

// MARK: - Case screen

/// The case-file screen: MoveMark's dark header carrying the case itself (eyebrow, title, a quiet line, the
/// REPORTED label + value, the status), then the light working sheet. Pushed; keeps the system back button.
struct MMCaseScreen<Content: View>: View {
    var eyebrow: String = "Maintenance case"
    var title: String
    var line: String?
    var reported: String?
    var status: MMCaseStatusMark.State
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 0) {
                    content()
                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, MMMetrics.inset)
                .padding(.top, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .environment(\.colorScheme, .light)
                .tint(MMInk.text)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: MMMetrics.sheetRadius, topTrailingRadius: MMMetrics.sheetRadius,
                                           style: .continuous).fill(MMInk.sheet)
                )
                .padding(.top, -MMMetrics.sheetRadius)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(MMInk.hero.ignoresSafeArea(edges: .top))
        }
        .background(MMInk.sheet.ignoresSafeArea())
        .toolbarBackground(MMInk.hero, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(eyebrow.uppercased())
                    .mmFont(11, .semibold)
                    .tracking(0.8)
                    .foregroundStyle(MMInk.heroSecondary)
                Spacer(minLength: 12)
                MMCaseStatusMark(state: status, onDark: true)
            }
            .padding(.top, 6)
            Text(title)
                .mmFont(27, .semibold)
                .foregroundStyle(.white)
                .lineLimit(4)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 8)
            if let line, !line.isEmpty {
                Text(line)
                    .mmFont(15)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.top, 4)
            }
            if let reported {
                VStack(alignment: .leading, spacing: 3) {
                    Text("REPORTED").mmFont(10.5, .semibold).tracking(0.8).foregroundStyle(MMInk.heroSecondary)
                    Text(reported).mmFont(14.5, .medium).monospacedDigit().foregroundStyle(.white)
                }
                .accessibilityElement(children: .combine)
                .padding(.top, 18)
            }
        }
        .padding(.horizontal, MMMetrics.inset)
        .padding(.bottom, 28 + MMMetrics.sheetRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) { MMInk.hero.frame(height: 2000) }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

// MARK: - Case chronology

/// One event in a case chronology: a rail mark (filled when it happened, hollow while pending), the event,
/// its date and time underneath, and an optional quiet line. Stack inside an MMPanel; the rail joins.
struct MMCaseTimelineRow: View {
    let title: String
    var date: String? = nil
    var detail: String? = nil
    var isFirst = false
    var isLast = false
    var isPending = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : MMInk.separator).frame(width: 1.5, height: 5)
                Circle()
                    .fill(isPending ? MMInk.card : MMInk.text)
                    .overlay(Circle().strokeBorder(isPending ? MMInk.secondary : MMInk.text, lineWidth: 1.5))
                    .frame(width: 10, height: 10)
                Rectangle().fill(isLast ? Color.clear : MMInk.separator).frame(width: 1.5).frame(maxHeight: .infinity)
            }
            .frame(width: 10)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .mmFont(15.5, isPending ? .regular : .semibold)
                    .foregroundStyle(isPending ? MMInk.secondary : MMInk.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let date {
                    Text(date).mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
                }
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .mmFont(14)
                        .foregroundStyle(MMInk.text.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 3)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isPending ? "Pending" : "")
    }
}

// MARK: - Lead evidence

/// The case's lead photo: full width in its own clipped tile, 4:3, tap to open the viewer. The photo is
/// passed in (usually MMEvidenceImage) so tests and screens share the pipeline.
struct MMCaseLeadPhoto<Photo: View>: View {
    var accessibilityLabel: String
    var action: () -> Void
    @ViewBuilder var photo: () -> Photo

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { photo() }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.75))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the photo viewer")
    }
}

/// A small clipped thumbnail for the case strip and the log rows.
struct MMCaseThumb<Photo: View>: View {
    var side: CGFloat = 64
    @ViewBuilder var photo: () -> Photo

    var body: some View {
        photo()
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.black.opacity(0.06), lineWidth: 0.75))
    }
}

// MARK: - Case row (log)

/// One case in the log: an evidence thumbnail when the case has one (never a stand-in photo), the title,
/// a quiet line (category · reported date), photo count and the calm status.
struct MMCaseRow<Thumb: View>: View {
    let title: String
    var line: String
    var photoCount: Int
    var status: MMCaseStatusMark.State
    var hasThumb: Bool
    @ViewBuilder var thumb: () -> Thumb

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if hasThumb && !dynamicTypeSize.isAccessibilitySize {
                MMCaseThumb(side: 60) { thumb() }
            } else if !dynamicTypeSize.isAccessibilitySize {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MMInk.field)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "doc.text").font(.system(size: 18, weight: .light)).foregroundStyle(MMInk.secondary)
                    }
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .mmFont(16, .semibold)
                    .foregroundStyle(MMInk.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(line)
                    .mmFont(13)
                    .monospacedDigit()
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    MMCaseStatusMark(state: status)
                    Text(photoCount == 0 ? "No photos" : photoCount == 1 ? "1 photo" : "\(photoCount) photos")
                        .mmFont(12.5)
                        .monospacedDigit()
                        .foregroundStyle(MMInk.secondary)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MMInk.secondary.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
