//
//  EvidenceSavedProofSection.swift
//  movemork
//
//  Saved proof as quiet artifact rows with compact actions.
//

import SwiftUI
import Nuke
import NukeUI

struct EvidenceSavedProofSection: View {
    let existingEntries: [EvidenceRecord]
    let moveOutMode: Bool
    let inspectionRepo: InspectionRepository
    let onEdit: (EvidenceRecord) -> Void
    let onAddPhotos: (EvidenceRecord) -> Void
    let onDelete: (EvidenceRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(moveOutMode ? "Saved move-out proof" : "Saved proof")
                .font(MoveMarkTheme.Typography.caption)
                .tracking(1.0)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

            if existingEntries.isEmpty {
                MMCompactCallout(
                    systemImage: "doc.text.image",
                    title: moveOutMode ? "No move-out entries yet" : "No saved entries yet",
                    message: "After you save proof with the bar below, each entry appears here with photos, condition, and tags so you can edit or add more later."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(existingEntries) { evidence in
                        savedProofRow(evidence)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 10)),
                                removal: .opacity
                            ))
                    }
                }
                .animation(MMMotion.cardReveal, value: existingEntries.map(\.id.uuidString).joined(separator: ","))
            }
        }
    }

    private func savedProofRow(_ evidence: EvidenceRecord) -> some View {
        MMCard(tone: .artifact, padding: 16, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(evidence.title)
                        .font(MoveMarkTheme.Typography.cardTitle)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    MMPill(
                        text: "\(evidence.photoCount) photo\(evidence.photoCount == 1 ? "" : "s")",
                        tone: evidence.photoCount > 0 ? .success : .warning
                    )
                }

                Text(evidence.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)

                SavedProofPhotoThumbnails(
                    evidence: evidence,
                    inspectionRepo: inspectionRepo
                )

                HStack(spacing: 8) {
                    Text("Condition")
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    Text("\(evidence.condition.rawValue) · \(evidence.condition.conditionMeterValue)/5")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.9))
                }

                if !evidence.issueTags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(evidence.issueTags, id: \.self) { tag in
                            MMPill(text: tag, tone: .warning)
                        }
                    }
                }

                Text(evidence.notes.isEmpty ? "No notes on this entry." : evidence.notes)
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
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
                        kind: .secondary,
                        size: .compact,
                        expandsToFillWidth: false
                    )

                    Spacer(minLength: 8)

                    Button("Delete") {
                        onDelete(evidence)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.semanticDanger)
                }
            }
        }
    }
}

// MARK: - Thumbnails + full-screen preview

private struct PhotoPreviewItem: Identifiable {
    let id: UUID
    let url: URL
    let filePath: String
}

private struct SavedProofPhotoThumbnails: View {
    let evidence: EvidenceRecord
    let inspectionRepo: InspectionRepository

    @State private var previewURLs: [UUID: URL] = [:]
    @State private var signedURLFailedIds: Set<UUID> = []
    @State private var imageRenderFailedIds: Set<UUID> = []
    @State private var renderNonce: [UUID: Int] = [:]
    @State private var previewItem: PhotoPreviewItem?

    private var photosFingerprint: String {
        evidence.photos.map { "\($0.id.uuidString)|\($0.filePath)" }.joined(separator: ";")
    }

    var body: some View {
        Group {
            if evidence.photos.isEmpty {
                if evidence.photoCount > 0 {
                    Text("Photos are still syncing…")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(evidence.photos.prefix(4))) { photo in
                            thumbnailCell(photo)
                        }
                        if evidence.photos.count > 4 {
                            Text("+\(evidence.photos.count - 4)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.88))
                                .frame(width: 48, height: 76)
                                .background(MoveMarkTheme.Colors.surfaceInset.opacity(0.88))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.5), lineWidth: 0.9)
                                )
                        }
                    }
                }
            }
        }
        .task(id: photosFingerprint) {
            signedURLFailedIds = []
            imageRenderFailedIds = []
            renderNonce = [:]
            previewURLs = [:]
            await loadThumbs()
        }
        .onChange(of: evidence.photos.count) { _, _ in
            signedURLFailedIds = []
            imageRenderFailedIds = []
            renderNonce = [:]
            previewURLs = [:]
            Task { await loadThumbs() }
        }
        .fullScreenCover(item: $previewItem) { item in
            PhotoPreviewFullScreen(initialURL: item.url, filePath: item.filePath) {
                previewItem = nil
            }
        }
    }

    @ViewBuilder
    private func thumbnailCell(_ photo: EvidencePhoto) -> some View {
        Group {
            if signedURLFailedIds.contains(photo.id) {
                Button {
                    Task { await retrySignedURL(for: photo) }
                } label: {
                    thumbPlaceholder(systemName: "arrow.clockwise", caption: MoveMarkFlowMessage.proofPreviewTapRetry)
                }
                .buttonStyle(.plain)
            } else if imageRenderFailedIds.contains(photo.id), let url = previewURLs[photo.id] {
                Button {
                    Task { await retryImageRender(for: photo, url: url) }
                } label: {
                    thumbPlaceholder(systemName: "arrow.clockwise", caption: MoveMarkFlowMessage.proofPreviewTapRetry)
                }
                .buttonStyle(.plain)
            } else if let url = previewURLs[photo.id] {
                let nonce = renderNonce[photo.id, default: 0]
                Button {
                    previewItem = PhotoPreviewItem(id: photo.id, url: url, filePath: photo.filePath)
                } label: {
                    LazyImage(url: url, resizingMode: .aspectFill)
                        .onFailure { _ in
                            Task { @MainActor in
                                imageRenderFailedIds.insert(photo.id)
                            }
                        }
                        .onSuccess { _ in
                            Task { @MainActor in
                                imageRenderFailedIds.remove(photo.id)
                            }
                        }
                        .frame(width: 76, height: 76)
                        .clipped()
                }
                .buttonStyle(.plain)
                .id("\(photo.id.uuidString)-\(nonce)")
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(MoveMarkTheme.Colors.mint.opacity(0.5))
                    .overlay { ProgressView().tint(MoveMarkTheme.Colors.primary) }
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.48), lineWidth: 0.9)
        )
    }

    private func thumbPlaceholder(systemName: String, caption: String) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(MoveMarkTheme.Colors.surfaceInset.opacity(0.75))
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: systemName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.primary)
                    Text(caption)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                .padding(4)
            }
    }

    private func loadThumbs() async {
        for photo in evidence.photos.prefix(4) {
            await resolveSignedURL(for: photo)
        }
    }

    private func resolveSignedURL(for photo: EvidencePhoto) async {
        do {
            let url = try await inspectionRepo.signedURL(bucket: "inspection-media", path: photo.filePath)
            await MainActor.run {
                previewURLs[photo.id] = url
                signedURLFailedIds.remove(photo.id)
            }
        } catch {
            await MainActor.run {
                signedURLFailedIds.insert(photo.id)
                previewURLs.removeValue(forKey: photo.id)
            }
        }
    }

    private func retrySignedURL(for photo: EvidencePhoto) async {
        await MoveMarkSignedURLCache.shared.invalidate(bucket: "inspection-media", path: photo.filePath)
        await MainActor.run {
            signedURLFailedIds.remove(photo.id)
            imageRenderFailedIds.remove(photo.id)
        }
        await resolveSignedURL(for: photo)
    }

    private func retryImageRender(for photo: EvidencePhoto, url: URL) async {
        _ = url
        await MoveMarkSignedURLCache.shared.invalidate(bucket: "inspection-media", path: photo.filePath)
        await MainActor.run {
            imageRenderFailedIds.remove(photo.id)
            renderNonce[photo.id, default: 0] += 1
        }
        await resolveSignedURL(for: photo)
    }
}

private struct PhotoPreviewFullScreen: View {
    let filePath: String
    let onClose: () -> Void

    @State private var imageURL: URL
    @State private var reloadGeneration = 0
    @State private var didAutoRetry = false
    @State private var showHardFailure = false
    @State private var isRefreshingURL = false

    private let inspectionRepo = InspectionRepository()

    init(initialURL: URL, filePath: String, onClose: @escaping () -> Void) {
        self.filePath = filePath
        self.onClose = onClose
        _imageURL = State(initialValue: initialURL)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if showHardFailure {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("Couldn’t load image")
                        .font(MoveMarkTheme.Typography.sectionTitle)
                        .foregroundStyle(.white.opacity(0.9))
                    Text("The preview link may have expired.")
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await manualRetry() }
                    } label: {
                        Text("Try again")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Colors.primary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isRefreshingURL {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Custom builder avoids Nuke's default gray `Rectangle` placeholder on the black chrome.
                Group {
                    LazyImage(url: imageURL) { state in
                        ZStack {
                            Color.black
                            if let container = state.imageContainer {
                                SwiftUI.Image(uiImage: container.image)
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if state.error != nil {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .onFailure { _ in
                        handleImageLoadFailure()
                    }
                }
                .id(reloadGeneration)
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

    private func handleImageLoadFailure() {
        Task { @MainActor in
            guard !showHardFailure else { return }
            if isRefreshingURL { return }

            if !didAutoRetry {
                didAutoRetry = true
                isRefreshingURL = true
                Task {
                    await MoveMarkSignedURLCache.shared.invalidate(bucket: "inspection-media", path: filePath)
                    do {
                        let newURL = try await inspectionRepo.signedURL(bucket: "inspection-media", path: filePath)
                        await MainActor.run {
                            imageURL = newURL
                            reloadGeneration += 1
                            isRefreshingURL = false
                        }
                    } catch {
                        await MainActor.run {
                            showHardFailure = true
                            isRefreshingURL = false
                        }
                    }
                }
            } else {
                showHardFailure = true
            }
        }
    }

    private func manualRetry() async {
        await MainActor.run {
            showHardFailure = false
            didAutoRetry = false
            isRefreshingURL = true
        }
        await MoveMarkSignedURLCache.shared.invalidate(bucket: "inspection-media", path: filePath)
        do {
            let newURL = try await inspectionRepo.signedURL(bucket: "inspection-media", path: filePath)
            await MainActor.run {
                imageURL = newURL
                reloadGeneration += 1
                isRefreshingURL = false
            }
        } catch {
            await MainActor.run {
                showHardFailure = true
                isRefreshingURL = false
            }
        }
    }
}
