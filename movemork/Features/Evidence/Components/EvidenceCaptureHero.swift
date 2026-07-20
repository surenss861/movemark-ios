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

            if let room {
                moveInVsMoveOutCompare(room: room)
            }
        }
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
