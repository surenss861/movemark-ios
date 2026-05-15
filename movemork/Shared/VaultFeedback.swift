//
//  VaultFeedback.swift
//  movemork
//
//  Lightweight workflow feedback events (presented via MMProofToast).
//

import Foundation

enum VaultFeedbackEvent: Equatable {
    case roomCompleted(roomName: String)
    /// First move-out proof saved for this room (distinct copy from move-in).
    case moveOutRoomCompleted(roomName: String)
    case documentUploaded(documentName: String)
    case readinessImproved(oldScore: Int, newScore: Int)
    case exportsUnlocked
}
