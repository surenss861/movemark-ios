//
//  FirstRunProofFlowView.swift
//  movemork
//
//  Moment → vault setup → room pick → capture → saved receipt.
//

import SwiftUI

struct FirstRunProofFlowView: View {
    let requiresOnboarding: Bool

    @Environment(PropertyStore.self) private var propertyStore
    @Environment(SessionManager.self) private var sessionManager

    @State private var onboardingName = "Renter"
    @State private var selectedMoment: RentalMoment = .justMovedIn
    @State private var isPreparingVaults = true

    private enum Step: Equatable {
        case moment
        case setup
        case pickRoom(UUID)
        case capture(propertyId: UUID, roomId: UUID, roomName: String)
        case saved(FirstRunSavedSummary)
    }

    @State private var step: Step = .moment

    var body: some View {
        Group {
            switch step {
            case .moment:
                FirstRunMomentPickerView(isPreparing: isPreparingVaults) { moment in
                    selectedMoment = moment
                    MoveMarkAnalytics.track(
                        .rentalMomentSelected,
                        properties: ["moment": moment.rawValue]
                    )
                    advanceAfterMomentSelected()
                }

            case .setup:
                FirstRunPropertySetupView(
                    requiresOnboarding: requiresOnboarding,
                    moment: selectedMoment,
                    onCreated: { propertyId in
                        step = .pickRoom(propertyId)
                    },
                    onOnboardingNameCaptured: { onboardingName = $0 }
                )

            case .pickRoom(let propertyId):
                FirstRunRoomPickerView(
                    propertyId: propertyId,
                    moment: selectedMoment
                ) { roomId, roomName in
                    step = .capture(propertyId: propertyId, roomId: roomId, roomName: roomName)
                }

            case .capture(let propertyId, let roomId, let roomName):
                NavigationStack {
                    EvidenceCaptureView(
                        roomID: roomId,
                        roomName: roomName,
                        moveOutMode: selectedMoment.capturesMoveOutEvidence,
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
                    moment: selectedMoment,
                    onContinueNextRoom: { finishFirstRun(exit: .continueNextRoom) },
                    onViewProofVault: { finishFirstRun(exit: .viewVault) }
                )
            }
        }
        .task(id: sessionManager.userId) {
            await loadPropertiesIfNeeded()
            isPreparingVaults = false
        }
    }

    private func loadPropertiesIfNeeded() async {
        guard let userId = sessionManager.userId else { return }
        if !propertyStore.hasCompletedInitialFetch {
            await propertyStore.fetchAll(userId: userId)
        }
    }

    private func advanceAfterMomentSelected() {
        if let propertyId = existingPropertyId {
            step = .pickRoom(propertyId)
        } else {
            step = .setup
        }
    }

    private var existingPropertyId: UUID? {
        guard !propertyStore.properties.isEmpty else { return nil }
        return propertyStore.activePropertyId ?? propertyStore.properties[0].id
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
