//
//  MoveMarkAnalytics.swift
//  movemork
//
//  Activation funnel events — observe → experiment → measure.
//

import Foundation
import OSLog

enum MoveMarkAnalytics {
    private static let log = Logger(subsystem: "movemark.movemork", category: "Analytics")

    enum Event: String {
        case appOpened = "app_opened"
        case onboardingStarted = "onboarding_started"
        case rentalMomentSelected = "rental_moment_selected"
        case proofVaultCreated = "proof_vault_created"
        case roomStarted = "room_started"
        case photoAdded = "photo_added"
        case issueTagged = "issue_tagged"
        case noteAdded = "note_added"
        case receiptAdded = "receipt_added"
        case leaseAdded = "lease_added"
        case proofScoreReached50 = "proof_score_reached_50"
        case proofScoreReached80 = "proof_score_reached_80"
        case reportGenerated = "report_generated"
        case reportShared = "report_shared"
        case paywallViewed = "paywall_viewed"
        case purchaseStarted = "purchase_started"
        case purchaseCompleted = "purchase_completed"
    }

    static func track(_ event: Event, properties: [String: String] = [:]) {
        if properties.isEmpty {
            log.notice("event=\(event.rawValue, privacy: .public)")
        } else {
            let flat = properties
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: " ")
            log.notice("event=\(event.rawValue, privacy: .public) \(flat, privacy: .public)")
        }

        #if DEBUG
        var payload = properties
        payload["event"] = event.rawValue
        payload["ts"] = ISO8601DateFormatter().string(from: Date())
        var history = UserDefaults.standard.array(forKey: debugHistoryKey) as? [[String: String]] ?? []
        history.append(payload)
        if history.count > 200 {
            history = Array(history.suffix(200))
        }
        UserDefaults.standard.set(history, forKey: debugHistoryKey)
        #endif
    }

    static func trackProofScoreIfNeeded(_ score: Int, propertyId: UUID) {
        let key50 = "MoveMark.analytics.proofScore50.\(propertyId.uuidString)"
        let key80 = "MoveMark.analytics.proofScore80.\(propertyId.uuidString)"
        if score >= 50, !UserDefaults.standard.bool(forKey: key50) {
            UserDefaults.standard.set(true, forKey: key50)
            track(.proofScoreReached50, properties: ["score": "\(score)"])
        }
        if score >= 80, !UserDefaults.standard.bool(forKey: key80) {
            UserDefaults.standard.set(true, forKey: key80)
            track(.proofScoreReached80, properties: ["score": "\(score)"])
        }
    }

    #if DEBUG
    private static let debugHistoryKey = "MoveMark.analytics.debugHistory"
    #endif
}
