//
//  FirstRunProofSavedView.swift
//  movemork
//

import SwiftUI

struct FirstRunProofSavedView: View {
    let summary: FirstRunSavedSummary
    var moment: RentalMoment = .justMovedIn
    let onContinueNextRoom: () -> Void
    let onViewProofVault: () -> Void
    /// Finishing onboarding is in flight: the actions ignore taps until it settles.
    var isBusy = false
    var errorMessage: String? = nil
    var onRetry: (() -> Void)? = nil

    @Environment(PropertyStore.self) private var propertyStore
    @State private var previewURL: URL?

    private var formattedTime: String {
        summary.savedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var photosSavedLine: String {
        summary.photoCount == 1 ? "1 photo saved" : "\(summary.photoCount) photos saved"
    }

    private var phaseLabel: String {
        moment.receiptPhaseLabel
    }

    private var headerSubtitle: String {
        "\(summary.roomName) proof · \(photosSavedLine) · \(phaseLabel)"
    }

    var body: some View {
        ProofSavedReceiptView(
            model: ProofSavedReceiptModel(
                roomName: summary.roomName,
                phaseLabel: phaseLabel,
                photoCount: summary.photoCount,
                issueCount: summary.issueCount,
                savedAt: summary.savedAt,
                imageURL: previewURL,
                primaryActionLabel: "Continue to next room",
                secondaryActionLabel: "View proof vault"
            ),
            onPrimary: onContinueNextRoom,
            onSecondary: onViewProofVault,
            onAddMorePhotos: onContinueNextRoom
        )
        .allowsHitTesting(!isBusy)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let errorMessage {
                MMNotice(message: errorMessage, actionTitle: onRetry != nil ? MMCopy.tryAgain : nil, action: onRetry)
                    .environment(\.colorScheme, .light)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .task {
            previewURL = await propertyStore.previewImageURL(for: summary.propertyId)
        }
    }
}
