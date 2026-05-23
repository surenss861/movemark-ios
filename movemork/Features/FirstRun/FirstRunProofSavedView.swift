//
//  FirstRunProofSavedView.swift
//  movemork
//

import SwiftUI

struct FirstRunProofSavedView: View {
    let summary: FirstRunSavedSummary
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

    private var headerSubtitle: String {
        "\(summary.roomName) proof · \(photosSavedLine) · Move-in"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ProofSavedReceiptView(
                model: ProofSavedReceiptModel(
                    roomName: summary.roomName,
                    phaseLabel: "Move-in",
                    photoCount: summary.photoCount,
                    issueCount: summary.issueCount,
                    timestampLabel: "Move-in · \(formattedTime)",
                    headerSubtitle: headerSubtitle,
                    documentedLabel: "Room now documented",
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
