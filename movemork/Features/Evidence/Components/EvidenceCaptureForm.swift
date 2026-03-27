//
//  EvidenceCaptureForm.swift
//  movemork
//
//  Proof details: quiet card, title, tags, notes, condition. Save in sticky bar only.
//

import SwiftUI
import PhotosUI

struct EvidenceCaptureForm: View {
    @Binding var title: String
    @Binding var notes: String
    @Binding var selectedTags: Set<String>
    @Binding var selectedCondition: RoomRecord.ConditionRating
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var showCamera: Bool

    let loadedImages: [UIImage]
    let isUploading: Bool
    let errorMessage: String?
    let successMessage: String?
    let moveOutMode: Bool
    let fixedIssueTags: [String]
    var onRetry: (() -> Void)? = nil

    var body: some View {
        MMCard(tone: .quiet, padding: 18, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(moveOutMode ? "Add move-out proof" : "Details")
                        .font(MoveMarkTheme.Typography.cardTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Title, notes, condition, and optional issue markers.")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
                }

                MMTextField(
                    title: "Entry title",
                    placeholder: "North wall paint wear",
                    text: $title
                )

                issueTagPicker

                MMTextField(
                    title: "Notes",
                    placeholder: "What matters, where it is, what it looked like",
                    text: $notes
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Condition")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))

                    Picker("Condition", selection: $selectedCondition) {
                        ForEach(RoomRecord.ConditionRating.allCases, id: \.self) { rating in
                            Text(rating.rawValue).tag(rating)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let errorMessage {
                    MMErrorBanner(
                        message: errorMessage,
                        retryTitle: MMCopy.tryAgain,
                        onRetry: onRetry ?? {}
                    )
                }

                if let successMessage {
                    Text(successMessage)
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                }
            }
        }
        .opacity(isUploading ? 0.7 : 1.0)
        .allowsHitTesting(!isUploading)
    }

    private var issueTagPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Issue tags")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))

                Text(
                    selectedTags.isEmpty
                        ? "Optional damage markers"
                        : "\(selectedTags.count) selected"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.68))
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(stride(from: 0, to: fixedIssueTags.count, by: 3)), id: \.self) { start in
                    HStack(spacing: 8) {
                        ForEach(Array(fixedIssueTags.dropFirst(start).prefix(3)), id: \.self) { tag in
                            tagChip(tag)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tagChip(_ tag: String) -> some View {
        let isSelected = selectedTags.contains(tag)

        Button {
            if isSelected {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        } label: {
            Text(tag)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? MoveMarkTheme.Colors.textPrimary
                        : MoveMarkTheme.Colors.textSecondary.opacity(0.76)
                )
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? Color.white.opacity(0.10)
                                : Color.white.opacity(0.03)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? MoveMarkTheme.Colors.primary.opacity(0.22)
                                : MoveMarkTheme.Colors.panelStroke.opacity(0.38),
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
