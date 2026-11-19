//
//  ListingProofSheet.swift
//  movemork
//
//  @file Listing proof as archived source material: the original listing image (when one is saved) with
//        the date it was added and "Source preserved", or a quiet empty frame explaining why it's worth
//        keeping — then the native PhotosPicker to add or replace it. The rental record presents this for
//        image records (Add, or Replace from the row's context menu); the upload itself stays in
//        PropertyVaultView.
//  @domain property
//  @see [[PropertyVaultView.swift]]
//

import SwiftUI
import PhotosUI

struct ReplacePhotoSheet: View {
    /// The listing image already on file.
    struct Current {
        let path: String
        var addedOn: Date?
        let resolve: (String) async -> URL?
    }

    let onDismiss: () -> Void
    @Binding var selection: PhotosPickerItem?
    var current: Current? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            MMSheetScaffold(title: "Listing proof") {
                Text(current == nil
                     ? "A screenshot of the original ad shows what was promised — appliances, finishes and condition — in the landlord's own words."
                     : "How the rental was advertised, kept with your record as source material.")
                    .mmFont(15)
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let current {
                    archived(current).padding(.top, 20)
                } else {
                    MMMissingPhotoFrame(label: "No listing saved yet")
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 120 : 180)
                        .padding(.top, 20)
                        .accessibilityLabel("No listing saved yet")
                }

                PhotosPicker(selection: $selection, matching: .images, preferredItemEncoding: .current) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 14, weight: .semibold))
                        Text(current == nil ? "Choose screenshot" : "Replace screenshot").mmFont(15.5, .semibold)
                    }
                    .foregroundStyle(MMInk.onLime)
                    .frame(maxWidth: .infinity, minHeight: MMMetrics.ctaHeight)
                    .background(MMInk.lime, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(MMLightPressStyle())
                .padding(.top, 22)

                Text(current == nil
                     ? "Saved as you chose it, with the date it was added."
                     : "The current image stays on file until the new one is saved.")
                    .mmFont(12.5)
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }

    private func archived(_ current: Current) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MMEvidenceImage(path: current.path, resolve: current.resolve, placeholder: MMInk.field, fit: true)
                .frame(maxWidth: .infinity)
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 320)
                .background(MMInk.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Original listing image")
            VStack(alignment: .leading, spacing: 3) {
                Text("Original listing").mmFont(15, .semibold).foregroundStyle(MMInk.text)
                if let date = current.addedOn {
                    Text("Added \(MMRecordDate.display(date))").mmFont(13).monospacedDigit().foregroundStyle(MMInk.secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal").font(.system(size: 12, weight: .semibold))
                    Text("Source preserved")
                }
                .mmFont(13, .medium)
                .foregroundStyle(MMInk.text)
                .padding(.top, 6)
            }
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
        }
        .padding(12)
        .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous)
            .strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
    }
}
