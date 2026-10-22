//
//  EvidenceCaptureView+Photos.swift
//  movemork
//
//  Photo picker loading: picked files become source evidence via ``MMEvidencePicker``.
//

import SwiftUI
import PhotosUI

extension EvidenceCaptureView {
    func loadSelectedItems(_ items: [PhotosPickerItem]) {
        Task { @MainActor in
            let selection = await MMEvidencePicker.load(items)
            loadedSources = selection.sources
            loadedImages = selection.previews
            if let message = selection.rejectionMessage {
                errorMessage = message
            }
        }
    }
}
