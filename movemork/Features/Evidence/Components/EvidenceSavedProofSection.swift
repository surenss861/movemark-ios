//
//  EvidenceSavedProofSection.swift
//  movemork
//
//  Saved proof as quiet artifact rows with compact actions.
//

import SwiftUI

struct EvidenceSavedProofSection: View {
    let existingEntries: [EvidenceRecord]
    let moveOutMode: Bool
    let onEdit: (EvidenceRecord) -> Void
    let onAddPhotos: (EvidenceRecord) -> Void
    let onDelete: (EvidenceRecord) -> Void

    private let inspectionRepo = InspectionRepository()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(moveOutMode ? "Saved move-out proof" : "Saved proof")
                .font(MoveMarkTheme.Typography.caption)
                .tracking(1.0)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            if existingEntries.isEmpty {
                MMCard(tone: .quiet, padding: 16, spacing: 8) {
                    Text("No saved proof yet")
                        .font(MoveMarkTheme.Typography.sectionTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                    Text("Saved entries for this room will appear here.")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(existingEntries) { evidence in
                        savedProofRow(evidence)
                    }
                }
            }
        }
    }

    private func savedProofRow(_ evidence: EvidenceRecord) -> some View {
        MMCard(tone: .quiet, padding: 14, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(evidence.title)
                            .font(MoveMarkTheme.Typography.sectionTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        Text(evidence.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    }

                    Spacer()

                    Text("\(evidence.photoCount) photo\(evidence.photoCount == 1 ? "" : "s")")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                }

                SavedProofPhotoThumbnails(
                    evidence: evidence,
                    inspectionRepo: inspectionRepo
                )

                if !evidence.issueTags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(evidence.issueTags.prefix(3), id: \.self) { tag in
                            MMPill(text: tag, tone: .warning)
                        }
                    }
                }

                Text(evidence.notes.isEmpty ? "No notes added." : evidence.notes)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text("Condition \(evidence.condition.conditionMeterValue)/5")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                    Spacer()

                    MMButton(
                        title: "Edit",
                        action: { onEdit(evidence) },
                        kind: .quiet,
                        size: .compact,
                        expandsToFillWidth: false
                    )

                    MMButton(
                        title: "Add photos",
                        action: { onAddPhotos(evidence) },
                        kind: .quiet,
                        size: .compact,
                        expandsToFillWidth: false
                    )

                    Button("Delete") {
                        onDelete(evidence)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.9))
                }
            }
        }
    }
}

// MARK: - Thumbnails + full-screen preview

private struct PhotoPreviewItem: Identifiable {
    let id: UUID
    let url: URL
}

private struct SavedProofPhotoThumbnails: View {
    let evidence: EvidenceRecord
    let inspectionRepo: InspectionRepository

    @State private var previewURLs: [UUID: URL] = [:]
    @State private var previewItem: PhotoPreviewItem?

    var body: some View {
        Group {
            if evidence.photos.isEmpty {
                if evidence.photoCount > 0 {
                    Text("Photos loading…")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(evidence.photos.prefix(4)) { photo in
                            thumbnailCell(photo)
                        }
                        if evidence.photos.count > 4 {
                            Text("+\(evidence.photos.count - 4)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                .frame(width: 44, height: 72)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .task(id: evidence.id) {
            await loadThumbs()
        }
        .onChange(of: evidence.photos.count) { _, _ in
            previewURLs = [:]
            Task { await loadThumbs() }
        }
        .fullScreenCover(item: $previewItem) { item in
            PhotoPreviewFullScreen(url: item.url) {
                previewItem = nil
            }
        }
    }

    @ViewBuilder
    private func thumbnailCell(_ photo: EvidencePhoto) -> some View {
        Group {
            if let url = previewURLs[photo.id] {
                Button {
                    previewItem = PhotoPreviewItem(id: photo.id, url: url)
                } label: {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                }
                        case .empty:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                                .overlay { ProgressView() }
                        @unknown default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.08))
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .overlay { ProgressView() }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadThumbs() async {
        for photo in evidence.photos.prefix(4) {
            if previewURLs[photo.id] != nil { continue }
            if let url = try? await inspectionRepo.signedURL(bucket: "inspection-media", path: photo.filePath) {
                await MainActor.run {
                    previewURLs[photo.id] = url
                }
            }
        }
    }
}

private struct PhotoPreviewFullScreen: View {
    let url: URL
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Couldn’t load image")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    EmptyView()
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .white.opacity(0.3))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}
