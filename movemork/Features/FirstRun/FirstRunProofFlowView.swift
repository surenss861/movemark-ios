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
    /// Re-entry guard for the saved receipt's buttons while onboarding completes.
    @State private var isFinishing = false
    @State private var finishError: String?

    var body: some View {
        Group {
            switch step {
            case .moment:
                FirstRunMomentPickerView(
                    isPreparing: isPreparingVaults,
                    onSelect: { moment in
                        selectedMoment = moment
                        MoveMarkAnalytics.track(
                            .rentalMomentSelected,
                            properties: ["moment": moment.rawValue]
                        )
                        advanceAfterMomentSelected()
                    },
                    onSignOut: { Task { await sessionManager.signOut() } }
                )

            case .setup:
                FirstRunPropertySetupView(
                    moment: selectedMoment,
                    onCreated: { propertyId in
                        step = .pickRoom(propertyId)
                    },
                    onBack: { step = .moment }
                )

            case .pickRoom(let propertyId):
                FirstRunRoomPickerView(
                    propertyId: propertyId,
                    moment: selectedMoment,
                    onStartProof: { roomId, roomName in
                        step = .capture(propertyId: propertyId, roomId: roomId, roomName: roomName)
                    },
                    // A rental already exists by now, so back returns to the moment (choosing again reuses it)
                    // rather than to setup, which would create a second rental.
                    onBack: { step = existingPropertyId != nil ? .moment : .setup }
                )

            case .capture(let propertyId, let roomId, let roomName):
                NavigationStack {
                    EvidenceCaptureView(
                        roomID: roomId,
                        roomName: roomName,
                        moveOutMode: selectedMoment.capturesMoveOutEvidence,
                        onFirstProofSaved: { summary in
                            propertyStore.firstRunAwaitingReceiptDismissal = true
                            // Proof exists now: onboarding is done even if the app closes on the receipt.
                            if requiresOnboarding {
                                Task { try? await sessionManager.recordOnboardingCompleted() }
                            }
                            let saved = FirstRunSavedSummary(
                                propertyId: propertyId,
                                roomName: summary.roomName,
                                photoCount: summary.photoCount,
                                issueCount: summary.issueCount,
                                savedAt: summary.savedAt
                            )
                            step = .saved(saved)
                        },
                        onBack: { step = .pickRoom(propertyId) }
                    )
                }

            case .saved(let summary):
                FirstRunProofSavedView(
                    summary: summary,
                    moment: selectedMoment,
                    onContinueNextRoom: { finishFirstRun(exit: .continueNextRoom) },
                    onViewProofVault: { finishFirstRun(exit: .viewVault) },
                    isBusy: isFinishing,
                    errorMessage: finishError,
                    onRetry: {
                        finishError = nil
                        finishFirstRun(exit: propertyStore.pendingFirstRunExit ?? .viewVault)
                    }
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
        guard !isFinishing, let userId = sessionManager.userId else { return }

        // A second tap after onboarding failed: the proof is saved on this device, so let the renter in
        // rather than trapping them on the receipt.
        if finishError != nil, requiresOnboarding, sessionManager.authPhase == .needsOnboarding,
           FirstRunProofPreferences.isComplete(userId: userId) {
            finishError = nil
            propertyStore.pendingFirstRunExit = exit
            sessionManager.authPhase = .signedIn
            return
        }

        isFinishing = true
        finishError = nil

        Task { @MainActor in
            defer { isFinishing = false }
            FirstRunProofPreferences.markComplete(userId: userId)
            propertyStore.firstRunAwaitingReceiptDismissal = false
            propertyStore.pendingFirstRunExit = exit

            _ = await propertyStore.refreshActivePropertyHydration(userId: userId)

            if requiresOnboarding, sessionManager.authPhase == .needsOnboarding {
                do {
                    try await sessionManager.completeOnboarding()
                } catch {
                    finishError = "Couldn’t finish setting up your account. Your proof is saved — try again, or continue anyway."
                    MMHaptics.error()
                }
            }
        }
    }
}

/// Back from a first-run step: the same quiet circle the auth screen uses in the header's trailing slot.
struct FirstRunBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.10), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityLabel("Back")
        .accessibilityIdentifier("firstRun.back")
    }
}
