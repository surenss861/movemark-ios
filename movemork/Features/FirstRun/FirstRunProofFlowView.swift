//
//  FirstRunProofFlowView.swift
//  movemork
//
//  Move-in proof first run — vault setup → room pick → capture → saved receipt.
//

import SwiftUI

struct FirstRunProofFlowView: View {
    let requiresOnboarding: Bool

    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var onboardingName = "Renter"

    private enum Step: Equatable {
        case setup
        case pickRoom(UUID)
        case capture(propertyId: UUID, roomId: UUID, roomName: String)
        case saved(FirstRunSavedSummary)
    }

    @State private var step: Step = .setup

    var body: some View {
        Group {
            switch step {
            case .setup:
                FirstRunPropertySetupView(
                    requiresOnboarding: requiresOnboarding,
                    onCreated: { propertyId in
                        step = .pickRoom(propertyId)
                    },
                    onOnboardingNameCaptured: { onboardingName = $0 }
                )

            case .pickRoom(let propertyId):
                FirstRunRoomPickerView(propertyId: propertyId) { roomId, roomName in
                    step = .capture(propertyId: propertyId, roomId: roomId, roomName: roomName)
                }

            case .capture(let propertyId, let roomId, let roomName):
                NavigationStack {
                    EvidenceCaptureView(
                        roomID: roomId,
                        roomName: roomName,
                        moveOutMode: false,
                        onFirstProofSaved: { summary in
                            propertyStore.firstRunAwaitingReceiptDismissal = true
                            let saved = FirstRunSavedSummary(
                                propertyId: propertyId,
                                roomName: summary.roomName,
                                photoCount: summary.photoCount,
                                issueCount: summary.issueCount,
                                savedAt: summary.savedAt
                            )
                            step = .saved(saved)
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Back") {
                                step = .pickRoom(propertyId)
                            }
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                        }
                    }
                }

            case .saved(let summary):
                FirstRunProofSavedView(
                    summary: summary,
                    onContinueNextRoom: { finishFirstRun(exit: .continueNextRoom) },
                    onViewProofVault: { finishFirstRun(exit: .viewVault) }
                )
            }
        }
        .task(id: sessionManager.userId) {
            await loadPropertiesIfNeeded()
            applyInitialStepIfNeeded()
        }
    }

    private func loadPropertiesIfNeeded() async {
        guard let userId = sessionManager.userId else { return }
        if !propertyStore.hasCompletedInitialFetch {
            await propertyStore.fetchAll(userId: userId)
        }
    }

    private func applyInitialStepIfNeeded() {
        guard case .setup = step else { return }
        guard !propertyStore.properties.isEmpty else { return }
        let propertyId = propertyStore.activePropertyId ?? propertyStore.properties[0].id
        step = .pickRoom(propertyId)
    }

    private func finishFirstRun(exit: PropertyStore.FirstRunExitAction) {
        guard let userId = sessionManager.userId else { return }

        Task { @MainActor in
            FirstRunProofPreferences.markComplete(userId: userId)
            propertyStore.firstRunAwaitingReceiptDismissal = false
            propertyStore.pendingFirstRunExit = exit

            _ = await propertyStore.refreshActivePropertyHydration(userId: userId)

            if requiresOnboarding, sessionManager.authPhase == .needsOnboarding {
                try? await sessionManager.completeOnboarding(firstName: onboardingName)
            }
        }
    }
}
