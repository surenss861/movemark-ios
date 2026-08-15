//
//  EvidenceCaptureHero.swift
//  movemork
//
//  Capture header — camera-first, no dashboard hero card.
//

import SwiftUI

struct EvidenceCaptureHero: View {
    let roomName: String
    let room: RoomRecord?
    let moveOutMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MMProofSectionHeader(
                title: "Capture \(roomName)",
                subtitle: moveOutMode
                    ? "Save move-out proof before handing back keys."
                    : "Save move-in proof before anything changes."
            )

            if !moveOutMode {
                shotPrompts
            }

            if let room {
                moveInVsMoveOutCompare(room: room)
            }
        }
    }

    private var shotPrompts: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Proof checklist")
                .font(MoveMarkTheme.Typography.caption)
                .tracking(0.7)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .textCase(.uppercase)

            ForEach(ProofSprint.roomShotPrompts, id: \.self) { prompt in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "camera")
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.9))
                        .frame(width: 14)
                        .padding(.top, 2)

                    Text(prompt)
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.9))
        )
    }

    @ViewBuilder
    private func moveInVsMoveOutCompare(room: RoomRecord) -> some View {
        let moveInPhotos = room.evidence.reduce(0) { $0 + $1.photoCount }
        let moveOutPhotos = room.moveOutEvidence.reduce(0) { $0 + $1.photoCount }

        if moveInPhotos == 0, moveOutPhotos == 0 {
            EmptyView()
        } else {
            Text("Move-in: \(moveInPhotos) photos · Move-out: \(moveOutPhotos) photos")
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
        }
    }
}
