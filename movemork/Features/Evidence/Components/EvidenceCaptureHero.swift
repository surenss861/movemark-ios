//
//  EvidenceCaptureHero.swift
//  movemork
//
//  @file Room screen hero — hosts the evidence plate
//  @domain proof-capture
//  @status wip
//  @see [[MMRoomEvidencePlate.swift]] — the plate itself
//  @see [[ROOM_EVIDENCE_RECORD]] — screen spec
//

import SwiftUI

struct EvidenceCaptureHero: View {
    let roomName: String
    let room: RoomRecord?
    let moveOutMode: Bool
    let inspectionRepo: InspectionRepository

    var body: some View {
        MMRoomEvidencePlate(
            roomName: roomName,
            room: room,
            moveOutMode: moveOutMode,
            resolvePhotoURL: { path in
                try? await inspectionRepo.signedURL(bucket: "inspection-media", path: path)
            }
        )
    }
}
