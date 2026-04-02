//
//  UserFacingDatabaseError.swift
//  movemork
//

import Foundation

/// Maps Supabase/Postgres errors to short, actionable copy. Prefer this over ad-hoc string checks per screen.
enum UserFacingDatabaseError {

    /// - Parameters:
    ///   - error: Underlying error from client SDK.
    ///   - fallback: Message when no known pattern matches.
    static func message(from error: Error, fallback: String) -> String {
        let lower = error.localizedDescription.lowercased()

        if lower.contains("not authenticated")
            || lower.contains("invalid jwt")
            || lower.contains("jwt")
            || lower.contains("session")
            || lower.contains("refresh token") {
            return "Session expired. Please sign in again."
        }

        if lower.contains("row-level security")
            || lower.contains("row level security")
            || lower.contains("violates row-level security")
            || lower.contains("42501")
            || lower.contains("permission denied for table")
            || (lower.contains("permission denied") && lower.contains("policy")) {
            return "Couldn’t save: your account isn’t allowed to write this data right now. Try signing out and back in."
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
