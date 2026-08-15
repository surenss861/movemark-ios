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
        ScrollView(showsIndicators: false) {
            ProofSavedReceiptView(
                model: ProofSavedReceiptModel(
                    roomName: summary.roomName,
                    phaseLabel: phaseLabel,
                    photoCount: summary.photoCount,
                    issueCount: summary.issueCount,
                    timestampLabel: "\(phaseLabel) · \(formattedTime)",
                    headerSubtitle: headerSubtitle,
                    documentedLabel: moment.receiptDocumentedLabel,
                    primaryActionLabel: "Continue next room",
                    imageURL: previewURL
                ),
                onPrimary: onContinueNextRoom,
                onViewVault: onViewProofVault,
                onAddMorePhotos: onContinueNextRoom
            )
            .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .mmProofShellBackground(heroFocus: false, ctaBloom: false)
        .task {
            previewURL = await propertyStore.previewImageURL(for: summary.propertyId)
        }
    }
}
