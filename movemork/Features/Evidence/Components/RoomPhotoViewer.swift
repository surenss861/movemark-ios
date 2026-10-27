//
//  RoomPhotoViewer.swift
//  movemork
//
//  @file Evidence viewer — full-screen dark, the photo first; under it a quiet record bar (subject, phase,
//        recorded date-time, photo n of m, the entry's condition, issue tags and notes when present), the
//        filmstrip, close. Used for room photos and maintenance case photos.
//  @domain proof-capture
//  @status wip
//  @see [[ROOM_EVIDENCE_RECORD]] — screen spec (§4, many photos)
//  @see [[RoomProofScreen.kt]] — Android counterpart (RoomPhotoViewer)
//

import SwiftUI

struct RoomPhotoViewer: View {
    /// What the record says about one photo. Every field is optional: the bar shows only what exists.
    struct Caption: Hashable {
        var entryTitle: String? = nil
        var phase: String? = nil
        var date: Date? = nil
        /// "Recorded" for the time MoveMark received it, "Captured" for a source's own declared time.
        var dateVerb: String = "Recorded"
        var condition: String? = nil
        var tags: [String] = []
        var notes: String? = nil
    }

    let photos: [EvidencePhoto]
    let startID: UUID
    /// The room or case the photos belong to.
    var subject: String?
    var captions: [UUID: Caption]
    let resolvePhotoURL: (String) async -> URL?
    let onClose: () -> Void

    @State private var selection: UUID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(photos: [EvidencePhoto], startID: UUID, subject: String? = nil, captions: [UUID: Caption] = [:],
         resolvePhotoURL: @escaping (String) async -> URL?, onClose: @escaping () -> Void) {
        self.photos = photos
        self.startID = startID
        self.subject = subject
        self.captions = captions
        self.resolvePhotoURL = resolvePhotoURL
        self.onClose = onClose
        _selection = State(initialValue: startID)
    }

    /// Captions for a room's photos from its entries (phase, recorded time, condition, tags, notes).
    static func captions(for entries: [EvidenceRecord]) -> [UUID: Caption] {
        var result: [UUID: Caption] = [:]
        for entry in entries {
            let notes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
            for photo in entry.photos {
                result[photo.id] = Caption(
                    entryTitle: title.isEmpty ? nil : title,
                    phase: entry.stage.rawValue,
                    date: MMCaseDate.parse(photo.serverCreatedAt)?.date ?? entry.createdAt,
                    condition: entry.condition.rawValue,
                    tags: entry.issueTags,
                    notes: notes.isEmpty ? nil : notes
                )
            }
        }
        return result
    }

    private var index: Int { photos.firstIndex(where: { $0.id == selection }) ?? 0 }
    private var caption: Caption? { captions[selection] }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $selection) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                    MMEvidenceImage(path: photo.filePath, resolve: resolvePhotoURL, placeholder: MMInk.evidence, fit: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement()
                        .accessibilityLabel(pageLabel(offset: offset, photo: photo))
                        .accessibilityAddTraits(.isImage)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)

            recordBar
            if photos.count > 1 { filmstrip }
        }
        .background(MMInk.evidence.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(MMInk.evidenceRaised, in: Circle())
                    .overlay(Circle().strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
            }
            .accessibilityLabel("Close")
            Spacer()
            Text("\(index + 1) of \(photos.count)")
                .mmFont(13.5, .medium)
                .monospacedDigit()
                .foregroundStyle(MMInk.heroSecondary)
                .contentTransition(.numericText())
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .accessibilityLabel("Photo \(index + 1) of \(photos.count)")
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: Record bar

    @ViewBuilder
    private var recordBar: some View {
        let lines = metaLine
        if subject != nil || caption != nil {
            VStack(alignment: .leading, spacing: 0) {
                if let phase = caption?.phase {
                    Text(phase.uppercased())
                        .mmFont(10.5, .semibold)
                        .tracking(0.9)
                        .foregroundStyle(MMInk.heroSecondary)
                }
                if let heading {
                    Text(heading)
                        .mmFont(17, .semibold)
                        .foregroundStyle(.white)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                        .padding(.top, 4)
                }
                if !lines.isEmpty {
                    Text(lines)
                        .mmFont(12.5)
                        .monospacedDigit()
                        .foregroundStyle(MMInk.heroSecondary)
                        .padding(.top, 3)
                }
                if let caption, !caption.tags.isEmpty {
                    tagRow(caption.tags).padding(.top, 10)
                }
                if let notes = caption?.notes {
                    Text(notes)
                        .mmFont(14)
                        .foregroundStyle(Color.white.opacity(0.82))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 6 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, photos.count > 1 ? 12 : 20)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .accessibilityElement(children: .combine)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selection)
        }
    }

    private var heading: String? {
        var parts = [subject, caption?.entryTitle].compactMap { $0 }.filter { !$0.isEmpty }
        // An entry titled after its room says the room once.
        if parts.count == 2, parts[0].caseInsensitiveCompare(parts[1]) == .orderedSame { parts.removeLast() }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var metaLine: String {
        var parts: [String] = []
        if let date = caption?.date { parts.append("\(caption?.dateVerb ?? "Recorded") \(MMCaseDate.text(date))") }
        if let condition = caption?.condition { parts.append("Condition \(condition)") }
        return parts.joined(separator: "  ·  ")
    }

    private func tagRow(_ tags: [String]) -> some View {
        TagFlow(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .mmFont(12.5, .medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Issues: \(tags.joined(separator: ", "))")
    }

    private func pageLabel(offset: Int, photo: EvidencePhoto) -> String {
        var parts = ["Photo \(offset + 1) of \(photos.count)"]
        if let subject { parts.append(subject) }
        if let c = captions[photo.id] {
            if let phase = c.phase { parts.append(phase) }
            if let date = c.date { parts.append("\(c.dateVerb) \(MMCaseDate.text(date))") }
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Filmstrip

    private var filmstrip: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                        ViewerThumb(photo: photo, isSelected: photo.id == selection, resolvePhotoURL: resolvePhotoURL)
                            .id(photo.id)
                            .onTapGesture {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { selection = photo.id }
                            }
                            .accessibilityLabel("Photo \(offset + 1)")
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: selection) { _, id in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { reader.scrollTo(id, anchor: .center) }
            }
        }
        .padding(.bottom, 10)
    }
}

/// Wraps issue tags onto as many lines as they need (no sideways scrolling in the record bar).
private struct TagFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct ViewerThumb: View {
    let photo: EvidencePhoto
    let isSelected: Bool
    let resolvePhotoURL: (String) async -> URL?

    var body: some View {
        MMEvidenceImage(path: photo.thumbnailPath ?? photo.filePath, resolve: resolvePhotoURL,
                        size: CGSize(width: 48, height: 48), placeholder: MMInk.evidenceRaised)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.9) : MMInk.evidenceStroke, lineWidth: isSelected ? 1.5 : 0.75)
            )
            .opacity(isSelected ? 1 : 0.55)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
