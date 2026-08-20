//
//  PropertyStore.swift
//  movemork
//
//  MoveMark — Property, maintenance, and dispute state.
//

import Foundation
import Observation
import Supabase

@MainActor
@Observable
final class PropertyStore {
    var currentProperty: PropertyRecord?
    /// All properties for the current user (for switching). Updated by fetchAll.
    var properties: [PropertyRow] = []
    /// Currently selected property id. When set, hydrate that property into currentProperty. Persisted per user.
    var activePropertyId: UUID?
    var maintenanceLog: [MaintenanceRecord] = []
    var isLoading = false
    var errorMessage: String? = nil
    /// True after first fetchAll completes (success or no property). Reset on clear() so we don't flash empty state on relaunch.
    var hasCompletedInitialFetch = false
    /// True when the last `fetchAll` ended in an error rather than a real answer.
    ///
    /// `hasCompletedInitialFetch` alone cannot tell "this user has no properties" apart from
    /// "we could not load them" — it is set in a `defer`, so it goes true on the throw path too.
    /// Routing needs that distinction: without it a failed load looks like an empty account and
    /// sends an existing renter back through first-run. Reset on `clear()`.
    var lastFetchFailed = false

    /// One-time relay for vault feedback (e.g. room completed). Consumed by PropertyVaultView.onAppear.
    @ObservationIgnored
    var pendingVaultFeedback: VaultFeedbackEvent? = nil

    /// Keeps first-run receipt visible after the first save even though rooms are now documented.
    var firstRunAwaitingReceiptDismissal = false

    /// After first-run receipt dismissal, vault tab can open walkthrough or stay on root.
    @ObservationIgnored
    var pendingFirstRunExit: FirstRunExitAction? = nil

    enum FirstRunExitAction: Equatable {
        case continueNextRoom
        case viewVault
    }

    let propertyRepo = PropertyRepository()
    let inspectionRepo = InspectionRepository()
    let maintenanceRepo = MaintenanceRepository()
    let documentRepo = DocumentRepository()
    let checklistRepo = ChecklistRepository()
}
