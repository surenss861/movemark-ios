//
//  UserFacingDatabaseError.swift
//  movemork
//

import Foundation

/// Maps Supabase/Postgres errors to short, actionable copy. Prefer this over ad-hoc string checks per screen.
enum UserFacingDatabaseError {

    /// Whether the failing operation was primarily reading or mutating data. Used for RLS / policy copy.
    enum Intent: Sendable {
        /// SELECT / list / refresh / preview / verify.
        case load
        /// INSERT / UPDATE / DELETE / upload.
        case mutate
    }

    /// - Parameters:
    ///   - error: Underlying error from client SDK.
    ///   - fallback: Message when no known pattern matches.
    ///   - intent: Distinguishes load vs save permission errors (RLS). Defaults to `.load` so accidental omissions skew toward “couldn’t load,” not a false “couldn’t save.”
    static func message(from error: Error, fallback: String, intent: Intent = .load) -> String {
        let lower = error.localizedDescription.lowercased()

        if MoveMarkSessionExpiry.requiresReauthentication(error) {
            MoveMarkSessionExpiry.notifyIfNeeded(for: error)
            return "Session expired. Please sign in again."
        }

        if lower.contains("row-level security")
            || lower.contains("row level security")
            || lower.contains("violates row-level security")
            || lower.contains("42501")
            || lower.contains("permission denied for table")
            || (lower.contains("permission denied") && lower.contains("policy")) {
            switch intent {
            case .load:
                return "Couldn’t load this data. Your account doesn’t have access — try signing out and back in."
            case .mutate:
                return "Couldn’t save: your account isn’t allowed to write this data right now. Try signing out and back in."
            }
        }

        if lower.contains("bucket")
            || lower.contains("storage")
            || (lower.contains("not found") && (lower.contains("object") || lower.contains("bucket"))) {
            return "Upload storage is unavailable right now. Try again soon."
        }

        if lower.contains("check constraint")
            || lower.contains("foreign key")
            || lower.contains("type_check")
            || lower.contains("_fkey")
            || lower.contains("violates check") {
            return "Couldn’t save: the server rejected this data. Try again."
        }

        if lower.contains("network")
            || lower.contains("offline")
            || lower.contains("internet")
            || lower.contains("connection")
            || lower.contains("timed out")
            || lower.contains("timeout") {
            return "No connection. Check your internet and try again."
        }

        return fallback
    }
}
