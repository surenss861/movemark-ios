//
//  RoomPhotoViewer.swift
//  movemork
//
//  @file Room photo viewer — every photo in the phase, paged, "2 of 4", filmstrip, close
//  @domain proof-capture
//  @status wip
//  @see [[ROOM_EVIDENCE_RECORD]] — screen spec (§4, many photos)
//  @see [[RoomProofScreen.kt]] — Android counterpart (RoomPhotoViewer)
//

import SwiftUI

struct RoomPhotoViewer: View {
    let photos: [EvidencePhoto]
    let startID: UUID
    let resolvePhotoURL: (String) async -> URL?
    let onClose: () -> Void

    @State private var selection: UUID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(photos: [EvidencePhoto], startID: UUID, resolvePhotoURL: @escaping (String) async -> URL?, onClose: @escaping () -> Void) {
        self.photos = photos
        self.startID = startID
        self.resolvePhotoURL = resolvePhotoURL
        self.onClose = onClose
        _selection = State(initialValue: startID)
    }

    private var index: Int { photos.firstIndex(where: { $0.id == selection }) ?? 0 }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    ViewerPage(photo: photo, resolvePhotoURL: resolvePhotoURL)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                    Text("\(index + 1) of \(photos.count)")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .environment(\.colorScheme, .dark)

                Spacer()

                if photos.count > 1 {
                    ScrollViewReader { reader in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photos) { photo in
                                    ViewerThumb(photo: photo, isSelected: photo.id == selection, resolvePhotoURL: resolvePhotoURL)
                                        .id(photo.id)
                                        .onTapGesture {
                                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { selection = photo.id }
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .onChange(of: selection) { _, id in
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { reader.scrollTo(id, anchor: .center) }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .statusBarHidden()
    }
}

private struct ViewerPage: View {
    let photo: EvidencePhoto
    let resolvePhotoURL: (String) async -> URL?
    @State private var url: URL?

    var body: some View {
        MMCachedAsyncImage(path: photo.filePath, signedURL: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .empty:
                ProgressView().tint(.white)
            case .failure:
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle").font(.title2)
                    Text("Couldn’t load this photo").font(MoveMarkTheme.Typography.subheadline)
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: photo.id) { url = await resolvePhotoURL(photo.filePath) }
        .accessibilityLabel("Evidence photo")
    }
}

private struct ViewerThumb: View {
    let photo: EvidencePhoto
    let isSelected: Bool
    let resolvePhotoURL: (String) async -> URL?
    @State private var url: URL?

    var body: some View {
        MMCachedAsyncImage(path: photo.thumbnailPath ?? photo.filePath, signedURL: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default: Color.white.opacity(0.08)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .opacity(isSelected ? 1 : 0.6)
        .task(id: photo.id) {
            if let thumb = photo.thumbnailPath, let u = await resolvePhotoURL(thumb) { url = u } else { url = await resolvePhotoURL(photo.filePath) }
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
