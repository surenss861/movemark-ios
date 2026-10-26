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
            MMInk.evidence.ignoresSafeArea()

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
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(MMInk.evidence.opacity(0.72), in: Circle())
                            .overlay(Circle().strokeBorder(MMInk.evidenceStroke, lineWidth: 0.75))
                    }
                    .accessibilityLabel("Close")
                    Spacer()
                    Text("\(index + 1) of \(photos.count)")
                        .mmFont(15, .medium)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background(MMInk.evidence.opacity(0.72), in: Capsule())
                        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
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

    var body: some View {
        MMEvidenceImage(path: photo.filePath, resolve: resolvePhotoURL, placeholder: MMInk.evidence, fit: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Evidence photo")
    }
}

private struct ViewerThumb: View {
    let photo: EvidencePhoto
    let isSelected: Bool
    let resolvePhotoURL: (String) async -> URL?

    var body: some View {
        MMEvidenceImage(path: photo.thumbnailPath ?? photo.filePath, resolve: resolvePhotoURL,
                        size: CGSize(width: 52, height: 52), placeholder: MMInk.evidenceRaised)
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
            .opacity(isSelected ? 1 : 0.6)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
