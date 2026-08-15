//
//  ProofSprintChecklistCard.swift
//  movemork
//
//  Move-in Proof Sprint checklist — rooms + lease/deposit protection steps.
//

import SwiftUI

struct ProofSprintChecklistCard: View {
    let property: PropertyRecord
    let onSelectRoom: (RoomRecord) -> Void
    let onAddDocs: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ProofSprint.title)
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text(ProofSprint.estimatedTimeLine)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.95))

                Text(ProofSprint.subtitle)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(progressLine)
                .font(MoveMarkTheme.Typography.footnoteEmphasis)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            VStack(spacing: 8) {
                ForEach(Array(ProofSprint.roomTargets.enumerated()), id: \.element.id) { index, target in
                    roomRow(index: index + 1, target: target)
                }

                ForEach(Array(ProofSprint.documentTargets.enumerated()), id: \.element.id) { index, target in
                    documentRow(
                        index: ProofSprint.roomTargets.count + index + 1,
                        target: target
                    )
                }
            }
        }
        .padding(16)
        .mmProofCardSurface(.neutral, cornerRadius: 20)
    }

    private var progressLine: String {
        let roomsDone = ProofSprint.roomTargets.filter { target in
            guard let room = ProofSprint.matchingRoom(for: target, in: property.rooms) else { return false }
            return ProofSprint.isRoomDocumented(room)
        }.count
        let docsDone = ProofSprint.documentTargets.filter {
            ProofSprint.isDocumentUploaded($0.documentType, in: property)
        }.count
        let total = ProofSprint.roomTargets.count + ProofSprint.documentTargets.count
        let done = roomsDone + docsDone
        let photos = property.rooms.reduce(0) { $0 + MMRoomProofMetrics.photoCount(for: $1) }
        let issues = property.rooms.reduce(0) { $0 + MMRoomProofMetrics.issueCount(for: $1) }
        return "\(done) of \(total) steps · \(photos) photos · \(issues) issues tagged"
    }

    @ViewBuilder
    private func roomRow(index: Int, target: ProofSprint.RoomTarget) -> some View {
        let matched = ProofSprint.matchingRoom(for: target, in: property.rooms)
        let done = matched.map(ProofSprint.isRoomDocumented) ?? false

        Button {
            if let matched {
                onSelectRoom(matched)
            }
        } label: {
            sprintRowLabel(
                index: index,
                title: target.title,
                subtitle: matched == nil
                    ? "Add this room to your vault"
                    : (done ? "Documented" : "Tap to capture"),
                isDone: done,
                isEnabled: matched != nil
            )
        }
        .buttonStyle(.plain)
        .disabled(matched == nil)
    }

    @ViewBuilder
    private func documentRow(index: Int, target: ProofSprint.DocumentTarget) -> some View {
        let done = ProofSprint.isDocumentUploaded(target.documentType, in: property)

        Button(action: onAddDocs) {
            sprintRowLabel(
                index: index,
                title: target.title,
                subtitle: done ? "Added" : target.reason,
                isDone: done,
                isEnabled: true
            )
        }
        .buttonStyle(.plain)
    }

    private func sprintRowLabel(
        index: Int,
        title: String,
        subtitle: String,
        isDone: Bool,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .frame(width: 18, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MoveMarkTheme.Typography.bodySmallEmphasis)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(MoveMarkTheme.Typography.subtitleLarge)
                .foregroundStyle(
                    isDone
                        ? MoveMarkTheme.Colors.primary
                        : MoveMarkTheme.Colors.textSecondary.opacity(isEnabled ? 0.45 : 0.25)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isDone
                        ? MoveMarkTheme.Colors.primary.opacity(0.10)
                        : MoveMarkTheme.Colors.card.opacity(0.88)
                )
        )
        .opacity(isEnabled ? 1 : 0.72)
    }
}
