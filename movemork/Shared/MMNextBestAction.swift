//
//  MMNextBestAction.swift
//  movemork
//
//  Shared “next best button” mapping — one obvious primary CTA per screen state.
//

import Foundation

/// Plain-language primary actions used across MoveMark.
enum MMNextBestAction: Equatable {
    case createVault
    case continueProof
    case addPhotos
    case saveProof
    case addDocs
    case makeReport
    case shareReport
    case tryAgain
    case openVault
    case addRoom
    case reviewRooms
    case upgradeToPro
    case addProperty

    var title: String {
        switch self {
        case .createVault: return "Create vault"
        case .continueProof: return "Continue proof"
        case .addPhotos: return "Add photos"
        case .saveProof: return "Save proof"
        case .addDocs: return "Add docs"
        case .makeReport: return "Make report"
        case .shareReport: return "Share report"
        case .tryAgain: return "Try again"
        case .openVault: return "Open"
        case .addRoom: return "Add room"
        case .reviewRooms: return "Review rooms"
        case .upgradeToPro: return "Upgrade to Pro"
        case .addProperty: return "Add property"
        }
    }
}

enum MMNextBestActionMapper {

  // MARK: - Property workflow

    static func from(propertyNextAction: PropertyStore.PropertyNextAction) -> MMNextBestAction {
        switch propertyNextAction {
        case .captureRoom:
            return .continueProof
        case .uploadDocument:
            return .addDocs
        case .reviewMaintenance:
            return .continueProof
        case .openDisputeBuilder:
            return .openVault
        case .openExports:
            return .makeReport
        case .reviewVault:
            return .openVault
        }
    }

    static func featuredVaultCTA(
        hasProperties: Bool,
        propertyNextAction: PropertyStore.PropertyNextAction?
    ) -> MMNextBestAction {
        guard hasProperties else { return .addProperty }
        if let action = propertyNextAction {
            return from(propertyNextAction: action)
        }
        return .openVault
    }

  // MARK: - Room proof

    static func roomProof(
        roomsEmpty: Bool,
        allRoomsDone: Bool,
        hasNextRoom: Bool
    ) -> MMNextBestAction {
        if roomsEmpty { return .addRoom }
        if allRoomsDone { return .reviewRooms }
        if hasNextRoom { return .continueProof }
        return .addRoom
    }

  // MARK: - Evidence capture

    static func evidenceCapture(
        photoCount: Int,
        isUploading: Bool,
        didJustSave: Bool,
        moveOutMode: Bool
    ) -> MMNextBestAction {
        if isUploading { return .saveProof }
        if didJustSave { return .saveProof }
        if photoCount == 0 { return .addPhotos }
        return moveOutMode ? .saveProof : .saveProof
    }

    static func evidenceSaveBarTitle(
        photoCount: Int,
        isUploading: Bool,
        didJustSave: Bool,
        moveOutMode: Bool
    ) -> String {
        if isUploading { return moveOutMode ? "Saving…" : "Saving…" }
        if didJustSave { return "Saved" }
        if photoCount == 0 { return "Add photos" }
        return moveOutMode ? "Save move-out" : MMNextBestAction.saveProof.title
    }

  // MARK: - Reports

    enum ReportReadiness {
        case noVault
        case notReady
        case readyToMake
        case readyToShare
        case processing
        case failed
    }

    static func report(_ readiness: ReportReadiness) -> MMNextBestAction {
        switch readiness {
        case .noVault: return .openVault
        case .notReady: return .continueProof
        case .readyToMake: return .makeReport
        case .readyToShare: return .shareReport
        case .processing: return .makeReport
        case .failed: return .tryAgain
        }
    }

    static func reportReadiness(
        hasVault: Bool,
        isExportReady: Bool?,
        hasReadyExport: Bool,
        isProcessing: Bool,
        isFailed: Bool
    ) -> ReportReadiness {
        if !hasVault { return .noVault }
        if isFailed { return .failed }
        if isProcessing { return .processing }
        if hasReadyExport { return .readyToShare }
        if isExportReady == true { return .readyToMake }
        return .notReady
    }

  // MARK: - Account / paywall

    static func paywallPlansUnavailable() -> MMNextBestAction {
        .tryAgain
    }
}
