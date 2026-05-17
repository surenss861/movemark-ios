//
//  SignedInRootView.swift
//  movemork
//
//  Gates signed-in users into first-run proof or the main tab shell.
//

import SwiftUI

struct SignedInRootView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Environment(PropertyStore.self) private var propertyStore

    var body: some View {
        Group {
            if !propertyStore.hasCompletedInitialFetch {
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if shouldShowFirstRunProof {
                FirstRunProofFlowView(requiresOnboarding: false)
            } else {
                AuthenticatedTabShellView()
            }
        }
        .task(id: sessionManager.userId) {
            await loadPropertiesIfNeeded()
        }
    }

    private var shouldShowFirstRunProof: Bool {
        guard let userId = sessionManager.userId else { return false }
        if FirstRunProofPreferences.isComplete(userId: userId) { return false }
        if propertyStore.firstRunAwaitingReceiptDismissal { return true }
        if propertyStore.properties.isEmpty { return true }
        guard let property = propertyStore.currentProperty ?? hydratedFirstProperty else {
            return true
        }
        return propertyStore.documentedRoomCount(for: property) == 0
    }

    private var hydratedFirstProperty: PropertyRecord? {
        guard let id = propertyStore.properties.first?.id else { return nil }
        if propertyStore.currentProperty?.id == id { return propertyStore.currentProperty }
        return nil
    }

    private func loadPropertiesIfNeeded() async {
        guard let userId = sessionManager.userId else { return }
        if !propertyStore.hasCompletedInitialFetch {
            await propertyStore.fetchAll(userId: userId)
        }
        syncFirstRunCompletionFromExistingProof(userId: userId)
    }

    private func syncFirstRunCompletionFromExistingProof(userId: UUID) {
        guard !FirstRunProofPreferences.isComplete(userId: userId) else { return }
        guard let property = propertyStore.currentProperty else { return }
        if propertyStore.documentedRoomCount(for: property) > 0 {
            FirstRunProofPreferences.markComplete(userId: userId)
        }
    }
}
