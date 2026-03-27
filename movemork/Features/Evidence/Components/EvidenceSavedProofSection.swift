//
//  EvidenceSavedProofSection.swift
//  movemork
//
//  Saved proof as quiet artifact rows with compact actions.
//

import SwiftUI

struct EvidenceSavedProofSection: View {
    let existingEntries: [EvidenceRecord]
    let moveOutMode: Bool
    let onEdit: (EvidenceRecord) -> Void
    let onAddPhotos: (EvidenceRecord) -> Void
    let onDelete: (EvidenceRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(moveOutMode ? "Saved move-out proof" : "Saved proof")
                .font(MoveMarkTheme.Typography.caption)
                .tracking(1.0)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            if existingEntries.isEmpty {
                MMCard(tone: .quiet, padding: 16, spacing: 8) {
                    Text("No saved proof yet")
                        .font(MoveMarkTheme.Typography.sectionTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Saved entries for this room will appear here.")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(existingEntries) { evidence in
                        savedProofRow(evidence)
                    }
                }
            }
        }
    }

    private func savedProofRow(_ evidence: EvidenceRecord) -> some View {
        MMCard(tone: .quiet, padding: 14, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(evidence.title)
                            .font(MoveMarkTheme.Typography.sectionTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        Text(evidence.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Text("\(evidence.photoCount) photo\(evidence.photoCount == 1 ? "" : "s")")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                }

                if !evidence.issueTags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(evidence.issueTags.prefix(3), id: \.self) { tag in
                            MMPill(text: tag, tone: .warning)
                        }
                    }
                }

                Text(evidence.notes.isEmpty ? "No notes added." : evidence.notes)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text("Condition \(evidence.condition.conditionMeterValue)/5")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                    Spacer()

                    MMButton(
                        title: "Edit",
                        action: { onEdit(evidence) },
                        kind: .quiet,
                        size: .compact,
                        expandsToFillWidth: false
                    )

                    MMButton(
                        title: "Add photos",
                        action: { onAddPhotos(evidence) },
                        kind: .quiet,
                        size: .compact,
                        expandsToFillWidth: false
                    )

                    Button("Delete") {
                        onDelete(evidence)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.9))
                }
            }
        }
    }
}
