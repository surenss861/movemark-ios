//
//  EvidenceCaptureForm.swift
//  movemork
//
//  Proof details on the dark room surface: title, tags, notes, condition. Save in sticky bar only.
//

import SwiftUI
import PhotosUI

struct EvidenceCaptureForm: View {
    @Binding var title: String
    @Binding var notes: String
    @Binding var selectedTags: Set<String>
    @Binding var selectedCondition: RoomRecord.ConditionRating
    @Binding var selectedItems: [PhotosPickerItem]

    let loadedImages: [UIImage]
    let isUploading: Bool
    let errorMessage: String?
    let successMessage: String?
    let moveOutMode: Bool
    let fixedIssueTags: [String]
    var onRetry: (() -> Void)? = nil

    var body: some View {
        // No card: the form sits in the Room body under a NEW ENTRY label (ROOM_EVIDENCE_RECORD §4). Dark evidence
        // surface: white text, white/12% strokes, never green.
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Details")
                    .mmFont(17, .semibold)
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)

                Text("Title, notes, condition, and optional issue markers.")
                    .mmFont(13.5)
                    .foregroundStyle(MMInk.heroSecondary)
            }

            MMEvidenceField(
                title: "Entry title",
                placeholder: "North wall paint wear",
                text: $title
            )

            MMEvidenceTagPicker(tags: fixedIssueTags, selected: $selectedTags)

            MMEvidenceField(
                title: "Notes",
                placeholder: "What matters, where it is, what it looked like",
                text: $notes,
                axis: .vertical
            )

            MMEvidenceConditionPicker(condition: $selectedCondition)

            if let errorMessage {
                MMEvidenceNotice(
                    message: errorMessage,
                    actionTitle: MMCopy.tryAgain,
                    action: onRetry ?? {}
                )
            }

            if let successMessage {
                MMEvidenceNotice(message: successMessage, tone: .success)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .opacity(isUploading ? 0.72 : 1.0)
        .allowsHitTesting(!isUploading)
        .animation(MMMotion.fastFade, value: successMessage)
    }
}
