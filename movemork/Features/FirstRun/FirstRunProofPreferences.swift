//
//  FirstRunProofPreferences.swift
//  movemork
//

import Foundation

enum FirstRunProofPreferences {
    private static func key(userId: UUID) -> String {
        "movemark.firstRunProofCompleted.\(userId.uuidString)"
    }

    static func isComplete(userId: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: key(userId: userId))
    }

    static func markComplete(userId: UUID) {
        UserDefaults.standard.set(true, forKey: key(userId: userId))
    }

    static func clear(userId: UUID) {
        UserDefaults.standard.removeObject(forKey: key(userId: userId))
    }
}
