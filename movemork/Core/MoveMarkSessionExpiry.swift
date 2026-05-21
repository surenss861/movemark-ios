//
//  MoveMarkSessionExpiry.swift
//  movemork
//
//  Central session-expiry signal so API failures return users to sign-in.
//

import Foundation

extension Notification.Name {
    /// Posted when a data/API error indicates the Supabase session is no longer valid.
    static let moveMarkSessionExpired = Notification.Name("MoveMark.sessionExpired")
}

enum MoveMarkSessionExpiry {
    static func requiresReauthentication(_ error: Error) -> Bool {
        let lower = error.localizedDescription.lowercased()
        if lower.contains("not authenticated")
            || lower.contains("invalid jwt")
            || lower.contains("jwt expired")
            || lower.contains("jwt")
            || lower.contains("session")
            || lower.contains("refresh token") {
            return true
        }
        let ns = error as NSError
        if ns.domain.contains("Auth"), ns.code == 401 { return true }
        return false
    }

    static func notifyIfNeeded(for error: Error) {
        guard requiresReauthentication(error) else { return }
        NotificationCenter.default.post(name: .moveMarkSessionExpired, object: nil)
    }
}
