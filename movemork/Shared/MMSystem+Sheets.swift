//
//  MMSystem+Sheets.swift
//  movemork
//
//  @file Pieces for the focused sheets on the dark evidence surface (Edit evidence, Add photos) and the Pro
//        paywall: an eyebrow + subject header, section labels, the record's photos (lead photo + filmstrip),
//        a large choice row, the pending-photo grid (Capture's treatment) and the dark proof-timeline step.
//        Lime stays on the one primary action; a lime check only marks something already recorded.
//  @domain design-system
//  @see [[MMSystem+Flows.swift]] · [[MMSystem+Patterns.swift]]
//

import SwiftUI
import UIKit

// MARK: - Header

/// The small label over a dark sheet or screen ("EDIT EVIDENCE", "MOVEMARK PRO"). A label, not a lockup.
struct MMDarkEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .mmFont(11, .semibold)
            .tracking(0.8)
            .foregroundStyle(MMInk.heroSecondary)
            .accessibilityLabel(text)
    }
}

/// Truth first on an evidence sheet: what this is, which record, when it was recorded.
struct MMEvidenceSheetHeader: View {
    let eyebrow: String
    let subject: String              // "Living Room · Move-in"
    var meta: String? = nil          // "Recorded Oct 26, 2025 · 3:29 PM · 5 photos"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMDarkEyebrow(text: eyebrow)
            Text(subject)
                .mmFont(24, .semibold)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 6)
            if let meta {
                Text(meta)
                    .mmFont(13.5)
                    .monospacedDigit()
                    .foregroundStyle(MMInk.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A section label on the evidence surface (CONDITION, WHAT WAS OBSERVED, NOTES), with an optional quiet detail.
struct MMEvidenceSectionLabel: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            MMDarkEyebrow(text: title)
            Spacer(minLength: 8)
            if let detail { Text(detail).mmFont(12.5).foregroundStyle(MMInk.heroSecondary) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - The record's photos

/// The photos already on an evidence record: one large lead photo and, when there are more, a filmstrip.
/// When only the count is known (photos not loaded yet), quiet tiles stand in — never a broken slot.
struct MMEvidenceRecordPhotos: View {
    let photos: [EvidencePhoto]
    let photoCount: Int
    let resolve: (String) async -> URL?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let thumb: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lead = photos.first {
                MMEvidenceImage(path: lead.filePath, resolve: resolve, placeholder: Color.white.opacity(0.06))
                    .frame(maxWidth: .infinity)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 190 : 240)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
                .accessibilityHidden(true)

                if photoCount > 1 {
                    filmstrip
                }
            } else if photoCount > 0 {
                MMEvidencePhotoStrip(placeholderCount: photoCount)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photoCount == 1 ? "1 photo on this record" : "\(photoCount) photos on this record")
    }

    private var filmstrip: some View {
        let rest = Array(photos.dropFirst().prefix(4))
        let unseen = max(0, photoCount - 1 - rest.count)
        return HStack(spacing: 8) {
            ForEach(rest) { photo in
                MMEvidenceImage(path: photo.thumbnailPath ?? photo.filePath, resolve: resolve,
                                size: CGSize(width: Self.thumb, height: Self.thumb), placeholder: Color.white.opacity(0.06))
                    .frame(width: Self.thumb, height: Self.thumb)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
            }
            if unseen > 0 {
                Text("+\(unseen)")
                    .mmFont(14, .medium)
                    .foregroundStyle(MMInk.heroSecondary)
                    .frame(width: Self.thumb, height: Self.thumb)
                    .background(MMInk.evidenceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Choices and pending photos

/// One large choice on the evidence surface: icon, title, one line of what it does. A label for a Button or
/// a native PhotosPicker — the picker itself stays system.
struct MMEvidenceChoiceLabel: View {
    let icon: String
    let title: String
    let detail: String
    var isBusy = false

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if isBusy { ProgressView().controlSize(.small).tint(.white) }
                else { Image(systemName: icon).font(.system(size: 18, weight: .regular)).foregroundStyle(.white) }
            }
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title).mmFont(17, .semibold).foregroundStyle(.white)
                Text(detail).mmFont(14).foregroundStyle(MMInk.heroSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MMInk.heroSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(MMInk.evidenceRaised, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Photos waiting to be saved, as Capture shows them: square tiles, three across, nothing on top.
struct MMPendingPhotoGrid: View {
    let images: [UIImage]
    var isUploading = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay { Image(uiImage: image).resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
                    .overlay {
                        if isUploading {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.45))
                            ProgressView().tint(.white)
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(images.count == 1 ? "1 photo ready" : "\(images.count) photos ready")
    }
}

// MARK: - Proof timeline (dark)

/// One step of the rental timeline on a dark surface: phase label, what MoveMark keeps, and — only where it
/// is genuinely Pro — a quiet "Pro" mark on the part Pro adds.
struct MMDarkTimelineStep: View {
    let phase: String                // "MOVE-IN"
    let title: String                // "Recorded"
    var detail: String? = nil
    var proPart: String? = nil       // "Move-out report"
    var isRecorded = false
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isRecorded ? MMInk.limeMark : MMInk.evidence)
                        .overlay(Circle().strokeBorder(isRecorded ? Color.clear : Color.white.opacity(0.45), lineWidth: 1.5))
                    if isRecorded {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(MMInk.onLime)
                    }
                }
                .frame(width: 18, height: 18)
                .padding(.top, 1)
                if !isLast {
                    Rectangle().fill(Color.white.opacity(0.16)).frame(width: 1.5).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                MMDarkEyebrow(text: phase)
                Text(title).mmFont(17, .semibold).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail).mmFont(14).foregroundStyle(MMInk.heroSecondary).fixedSize(horizontal: false, vertical: true)
                }
                if let proPart {
                    HStack(spacing: 6) {
                        Text(proPart).mmFont(13.5, .medium).foregroundStyle(.white)
                        Text("Pro")
                            .mmFont(11.5, .semibold)
                            .foregroundStyle(MMInk.evidence)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.white, in: Capsule())
                    }
                    .padding(.top, 3)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(proPart), included with Pro")
                }
            }
            .padding(.bottom, isLast ? 0 : 18)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// A selectable plan on a dark surface: radio, name, App Store price, one quiet line.
struct MMDarkPlanRow: View {
    let title: String
    let price: String
    var detail: String? = nil
    var isSelected = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 21))
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.4))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).mmFont(16, .semibold).foregroundStyle(.white)
                if let detail {
                    Text(detail).mmFont(13).foregroundStyle(MMInk.heroSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Text(price).mmFont(16, .semibold).monospacedDigit().foregroundStyle(.white).layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(isSelected ? Color.white.opacity(0.09) : MMInk.evidenceRaised,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(isSelected ? Color.white.opacity(0.85) : MMInk.evidenceStroke, lineWidth: isSelected ? 1.5 : 0.75))
        .contentShape(Rectangle())
    }
}
