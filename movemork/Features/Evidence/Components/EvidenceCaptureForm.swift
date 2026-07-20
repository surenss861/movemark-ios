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

    let loadedImages: [UIImage]
    let isUploading: Bool
    let errorMessage: String?
    let successMessage: String?
    let moveOutMode: Bool
    let fixedIssueTags: [String]
    var onRetry: (() -> Void)? = nil

    var body: some View {
        MMCard(tone: .artifact, padding: 18, spacing: 16) {
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Condition")
                        .font(MoveMarkTheme.Typography.caption)
                        .tracking(0.9)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .textCase(.uppercase)

                    Picker("Condition", selection: $selectedCondition) {
                        ForEach(RoomRecord.ConditionRating.allCases, id: \.self) { rating in
                            Text(rating.rawValue).tag(rating)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.38), lineWidth: 0.8)
                )

                if let errorMessage {
                    MMErrorBanner(
                        message: errorMessage,
                        retryTitle: MMCopy.tryAgain,
                        onRetry: onRetry ?? {}
                    )
                }

                if let successMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(MoveMarkTheme.Typography.sectionTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.semanticSuccess)
                        Text(successMessage)
                            .font(MoveMarkTheme.Typography.subheadline)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MoveMarkTheme.Colors.semanticSuccess.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MoveMarkTheme.Colors.semanticSuccess.opacity(0.22), lineWidth: 0.8)
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .opacity(isUploading ? 0.72 : 1.0)
        .allowsHitTesting(!isUploading)
        .animation(MMMotion.fastFade, value: successMessage)
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
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.68))
            }

            FlowLayout(spacing: 8) {
                ForEach(fixedIssueTags, id: \.self) { tag in
                    tagChip(tag)
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
                .font(MoveMarkTheme.Typography.footnote)
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
                                ? MoveMarkTheme.Colors.primary.opacity(0.18)
                                : MoveMarkTheme.Colors.cardRaised.opacity(0.5)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected
                                ? MoveMarkTheme.Colors.primary.opacity(0.22)
                                : MoveMarkTheme.Colors.cardStroke.opacity(0.38),
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
