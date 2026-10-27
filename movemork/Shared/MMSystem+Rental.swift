//
//  MMSystem+Rental.swift
//  movemork
//
//  @file The rental record in the final system: the record screen (dark header carrying the rental and its
//        move-in proof, in the Proof header's language), the rooms block (the next room with the one capture
//        action, then every room with its proof), record rows (Added / Needed with one action), and the
//        loading skeleton that keeps the record's shape. Used by the rental detail, the room list and
//        their sheets so one rental reads the same everywhere.
//  @domain design-system
//  @see [[MMSystem.swift]] [[MMSystem+Property.swift]] [[ProofHomeView.swift]]
//

import SwiftUI

// MARK: - Address

/// How a rental's address reads under its title: "Unit 2304 · Toronto, ON". The street leads only when the
/// title is a nickname rather than the street itself. Never shows a placeholder such as "Unknown".
enum RentalAddress {
    /// "2304" → "Unit 2304"; "Apt 4B", "Unit 2304", "#12", "Suite 300" stay as typed.
    static func unitLabel(_ raw: String) -> String? {
        let unit = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unit.isEmpty else { return nil }
        let lower = unit.lowercased()
        let prefixed = ["unit", "apt", "apartment", "suite", "ste", "#", "floor", "fl ", "ph", "penthouse", "basement", "upper", "lower"]
        return prefixed.contains(where: { lower.hasPrefix($0) }) ? unit : "Unit \(unit)"
    }

    static func line(title: String, street: String, unit: String, city: String, province: String) -> String? {
        let street = street.trimmingCharacters(in: .whitespacesAndNewlines)
        let showsStreet = !street.isEmpty && street.caseInsensitiveCompare(title.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame
        let place = RentalLocation.line(city: city, province: province)
        let first = [showsStreet ? street : nil, unitLabel(unit)].compactMap { $0 }.joined(separator: ", ")
        let parts = [first, place].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Record screen

/// A pushed record screen: the text-only MoveMark mark, an eyebrow, the title, a quiet line or two, and an
/// optional block under them (the move-in proof), then the light working sheet. Keeps the system back button
/// on a dark bar of the header colour.
struct MMRecordScreen<HeaderExtra: View, Content: View>: View {
    var eyebrow: String
    var title: String
    var lines: [String] = []
    @ViewBuilder var headerExtra: () -> HeaderExtra
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 0) {
                    content()
                    Color.clear.frame(height: 40)
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
            Text("MoveMark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
                .accessibilityHidden(true)
            if !dynamicTypeSize.isAccessibilitySize {
                Text(eyebrow.uppercased())
                    .mmFont(11, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(MMInk.heroSecondary)
                    .padding(.top, 18)
            }
            if !title.isEmpty {
                Text(title)
                    .mmFont(27, .semibold)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, dynamicTypeSize.isAccessibilitySize ? 12 : 6)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .mmFont(index == 0 ? 14.5 : 13.5)
                    .foregroundStyle(MMInk.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, index == 0 ? 5 : 2)
            }
            headerExtra()
        }
        .padding(.horizontal, MMMetrics.inset)
        .padding(.bottom, 26 + MMMetrics.sheetRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) { MMInk.hero.frame(height: 2000) }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension MMRecordScreen where HeaderExtra == EmptyView {
    init(eyebrow: String, title: String, lines: [String] = [], @ViewBuilder content: @escaping () -> Content) {
        self.init(eyebrow: eyebrow, title: title, lines: lines, headerExtra: { EmptyView() }, content: content)
    }
}

/// Move-in proof on the dark header, exactly as the Proof header states it: label and percentage, a thin
/// lime line on a dark track, and the count it stands for.
struct MMHeaderProofProgress: View {
    var label = "Move-in proof"
    let done: Int
    let total: Int

    var body: some View {
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).mmFont(12.5, .medium).foregroundStyle(.white)
                Spacer()
                if total > 0 {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .mmFont(12.5, .medium).monospacedDigit().foregroundStyle(MMInk.heroSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16))
                    Capsule().fill(MMInk.limeMark)
                        .frame(width: done == 0 ? 0 : max(geo.size.width * fraction, 4))
                }
            }
            .frame(height: 4)
            Text(total == 0 ? "Add rooms to start" : "\(done) of \(total) rooms documented")
                .mmFont(12.5)
                .monospacedDigit()
                .foregroundStyle(MMInk.heroSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(total == 0 ? "\(label): add rooms to start"
                            : "\(label): \(done) of \(total) rooms documented")
    }
}

// MARK: - Section header

/// A record section's title with a quiet fact on the right ("1 of 3 added"), or a small action ("All rooms").
struct MMRecordSectionHeader: View {
    let title: String
    var detail: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).mmFont(16, .semibold).foregroundStyle(MMInk.text).accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .mmFont(13.5, .medium)
                    .foregroundStyle(MMInk.secondary)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
            } else if let detail {
                Text(detail).mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
            }
        }
    }
}

// MARK: - Rooms

/// One room as the record shows it: what it holds, or that it still needs proof.
struct MMRentalRoom: Identifiable, Equatable {
    let id: UUID
    let name: String
    var photos: Int
    var issues: Int = 0
    var isHighlighted = false

    var isDocumented: Bool { photos > 0 }

    /// "Recorded · 4 photos", "Recorded · 3 photos · 1 issue", or "Needs proof".
    var line: String {
        guard isDocumented else { return "Needs proof" }
        var parts = ["Recorded", photos == 1 ? "1 photo" : "\(photos) photos"]
        if issues > 0 { parts.append(issues == 1 ? "1 issue" : "\(issues) issues") }
        return parts.joined(separator: " · ")
    }
}

extension MMRentalRoom {
    init(_ room: RoomRecord, isHighlighted: Bool = false) {
        self.init(id: room.id, name: room.name, photos: MMRoomProofMetrics.photoCount(for: room),
                  issues: MMRoomProofMetrics.issueCount(for: room), isHighlighted: isHighlighted)
    }
}

/// The rooms of a rental as one object: the next room to document with the single capture action on top,
/// then every other room with its proof (an ink check when recorded, an empty ring while it needs proof).
/// When every room is recorded the top states it and carries `completeAction` instead.
struct MMRentalRoomsBlock: View {
    let rooms: [MMRentalRoom]
    /// The room the capture action opens (usually the first without proof).
    var nextID: UUID?
    /// Show at most this many rooms below the next one; the rest are reached through `onSeeAll`.
    var limit: Int? = nil
    var completeTitle = "Every room documented"
    var completeActionTitle: String? = nil
    var completeAction: (() -> Void)? = nil
    var onCapture: () -> Void
    var onOpenRoom: (UUID) -> Void
    var onSeeAll: (() -> Void)? = nil
    var onAddRoom: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var next: MMRentalRoom? { rooms.first { $0.id == nextID && !$0.isDocumented } }
    /// Below the next room: when the list is capped, rooms still needing proof come first so nothing missing
    /// hides behind "more rooms"; uncapped, the rental's own order.
    private var others: [MMRentalRoom] {
        let rest = rooms.filter { $0.id != next?.id }
        guard limit != nil else { return rest }
        return rest.filter { !$0.isDocumented } + rest.filter(\.isDocumented)
    }
    private var shown: [MMRentalRoom] { limit.map { Array(others.prefix($0)) } ?? others }
    private var hiddenCount: Int { others.count - shown.count }
    private var photoTotal: Int { rooms.reduce(0) { $0 + $1.photos } }

    var body: some View {
        MMGroup {
            if let next { nextBlock(next) } else { completeBlock }
            ForEach(shown) { room in
                MMRowDivider(leading: dynamicTypeSize.isAccessibilitySize ? 16 : 52)
                Button { onOpenRoom(room.id) } label: { row(room) }
                    .buttonStyle(MMLightPressStyle())
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens \(room.name)")
            }
            if hiddenCount > 0, let onSeeAll {
                MMRowDivider(leading: dynamicTypeSize.isAccessibilitySize ? 16 : 52)
                footerButton(title: hiddenCount == 1 ? "1 more room" : "\(hiddenCount) more rooms",
                             icon: "ellipsis", action: onSeeAll)
            }
            if let onAddRoom {
                MMRowDivider(leading: dynamicTypeSize.isAccessibilitySize ? 16 : 52)
                footerButton(title: "Add a room", icon: "plus", action: onAddRoom)
            }
        }
    }

    private func nextBlock(_ room: MMRentalRoom) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { onOpenRoom(room.id) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next room").mmFont(12.5).foregroundStyle(MMInk.secondary)
                    HStack(spacing: 8) {
                        if !dynamicTypeSize.isAccessibilitySize {
                            Image(systemName: RoomGlyph.symbol(for: room.name))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(MMInk.text.opacity(0.7))
                        }
                        Text(room.name).mmFont(20, .semibold).foregroundStyle(MMInk.text)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                            .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                    }
                    Text("No proof yet — photograph it before you unpack.")
                        .mmFont(13).foregroundStyle(MMInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            MMPrimaryButton(title: "Capture \(room.name)", icon: "camera.fill") {
                MMHaptics.soft()
                onCapture()
            }
            .padding(.top, 14)
            .background(MMRowHighlight(isOn: room.isHighlighted).padding(-12))
        }
        .padding(16)
    }

    private var completeBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 17)).foregroundStyle(MMInk.text)
                Text(completeTitle).mmFont(18, .semibold).foregroundStyle(MMInk.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("\(rooms.count == 1 ? "1 room" : "\(rooms.count) rooms") · \(photoTotal == 1 ? "1 photo" : "\(photoTotal) photos") recorded")
                .mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
                .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 25)
            if let completeActionTitle, let completeAction {
                MMPrimaryButton(title: completeActionTitle, icon: "doc.text.fill", action: completeAction)
                    .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .accessibilityElement(children: .contain)
    }

    private func row(_ room: MMRentalRoom) -> some View {
        let isAX = dynamicTypeSize.isAccessibilitySize
        return HStack(spacing: 12) {
            if !isAX {
                Image(systemName: RoomGlyph.symbol(for: room.name))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MMInk.text.opacity(room.isDocumented ? 0.75 : 0.45))
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(room.name).mmFont(16).foregroundStyle(MMInk.text).lineLimit(isAX ? 4 : 2)
                Text(room.line).mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary).lineLimit(isAX ? 3 : 1)
            }
            Spacer(minLength: 8)
            if room.isDocumented {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 17)).foregroundStyle(MMInk.text)
                    .accessibilityLabel("Recorded")
            } else {
                Circle().strokeBorder(MMInk.secondary.opacity(0.5), lineWidth: 1.5).frame(width: 17, height: 17)
                    .accessibilityLabel("Needs proof")
            }
            MMRowChevron()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight, alignment: .leading)
        .background(MMRowHighlight(isOn: room.isHighlighted))
        .contentShape(Rectangle())
    }

    private func footerButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(MMInk.secondary)
                    .frame(width: 24)
                Text(title).mmFont(15.5).foregroundStyle(MMInk.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
    }
}

// MARK: - Records

/// One supporting record (lease, deposit receipt, listing proof): what it is, whether it is on file — with
/// when it was added ("Added Oct 19, 2025") and the file itself on its own quiet line — or why it's worth
/// adding, and one action. The status is a word, never a pill; only "Needed" carries colour.
struct MMRecordRow<Action: View>: View {
    let title: String
    let icon: String
    let isPresent: Bool
    /// Present: the date it was added ("Oct 19, 2025"). Missing: the reason to add it.
    var detail: String? = nil
    /// Present: what the file is ("Harbour-St-lease-2025.pdf", "Image"), truncated in the middle.
    var file: String? = nil
    var isHighlighted = false
    @ViewBuilder var action: () -> Action

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isAX = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: 12) {
            if !isAX {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(MMInk.text.opacity(isPresent ? 0.8 : 0.45))
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).mmFont(16).foregroundStyle(MMInk.text).lineLimit(isAX ? 4 : 2)
                statusLine
                    .mmFont(13)
                    .lineLimit(isAX ? 5 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                if isPresent, let file, !file.isEmpty {
                    Text(file).mmFont(12.5).foregroundStyle(MMInk.secondary)
                        .lineLimit(isAX ? 3 : 1).truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            action()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight + 6, alignment: .leading)
        .background(MMRowHighlight(isOn: isHighlighted))
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.22), value: isHighlighted)
    }

    private var statusLine: Text {
        let lead = Text(isPresent ? "Added" : "Needed")
            .foregroundColor(isPresent ? MMInk.text : MMInk.warning)
        guard let detail, !detail.isEmpty else { return lead }
        return lead + Text(isPresent ? " \(detail)" : " · \(detail)").foregroundColor(MMInk.secondary)
    }
}

/// Dates on supporting records as stored (ISO timestamp, sometimes date-only), shown "Oct 19, 2025".
enum MMRecordDate {
    static func parse(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = full.date(from: raw) { return d }
        full.formatOptions = [.withInternetDateTime]
        if let d = full.date(from: raw) { return d }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(identifier: "UTC")
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: String(raw.prefix(10)))
    }

    static func display(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

// MARK: - Loading

/// The rental record while it loads: the same dark header and sheet with quiet placeholder bars where the
/// rental, its proof and its rooms will be — the layout holds, no spinner on an empty page.
struct MMRentalRecordSkeleton: View {
    var body: some View {
        MMRecordScreen(eyebrow: "Rental record", title: "", headerExtra: {
            VStack(alignment: .leading, spacing: 10) {
                bar(width: 200, height: 24, dark: true).padding(.bottom, 2)
                bar(width: 170, height: 12, dark: true)
                bar(width: nil, height: 4, dark: true).padding(.top, 14)
                bar(width: 140, height: 10, dark: true)
            }
            .padding(.top, 6)
        }) {
            VStack(alignment: .leading, spacing: 12) {
                bar(width: 70, height: 14, dark: false)
                MMGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        bar(width: 80, height: 10, dark: false)
                        bar(width: 150, height: 18, dark: false)
                        Capsule().fill(MMInk.field).frame(height: MMMetrics.ctaHeight).padding(.top, 6)
                    }
                    .padding(16)
                    ForEach(0..<3, id: \.self) { _ in
                        MMRowDivider(leading: 16)
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                bar(width: 120, height: 12, dark: false)
                                bar(width: 90, height: 9, dark: false)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                }
                Text("Opening your rental record…")
                    .mmFont(13).foregroundStyle(MMInk.secondary)
                    .padding(.top, 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Opening your rental record")
    }

    private func bar(width: CGFloat?, height: CGFloat, dark: Bool) -> some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(dark ? Color.white.opacity(0.14) : MMInk.separator)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
