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
            case .missing: "Move-out proof needed"
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

    /// "Oct 24": the two ends of one tenancy read best as short dates side by side.
    static func day(_ date: Date?) -> String? {
        date?.formatted(.dateTime.month(.abbreviated).day())
    }

    /// What changed, in record language only — never a judgement of cause or fault. Built from the move-out
    /// issue tags the move-in record doesn't carry, or the condition ratings. Nil when nothing changed.
    var headline: String? {
        switch state {
        case .newIssue:
            let shown = newTags.prefix(3).joined(separator: ", ")
            let more = newTags.count > 3 ? " and \(newTags.count - 3) more" : ""
            return "New issue recorded: \(shown)\(more)"
        case .changed:
            return conditionLine
        default:
            return nil
        }
    }

    /// "Condition Good → Fair" when the move-out rating is lower than move-in; nil otherwise.
    var conditionLine: String? {
        guard let a = moveInCondition, let b = moveOutCondition, b.conditionMeterValue < a.conditionMeterValue else { return nil }
        return "Condition \(a.rawValue) → \(b.rawValue)"
    }
}

enum MoveOutSide { case moveIn, moveOut }

// MARK: - Header progress

/// Move-out progress in the Proof header's language: label and percentage, a thin lime line on the dark
/// track, and the count it stands for underneath.
struct MoveOutHeaderProgress: View {
    let done: Int
    let total: Int

    var body: some View {
        let fraction = total == 0 ? 0 : Double(done) / Double(total)
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text("Move-out proof").mmFont(12.5, .medium).foregroundStyle(.white)
                Spacer()
                Text("\(Int((fraction * 100).rounded()))%")
                    .mmFont(12.5, .medium).monospacedDigit().foregroundStyle(MMInk.heroSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.16))
                    Capsule().fill(MMInk.limeMark).frame(width: done == 0 ? 0 : max(geo.size.width * fraction, 4))
                }
            }
            .frame(height: 4)
            Text("\(done) of \(total) rooms compared").mmFont(12.5).monospacedDigit().foregroundStyle(MMInk.heroSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Move-out proof: \(done) of \(total) rooms compared")
    }
}

// MARK: - Tally

/// The page's index, read in one glance: how many rooms changed, still need move-out proof, are unchanged.
struct MoveOutTally: View {
    let changed: Int
    let missing: Int
    let unchanged: Int
    /// Jump to that group (0 changed, 1 missing, 2 unchanged).
    var onSelect: (Int) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let items = [("Changed", changed), ("Need proof", missing), ("Unchanged", unchanged)]
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 0))
        layout {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button { onSelect(index) } label: {
                    let itemLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
                        : AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    itemLayout {
                        Text("\(item.1)").mmFont(22, .semibold).monospacedDigit()
                            .foregroundStyle(item.1 == 0 ? MMInk.secondary.opacity(0.6) : MMInk.text)
                        Text(item.0).mmFont(12.5).foregroundStyle(MMInk.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
                .disabled(item.1 == 0)
                .accessibilityElement(children: .combine)
                .accessibilityHint(item.1 == 0 ? "" : "Moves to these rooms.")
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - State mark

/// The state as the first thing read on a room: a small mark and a plain word. Filled amber for a new issue,
/// amber ring for a change, dashed ring for missing proof. Never red.
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

/// What the renter just gained: a room that now has its move-out side. Quiet ink, no celebration.
struct MoveOutJustCompared: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark").font(.system(size: 10.5, weight: .bold))
            Text("Compared just now").mmFont(12, .medium)
        }
        .foregroundStyle(MMInk.text)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Photo side

/// One side's photo: fills the frame the pair gives it, opens the viewer, shows the side's photo count.
private struct MoveOutPhoto: View {
    let photo: EvidencePhoto?
    let count: Int
    let size: CGSize
    let resolve: (String) async -> URL?
    var missingLabel = "Not captured yet"
    let onOpen: () -> Void

    var body: some View {
        if let photo {
            Button(action: onOpen) {
                MMEvidenceImage(path: photo.filePath, resolve: resolve, size: size, placeholder: MMInk.field)
                    .overlay(alignment: .bottomTrailing) {
                        if count > 1 {
                            Text("\(count)")
                                .mmFont(11.5, .semibold).monospacedDigit().foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color.black.opacity(0.55), in: Capsule())
                                .padding(8)
                                .accessibilityLabel("\(count) photos")
                        }
                    }
            }
            .buttonStyle(MMLightPressStyle())
        } else {
            MMMissingPhotoFrame(label: count > 0 ? "\(count) photos" : missingLabel)
        }
    }
}

// MARK: - Inspection spread (changed / new issue)

/// A room whose move-out record differs from move-in: the state, the room, what changed in record language,
/// then MOVE-IN · date and MOVE-OUT · date above large photos side by side, and the renter's move-out note.
struct MoveOutSpreadCard: View {
    let comparison: MoveOutComparison
    let resolve: (String) async -> URL?
    var justCompared = false
    var onOpenPhoto: (MoveOutSide) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var photoHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 200 : 236 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                MoveOutStateMark(state: comparison.state)
                Spacer(minLength: 8)
                if justCompared { MoveOutJustCompared() }
            }
            Text(comparison.roomName)
                .mmFont(21, .semibold)
                .foregroundStyle(MMInk.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)
            if let headline = comparison.headline {
                Text(headline)
                    .mmFont(15.5, .medium)
                    .foregroundStyle(MMInk.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
            }

            MMComparisonPair(
                title: comparison.roomName, change: comparison.state == .newIssue ? .newIssue : .changed,
                beforeNote: comparison.moveInCondition?.rawValue,
                beforeDate: MoveOutComparison.day(comparison.moveInDate),
                afterNote: comparison.moveOutCondition?.rawValue,
                afterDate: MoveOutComparison.day(comparison.moveOutDate),
                photoHeight: photoHeight, showsHeader: false, datesInLabel: true,
                before: { side(.moveIn) },
                after: { side(.moveOut) }
            )
            .padding(.top, 18)

            if !details.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(details, id: \.self) { line in
                        Text(line).mmFont(13.5).foregroundStyle(MMInk.text).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MMInk.field, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 14)
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
        }
    }

    /// What the move-out record adds to the comparison: the renter's move-out note, quoted as recorded, plus
    /// a lower condition when the headline is about a new issue.
    private var details: [String] {
        var lines: [String] = []
        if comparison.state == .newIssue, let condition = comparison.conditionLine { lines.append(condition) }
        if let note = comparison.moveOutText { lines.append("Move-out note: “\(note)”") }
        return lines
    }

    private func side(_ side: MoveOutSide) -> some View {
        MoveOutPhoto(photo: side == .moveIn ? comparison.moveInPhoto : comparison.moveOutPhoto,
                     count: side == .moveIn ? comparison.moveInPhotoCount : comparison.moveOutPhotoCount,
                     size: CGSize(width: 180, height: photoHeight), resolve: resolve, missingLabel: "No photo",
                     onOpen: { onOpenPhoto(side) })
    }
}

// MARK: - Missing move-out proof

/// A room still waiting for its move-out side: the move-in photo it will be compared with beside an empty
/// frame, and the capture action — lime only when it is the screen's one most important action.
struct MoveOutMissingCard: View {
    let comparison: MoveOutComparison
    let resolve: (String) async -> URL?
    var isPrimary = false
    var onOpenPhoto: (MoveOutSide) -> Void = { _ in }
    var onCapture: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MoveOutStateMark(state: .missing)
            Text(comparison.roomName)
                .mmFont(19, .semibold)
                .foregroundStyle(MMInk.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
                .accessibilityAddTraits(.isHeader)

            // The two sides are deliberately unequal: the real move-in photo, then a quiet line for the side
            // that doesn't exist yet — never an empty photo-sized slot competing with real evidence.
            sideLabel("MOVE-IN", date: MoveOutComparison.day(comparison.moveInDate))
                .padding(.top, 12)
            MoveOutPhoto(photo: comparison.moveInPhoto, count: comparison.moveInPhotoCount,
                         size: CGSize(width: 340, height: 150), resolve: resolve, missingLabel: "No photo",
                         onOpen: { onOpenPhoto(.moveIn) })
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 6)
            if let condition = comparison.moveInCondition?.rawValue {
                Text(condition).mmFont(13).foregroundStyle(MMInk.text).padding(.top, 6)
            }

            Rectangle().fill(MMInk.separator).frame(height: 0.75).padding(.top, 14)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                sideLabel("MOVE-OUT", date: nil)
                Text("No proof recorded yet").mmFont(14).foregroundStyle(MMInk.secondary)
                Spacer(minLength: 0)
            }
            .padding(.top, 12)

            if isPrimary {
                MMPrimaryButton(title: "Capture move-out proof", icon: "camera", action: onCapture)
                    .padding(.top, 14)
            } else {
                Button(action: onCapture) {
                    HStack(spacing: 7) {
                        Image(systemName: "camera").font(.system(size: 14, weight: .medium))
                        Text("Capture move-out proof").mmFont(15, .medium)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MMInk.secondary.opacity(0.6))
                    }
                    .foregroundStyle(MMInk.text)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MMLightPressStyle())
                .padding(.top, 6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous)
            .strokeBorder(MMInk.cardStroke, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if comparison.moveInPhoto != nil { Button("View move-in photo") { onOpenPhoto(.moveIn) } }
            Button("Capture move-out proof") { onCapture() }
        }
    }

    private func sideLabel(_ label: String, date: String?) -> some View {
        Text(date.map { "\(label) · \($0.uppercased())" } ?? label)
            .mmFont(10.5, .semibold).tracking(0.8).monospacedDigit().foregroundStyle(MMInk.secondary)
    }
}

// MARK: - Compact row (unchanged / not compared)

/// A room that reads the same at both ends, compressed: "Kitchen · ✓ Unchanged", then both dates. Tapping
/// expands it to the full move-in | move-out pair; each photo there opens the viewer.
struct MoveOutCompactRow: View {
    let comparison: MoveOutComparison
    let resolve: (String) async -> URL?
    var justCompared = false
    var onOpenPhoto: (MoveOutSide) -> Void = { _ in }

    @State private var isExpanded: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(comparison: MoveOutComparison, resolve: @escaping (String) async -> URL?, justCompared: Bool = false,
         initiallyExpanded: Bool = false, onOpenPhoto: @escaping (MoveOutSide) -> Void = { _ in }) {
        self.comparison = comparison
        self.resolve = resolve
        self.justCompared = justCompared
        self.onOpenPhoto = onOpenPhoto
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    private var dates: String {
        let moveIn = MoveOutComparison.day(comparison.moveInDate).map { "Move-in \($0)" }
            ?? (comparison.state == .noBaseline ? "No move-in photos" : nil)
        let moveOut = MoveOutComparison.day(comparison.moveOutDate).map { "Move-out \($0)" }
        return [moveIn, moveOut].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() } } label: { summary }
                .buttonStyle(MMLightPressStyle())
                .accessibilityHint(isExpanded ? "Hides the photos." : "Shows move-in and move-out photos side by side.")
            if isExpanded {
                MMComparisonPair(
                    title: comparison.roomName, change: .unchanged,
                    beforeNote: comparison.moveInCondition?.rawValue,
                    beforeDate: MoveOutComparison.day(comparison.moveInDate),
                    afterNote: comparison.moveOutCondition?.rawValue,
                    afterDate: MoveOutComparison.day(comparison.moveOutDate),
                    photoHeight: 170, showsHeader: false, datesInLabel: true,
                    before: { side(.moveIn) },
                    after: { side(.moveOut) }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .accessibilityActions {
                    if comparison.moveInPhoto != nil { Button("View move-in photo") { onOpenPhoto(.moveIn) } }
                    if comparison.moveOutPhoto != nil { Button("View move-out photo") { onOpenPhoto(.moveOut) } }
                }
            }
        }
    }

    private var summary: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { name; state }
                    VStack(alignment: .leading, spacing: 3) { name; state }
                }
                Text(dates).mmFont(12.5).monospacedDigit().foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MMInk.secondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var name: some View {
        Text(comparison.roomName).mmFont(16, .medium).foregroundStyle(MMInk.text).fixedSize(horizontal: false, vertical: true)
    }

    private var state: some View {
        HStack(spacing: 4) {
            if comparison.state == .unchanged {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
            }
            Text(justCompared ? "\(comparison.state.label) · compared just now" : comparison.state.label)
                .mmFont(13)
        }
        .foregroundStyle(MMInk.secondary)
    }

    private func side(_ side: MoveOutSide) -> some View {
        MoveOutPhoto(photo: side == .moveIn ? comparison.moveInPhoto : comparison.moveOutPhoto,
                     count: side == .moveIn ? comparison.moveInPhotoCount : comparison.moveOutPhotoCount,
                     size: CGSize(width: 170, height: 170), resolve: resolve, missingLabel: "No photo",
                     onOpen: { onOpenPhoto(side) })
    }
}
