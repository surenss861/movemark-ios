//
//  EvidenceCaptureView+Photos.swift
//  movemork
//
//  Photo picker loading: picked files become source evidence via ``MMEvidencePicker``.
//

import SwiftUI
import PhotosUI

extension EvidenceCaptureView {
    /// Removes one pending photo before saving. A library photo is deselected in the picker too (which
    /// reloads the library part); a camera shot is dropped directly.
    func removePendingPhoto(at index: Int) {
        guard loadedSources.indices.contains(index), loadedImages.indices.contains(index) else { return }
        if loadedSources[index].captureSource != .camera {
            let libraryIndex = loadedSources[..<index].filter { $0.captureSource != .camera }.count
            let libraryCount = loadedSources.filter { $0.captureSource != .camera }.count
            if libraryCount == selectedItems.count, selectedItems.indices.contains(libraryIndex) {
                selectedItems.remove(at: libraryIndex)
                return
            }
        }
        loadedSources.remove(at: index)
        loadedImages.remove(at: index)
    }

    func loadSelectedItems(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            let selection = await MMEvidencePicker.load(items)
            // The picker's selection is the library part of the pending set; camera shots stay.
            let camera = zip(loadedSources, loadedImages).filter { $0.0.captureSource == .camera }
            loadedSources = camera.map(\.0) + selection.sources
            loadedImages = camera.map(\.1) + selection.previews
            if let message = selection.rejectionMessage {
                errorMessage = message
            }
        }
    }
}
