//
//  MoveMarkFlowMessage.swift
//  movemork
//
//  User-facing copy that distinguishes upload vs database vs refresh so saves don’t feel “all failed.”
//

import Foundation

/// Returned after room evidence mutations that re-hydrate the active property.
struct PropertyMutationOutcome: Sendable {
    /// When true, the write likely succeeded but reloading the property snapshot failed; local optimistic state is kept.
    var hydrationRefreshFailed: Bool
}

/// After creating a maintenance issue and refreshing the list.
struct MaintenanceSubmitOutcome: Sendable {
    var inserted: MaintenanceIssueRow
    var listRefreshFailed: Bool
}

enum MoveMarkFlowMessage {

    // MARK: - Local validation / missing state (not from `Error`)

    static let signInRequired = "You need to sign in again."
    static let noActiveProperty = "No active property loaded."
    static let notSignedInPropertyForm = "Not signed in. Please sign in and try again."
    static let notSignedInShort = "Not signed in."
    static let maintenanceIssueNotFound = "This issue couldn’t be found. It may have been removed."
    static let noPropertyOrAuth = "No property or not authenticated."

    static let proofHydrationHint = " If the list looks stale, leave and reopen this room."

    static let proofPreviewTapRetry = "Couldn’t load preview. Tap to retry."

    static let incidentSavedRefreshStale = "Incident saved. If it doesn’t show below, go back and open Maintenance again."

    static let maintenanceEvidencePreviewHint = " Photos are saved; previews may take a moment. Leave and return if images don’t appear."

    static let documentVaultRefreshHint = " File is saved. If the row doesn’t update, leave this vault and open it again."

    static let exportQueuedHint = "Export queued. Open Exports to download when it’s ready—verification can take a moment."

    // MARK: - Likely cause

    static func isLikelyStorageFailure(_ error: Error) -> Bool {
        let lower = error.localizedDescription.lowercased()
        if lower.contains("bucket") || lower.contains("storage") { return true }
        if lower.contains("not found"), lower.contains("object") || lower.contains("bucket") { return true }
        return false
    }

    // MARK: - Room proof

    static func proofSaveFailed(_ error: Error) -> String {
        if isLikelyStorageFailure(error) {
            return "Couldn’t upload photos, so this proof wasn’t saved. Check your connection and try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t save proof. Try again.")
    }

    static func proofUpdateFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t update proof. Try again.")
    }

    static func proofDeleteFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t remove proof. Try again.")
    }

    static func proofAppendPhotosFailed(_ error: Error) -> String {
        if isLikelyStorageFailure(error) {
            return "Couldn’t upload the new photos. Your existing proof is unchanged."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t add photos. Try again.")
    }

    // MARK: - Maintenance

    static func maintenanceComposerFailed(_ error: Error) -> String {
        if isLikelyStorageFailure(error) {
            return "Couldn’t upload photos. The incident may still be saved without images—check the list, or try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t save this incident. Try again.")
    }

    static func maintenanceEvidenceLoadFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t load evidence previews. Try again.")
    }

    static func maintenanceListLoadFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t load maintenance list. Try again.")
    }

    static func maintenancePhotoUploadFailed(_ error: Error) -> String {
        if isLikelyStorageFailure(error) {
            return "Couldn’t upload this photo. Check your connection and try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Photo upload failed. Try again.")
    }

    static func maintenancePhotoRecordFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(
            from: error,
            fallback: "Photo uploaded, but we couldn’t attach it to this issue. Try again."
        )
    }

    static func maintenanceFollowUpFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t save follow-up. Try again.")
    }

    static func maintenanceResolveFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t update status. Try again.")
    }

    // MARK: - Supporting documents

    static func documentUploadFailed(_ error: Error) -> String {
        if isLikelyStorageFailure(error) {
            return "Couldn’t upload the file. Check your connection and try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t upload this document. Try again.")
    }

    static func documentRecordCreateFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(
            from: error,
            fallback: "Couldn’t save the document record. Try uploading again."
        )
    }

    static let documentImageReadFailed = "Couldn’t read this photo. Try another image."

    static let documentPreviewMissing = "No document on file for this slot yet."

    static func documentDeleteFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t remove this document. Try again.")
    }

    static func documentPreviewFailed(_ error: Error) -> String {
        if isLikelyStorageFailure(error) {
            return "Couldn’t open a preview right now. The file may still be saved—try again in a moment."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t open preview. Try again.")
    }

    // MARK: - Exports / API

    static let exportServerFailedHint = "This export didn’t finish on the server. Start a new export from your vault."

    static func exportOrAPIFailed(_ error: Error, fallback: String) -> String {
        UserFacingDatabaseError.message(from: error, fallback: fallback)
    }

    /// Move-out checklist DB save (not export).
    static func moveOutChecklistSaveFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t update move-out checklist. Try again.")
    }

    /// Client-side move-out PDF upload to Supabase `exports` (not Railway API).
    static func moveOutReportExportFailed(_ error: Error) -> String {
        if isLikelyStorageFailure(error) {
            return "Export storage is unavailable right now. Try again soon."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t export move-out report. Try again.")
    }

    /// Local verify (signed URL) failure for an export row — distinct from API verify/download.
    static func exportFileVerificationFailed(_ error: Error) -> String {
        if isLikelyStorageFailure(error) {
            return "Couldn’t verify the file in storage yet. It may still be processing—tap Verify again in a moment."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t verify this export. Try again.")
    }

    // MARK: - Dispute builder

    private static func disputeStorageCopy() -> String {
        "Export storage is unavailable right now. Try again soon."
    }

    static func disputeOperationFailed(_ error: Error, fallback: String) -> String {
        if isLikelyStorageFailure(error) { return disputeStorageCopy() }
        return UserFacingDatabaseError.message(from: error, fallback: fallback)
    }

    static func disputeEvidenceLoadFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t load evidence. Try again.")
    }

    // MARK: - Auth & account

    static func authOperationFailed(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("invalid login") || raw.contains("invalid credentials") || raw.contains("invalid email or password") {
            return "Couldn’t sign in. Check your email and password."
        }
        if raw.contains("email not confirmed") {
            return "Please confirm your email, then try again."
        }
        if raw.contains("already registered") || raw.contains("already been registered") || raw.contains("user already registered") {
            return "This email already has an account. Sign in instead."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t complete sign-in. Try again.")
    }

    static func accountPasswordResetFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t send reset email. Try again.")
    }

    static func accountProfileUpdateFailed(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("not authenticated") || raw.contains("jwt") || raw.contains("session") {
            return "Session expired. Please sign in again."
        }
        if raw.contains("duplicate") || raw.contains("violat") || raw.contains("constraint") {
            return "Couldn’t update profile right now. Try again."
        }
        if raw.contains("permission") || raw.contains("policy") || raw.contains("row-level") {
            return "Your profile couldn’t be updated. Please try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t update your name. Try again.")
    }

    static func onboardingProfileSaveFailed(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("not authenticated") || raw.contains("jwt") || raw.contains("session") {
            return "Session expired. Please sign in again."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t save your name. Try again.")
    }

    // MARK: - Properties & maintenance shell

    static func propertyListLoadFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t load your properties. Try again.")
    }

    static func propertySwitchLoadFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t load this property. Try again.")
    }

    static func maintenanceIssueLookupFailed(_ error: Error) -> String {
        UserFacingDatabaseError.message(from: error, fallback: "Couldn’t load this issue. Try again.")
    }

    // MARK: - Property & room forms

    static func propertyCreateFailed(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("not authenticated") || raw.contains("jwt") || raw.contains("session") {
            return "Session expired. Please sign in again."
        }
        if raw.contains("duplicate") || raw.contains("already exists") {
            return "A property with these details already exists."
        }
        if raw.contains("constraint") || raw.contains("violat") {
            return "Couldn’t create property vault. Please check your details and try again."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t create property vault. Try again.")
    }

    static func propertyUpdateFailed(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("not authenticated") || raw.contains("jwt") || raw.contains("session") {
            return "Session expired. Please sign in again."
        }
        if raw.contains("violat") || raw.contains("constraint") {
            return "Couldn’t update property details. Please check your fields and try again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t update property details. Try again.")
    }

    static func roomAddFailed(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        if raw.contains("duplicate") || raw.contains("already") {
            return "A room with this name already exists."
        }
        if raw.contains("not authenticated") || raw.contains("jwt") || raw.contains("session") {
            return "Session expired. Please sign in again."
        }
        return UserFacingDatabaseError.message(from: error, fallback: "Couldn’t add room. Try again.")
    }
}
