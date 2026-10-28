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
            // Same order and words as Edit evidence: condition, what was observed, then the label and notes.
            VStack(alignment: .leading, spacing: 12) {
                MMEvidenceSectionLabel(title: "Condition")
                FlowLayout(spacing: 8) {
                    ForEach(RoomRecord.ConditionRating.allCases.reversed(), id: \.self) { rating in
                        MMEvidenceChip(title: rating.rawValue, isSelected: selectedCondition == rating) {
                            MMHaptics.selection()
                            selectedCondition = rating
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                MMEvidenceSectionLabel(title: "What was observed",
                                       detail: selectedTags.isEmpty ? "Only if relevant" : "\(selectedTags.count) noted")
                FlowLayout(spacing: 8) {
                    ForEach(fixedIssueTags, id: \.self) { tag in
                        MMEvidenceChip(title: tag, isSelected: selectedTags.contains(tag)) {
                            MMHaptics.selection()
                            if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                MMEvidenceSectionLabel(title: "Notes")
                MMEvidenceField(title: "Label", placeholder: "e.g. North wall", text: $title)
                MMEvidenceField(title: "Notes", placeholder: "What you saw, and where", text: $notes, axis: .vertical)
            }

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
