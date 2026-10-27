//
//  MMSystem+MoveOut.swift
//  movemork
//
//  @file The Move-out comparison: each room's move-in record (the baseline) beside its move-out record, the
//        change stated plainly first. Built on MMComparisonPair. Holds the honest state rule (see
//        `MoveOutComparison.make(room:)`), the large comparison card for rooms that changed or still need
//        move-out proof, and the compact row for rooms that read the same.
//  @domain move-out
//  @see [[MMSystem+Patterns.swift]]
//

import SwiftUI

// MARK: - Model + state rule

/// One room compared across the tenancy, derived only from the room's real records.
struct MoveOutComparison: Identifiable, Hashable {
    enum State: Hashable {
        case newIssue      // move-out records an issue tag the move-in record doesn't have
        case changed       // move-out condition is worse than move-in condition
        case missing       // no move-out photo yet
        case unchanged     // photographed at both ends, no new issue, condition not worse
        case noBaseline    // move-out photos but no move-in photos, so nothing to compare against

        var label: String {
            switch self {
            case .newIssue: "New issue"
            case .changed: "Changed"
            case .missing: "Move-out proof missing"
            case .unchanged: "Unchanged"
            case .noBaseline: "No move-in baseline"
            }
        }
    }

    let id: UUID
    let roomName: String
    let state: State
    /// All loaded photos per side, newest entry first; the first is the one shown.
    let moveInPhotos: [EvidencePhoto]
    let moveOutPhotos: [EvidencePhoto]
    let moveInPhotoCount: Int
    let moveOutPhotoCount: Int
    let moveInCondition: RoomRecord.ConditionRating?
    let moveOutCondition: RoomRecord.ConditionRating?
    let moveInText: String?
    let moveOutText: String?
    let moveInDate: Date?
    let moveOutDate: Date?
    /// Issue tags recorded at move-out that the move-in record doesn't carry.
    let newTags: [String]

    var moveInPhoto: EvidencePhoto? { moveInPhotos.first }
    var moveOutPhoto: EvidencePhoto? { moveOutPhotos.first }
    var needsAttention: Bool { state == .newIssue || state == .changed }

    /// The comparison state rule, applied in this order:
    ///  1. No move-out photo (`moveOutPhotoTotal == 0`) → **missing**. An entry without photos doesn't count,
    ///     mirroring the server's `not_enough_move_out_proof` guard.
    ///  2. No move-in photo → **noBaseline**: there is nothing to compare against, so no change is claimed.
    ///  3. Any issue tag on a move-out entry that no move-in entry of the room carries (case- and
    ///     space-insensitive) → **newIssue**.
    ///  4. The newest move-out entry's condition rating is lower than the newest move-in entry's → **changed**.
    ///  5. Otherwise → **unchanged**.
    /// Tags and conditions come from the loaded entries (snapshot v2 loads each room's newest entries first);
    /// counts use the server totals. Notes are shown but never interpreted.
    static func make(room: RoomRecord) -> MoveOutComparison {
        let moveIn = room.evidence
        let moveOut = room.moveOutEvidence
        let latestIn = moveIn.first
        let latestOut = moveOut.first

        func key(_ tag: String) -> String { tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let baselineTags = Set(moveIn.flatMap(\.issueTags).map(key))
        var seen = Set<String>()
        let newTags = moveOut.flatMap(\.issueTags).filter { tag in
            let k = key(tag)
            guard !k.isEmpty, !baselineTags.contains(k), !seen.contains(k) else { return false }
            seen.insert(k)
            return true
        }

        let state: State
        if room.moveOutPhotoTotal == 0 {
            state = .missing
        } else if room.moveInPhotoTotal == 0 {
            state = .noBaseline
        } else if !newTags.isEmpty {
            state = .newIssue
        } else if let a = latestIn?.condition, let b = latestOut?.condition, b.conditionMeterValue < a.conditionMeterValue {
            state = .changed
        } else {
            state = .unchanged
        }

        return MoveOutComparison(
            id: room.id, roomName: room.name, state: state,
            moveInPhotos: moveIn.flatMap(\.photos), moveOutPhotos: moveOut.flatMap(\.photos),
            moveInPhotoCount: room.moveInPhotoTotal, moveOutPhotoCount: room.moveOutPhotoTotal,
            moveInCondition: latestIn?.condition, moveOutCondition: latestOut?.condition,
            moveInText: text(of: latestIn, roomName: room.name), moveOutText: text(of: latestOut, roomName: room.name),
            moveInDate: latestIn?.createdAt, moveOutDate: latestOut?.createdAt,
            newTags: newTags
        )
    }

    /// The renter's own words for an entry: its note, else its title — unless it only repeats the room name.
    private static func text(of entry: EvidenceRecord?, roomName: String) -> String? {
        guard let entry else { return nil }
        let room = roomName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for candidate in [entry.notes, entry.title] {
            let t = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, t.lowercased() != room { return t.count > 90 ? String(t.prefix(88)) + "…" : t }
        }
        return nil
    }

    static func day(_ date: Date?) -> String? {
        date?.formatted(.dateTime.month(.abbreviated).day().year())
    }

    /// The note under a side: condition first, then the renter's words.
    static func note(_ condition: RoomRecord.ConditionRating?, _ text: String?) -> String? {
        let parts = [condition?.rawValue, text].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// One plain sentence on what differs; nil when nothing does.
    var changeSentence: String? {
        switch state {
        case .newIssue:
            let list = newTags.prefix(3).joined(separator: ", ")
            let more = newTags.count > 3 ? " and \(newTags.count - 3) more" : ""
            return "Recorded at move-out, not in the move-in record: \(list)\(more)."
        case .changed:
            guard let a = moveInCondition, let b = moveOutCondition else { return nil }
            return "Condition recorded as \(a.rawValue) at move-in and \(b.rawValue) at move-out."
        default:
            return nil
        }
    }
}

enum MoveOutSide { case moveIn, moveOut }

// MARK: - State mark

/// The change state as the first thing read on a comparison: a small mark and a plain word. Amber outline
/// for a difference, a dashed ring for missing proof, a quiet filled dot for unchanged. Never red.
struct MoveOutStateMark: View {
    let state: MoveOutComparison.State

    var body: some View {
        HStack(spacing: 7) {
            mark.frame(width: 9, height: 9)
            Text(state.label.uppercased())
                .mmFont(11.5, .semibold)
                .tracking(0.6)
                .foregroundStyle(state == .newIssue || state == .changed ? MMInk.warning : MMInk.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var mark: some View {
        switch state {
        case .newIssue: Circle().fill(MMInk.warning)
        case .changed: Circle().strokeBorder(MMInk.warning, lineWidth: 1.75)
        case .missing, .noBaseline:
            Circle().strokeBorder(MMInk.secondary, style: StrokeStyle(lineWidth: 1.25, dash: [2, 1.5]))
        case .unchanged: Circle().fill(MMInk.secondary.opacity(0.55))
        }
    }
}

// MARK: - Comparison card

/// A room that changed or still needs move-out proof: the state first, the room, then move-in and move-out
/// side by side at full width. Each photo opens the evidence viewer; a missing side offers capture.
struct MoveOutComparisonCard: View {
    let comparison: MoveOutComparison
    let resolve: (String) async -> URL?
    var onOpenPhoto: (MoveOutSide) -> Void = { _ in }
    var onCapture: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var photoHeight: CGFloat {
        comparison.state == .missing ? 150 : (dynamicTypeSize.isAccessibilitySize ? 170 : 196)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MoveOutStateMark(state: comparison.state)
            Text(comparison.roomName)
                .mmFont(20, .semibold)
                .foregroundStyle(MMInk.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)

            MMComparisonPair(
                title: comparison.roomName, change: .unchanged,
                beforeNote: MoveOutComparison.note(comparison.moveInCondition, comparison.moveInText),
                beforeDate: MoveOutComparison.day(comparison.moveInDate),
                afterNote: comparison.state == .missing ? nil : MoveOutComparison.note(comparison.moveOutCondition, comparison.moveOutText),
                afterDate: comparison.state == .missing ? nil : MoveOutComparison.day(comparison.moveOutDate),
                photoHeight: photoHeight, showsHeader: false,
                before: { side(.moveIn) },
                after: { side(.moveOut) }
            )
            .padding(.top, 14)

            if let sentence = comparison.changeSentence {
                Text(sentence)
                    .mmFont(13.5)
                    .foregroundStyle(MMInk.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MMInk.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 14)
            }

            if comparison.state == .missing {
                Button(action: onCapture) {
                    HStack(spacing: 7) {
                        Image(systemName: "camera").font(.system(size: 14, weight: .medium))
                        Text("Capture move-out").mmFont(15, .medium)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MMInk.secondary.opacity(0.6))
                    }
                    .foregroundStyle(MMInk.text)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
                .padding(.top, 8)
                .accessibilityHint("Opens move-out capture for \(comparison.roomName).")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous)
            .strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if comparison.moveInPhoto != nil { Button("View move-in photo") { onOpenPhoto(.moveIn) } }
            if comparison.moveOutPhoto != nil { Button("View move-out photo") { onOpenPhoto(.moveOut) } }
            if comparison.state == .missing { Button("Capture move-out") { onCapture() } }
        }
    }

    @ViewBuilder
    private func side(_ side: MoveOutSide) -> some View {
        let photo = side == .moveIn ? comparison.moveInPhoto : comparison.moveOutPhoto
        let count = side == .moveIn ? comparison.moveInPhotoCount : comparison.moveOutPhotoCount
        if let photo {
            Button { onOpenPhoto(side) } label: {
                MMEvidenceImage(path: photo.filePath, resolve: resolve, size: CGSize(width: 190, height: photoHeight),
                                placeholder: MMInk.field)
                    .overlay(alignment: .bottomTrailing) {
                        if count > 1 {
                            Text("\(count)")
                                .mmFont(11.5, .semibold)
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.55), in: Capsule())
                                .padding(8)
                                .accessibilityLabel("\(count) photos")
                        }
                    }
            }
            .buttonStyle(MMLightPressStyle())
        } else if side == .moveOut && comparison.state == .missing {
            MMMissingPhotoFrame()
        } else {
            MMMissingPhotoFrame(label: count > 0 ? "\(count) photos" : "No photo")
        }
    }
}

// MARK: - Compact row

/// A room that reads the same at both ends: both photos small and side by side, the room and one quiet line.
/// The row opens the room's move-out capture; each thumbnail opens the viewer.
struct MoveOutCompactRow: View {
    let comparison: MoveOutComparison
    let resolve: (String) async -> URL?
    var onOpenPhoto: (MoveOutSide) -> Void = { _ in }
    var onOpen: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var detail: String {
        switch comparison.state {
        case .noBaseline:
            return "No move-in photos to compare against"
        default:
            let condition = comparison.moveOutCondition.map { "\($0.rawValue) at both ends" } ?? "Same as move-in"
            if let date = MoveOutComparison.day(comparison.moveOutDate) { return "\(condition) · \(date)" }
            return condition
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                thumb(.moveIn)
                thumb(.moveOut)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(comparison.roomName).mmFont(16, .medium).foregroundStyle(MMInk.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                Text(detail).mmFont(13).foregroundStyle(MMInk.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
            }
            Spacer(minLength: 6)
            Button(action: onOpen) {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MMInk.secondary.opacity(0.6))
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MMLightPressStyle())
            .accessibilityLabel("Open \(comparison.roomName) move-out")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onOpen() }
        .accessibilityActions {
            if comparison.moveInPhoto != nil { Button("View move-in photo") { onOpenPhoto(.moveIn) } }
            if comparison.moveOutPhoto != nil { Button("View move-out photo") { onOpenPhoto(.moveOut) } }
        }
    }

    @ViewBuilder
    private func thumb(_ side: MoveOutSide) -> some View {
        let photo = side == .moveIn ? comparison.moveInPhoto : comparison.moveOutPhoto
        let size = CGSize(width: 48, height: 48)
        Group {
            if let photo {
                MMEvidenceImage(path: photo.thumbnailPath ?? photo.filePath, resolve: resolve, size: size, placeholder: MMInk.field)
                    .onTapGesture { onOpenPhoto(side) }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(MMInk.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .background(MMInk.field)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
