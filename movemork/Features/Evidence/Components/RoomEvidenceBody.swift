//
//  RoomEvidenceBody.swift
//  movemork
//
//  @file Room body — condition, damage noted, saved entries, add more proof (no stacked cards)
//  @domain proof-capture
//  @status wip
//  @see [[ROOM_EVIDENCE_RECORD]] — screen spec (§4 composition)
//  @see [[RoomEvidenceBody.kt]] — Android counterpart
//

import SwiftUI
import PhotosUI

struct RoomEvidenceBody: View {
    let entries: [EvidenceRecord]
    let moveOutMode: Bool
    let isBusy: Bool
    let onEdit: (EvidenceRecord) -> Void
    let onAddPhotos: (EvidenceRecord) -> Void
    let onDelete: (EvidenceRecord) -> Void

    private var ordered: [EvidenceRecord] { entries.sorted { $0.createdAt > $1.createdAt } }
    private var latest: EvidenceRecord? { ordered.first }
    /// Union of tags across entries, in first-seen order (newest entry first).
    private var damage: [String] {
        var seen = Set<String>()
        return ordered.flatMap(\.issueTags).filter { seen.insert($0).inserted }
    }
    private var notes: [(title: String, text: String)] {
        ordered.compactMap { entry in
            let text = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : (entry.title, text)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let latest {
                conditionRow(latest.condition)
                hairline
            }

            if !damage.isEmpty || !notes.isEmpty {
                damageSection
                hairline
            }

            // Adding evidence lives on the hero ("Add evidence"), so the body ends with the record.
            entriesSection
        }
    }

    // MARK: - Condition

    private func conditionRow(_ condition: RoomRecord.ConditionRating) -> some View {
        HStack(alignment: .center, spacing: 12) {
            sectionLabel("Condition")
            Spacer(minLength: 8)
            Text(condition.rawValue)
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { step in
                    Capsule()
                        .fill(step <= condition.conditionMeterValue
                              ? MoveMarkTheme.Colors.textPrimary.opacity(0.85)
                              : MoveMarkTheme.Colors.textMuted.opacity(0.3))
                        .frame(width: 10, height: 4)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Condition \(condition.rawValue), \(condition.conditionMeterValue) of 5")
    }

    // MARK: - Damage

    private var damageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(damage.isEmpty ? "Notes" : "Damage noted")
            if !damage.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(damage, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Circle().fill(MoveMarkTheme.Colors.semanticWarning).frame(width: 6, height: 6)
                            Text(tag)
                                .font(MoveMarkTheme.Typography.footnoteEmphasis)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(MoveMarkTheme.Colors.semanticWarning.opacity(0.14), in: Capsule())
                    }
                }
            }
            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                VStack(alignment: .leading, spacing: 3) {
                    if notes.count > 1 {
                        Text(note.title)
                            .font(MoveMarkTheme.Typography.footnoteEmphasis)
                            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    }
                    Text(note.text)
                        .font(MoveMarkTheme.Typography.body)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 18)
    }

    // MARK: - Entries

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                sectionLabel(moveOutMode ? "Move-out entries" : "Entries")
                Spacer()
                Text("\(ordered.count)")
                    .font(MoveMarkTheme.Typography.monoMeta)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
            }
            .padding(.bottom, 4)

            ForEach(Array(ordered.enumerated()), id: \.element.id) { index, entry in
                if index > 0 {
                    Rectangle().fill(MoveMarkTheme.Colors.divider.opacity(0.5)).frame(height: 0.5)
                }
                entryRow(entry)
            }
        }
        .padding(.vertical, 18)
    }

    private func entryRow(_ entry: EvidenceRecord) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(2)
                Text(RoomEvidenceHero.recordedFormatter.string(from: entry.createdAt).uppercased())
                    .font(MoveMarkTheme.Typography.monoMeta)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                Text(entrySummary(entry))
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
            Spacer(minLength: 8)
            Menu {
                Button { onEdit(entry) } label: { Label("Edit details", systemImage: "pencil") }
                Button { onAddPhotos(entry) } label: { Label("Add photos", systemImage: "plus.viewfinder") }
                Divider()
                Button(role: .destructive) { onDelete(entry) } label: { Label("Delete entry", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isBusy)
            .accessibilityLabel("Actions for \(entry.title)")
        }
        .padding(.vertical, 10)
    }

    private func entrySummary(_ entry: EvidenceRecord) -> String {
        var parts = [entry.photoCount == 1 ? "1 photo" : "\(entry.photoCount) photos", entry.condition.rawValue]
        if !entry.issueTags.isEmpty {
            parts.append(entry.issueTags.count == 1 ? "1 issue" : "\(entry.issueTags.count) issues")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Helpers

    private var hairline: some View {
        Rectangle().fill(MoveMarkTheme.Colors.divider).frame(height: 0.5)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(MoveMarkTheme.Typography.kicker)
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(MoveMarkTheme.Colors.textMuted)
    }
}
