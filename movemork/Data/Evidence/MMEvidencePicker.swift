//
//  MMEvidencePicker.swift
//  movemork
//
//  MoveMark — Photos picker items → source evidence. One loader for every evidence picker, so the
//  file bytes iOS supplies are the bytes that get preserved (see ``MMEvidenceImport``).
//
//  Pickers that feed evidence use `preferredItemEncoding: .current`, which asks Photos for the asset's
//  current file instead of a transcoded copy. Real-device behaviour is part of the evidence gate.
//

import PhotosUI
import SwiftUI

struct MMEvidenceSelection {
    var sources: [MMEvidenceSource] = []
    /// Display-only previews, index-aligned with `sources`.
    var previews: [UIImage] = []
    /// Set when at least one picked item couldn't become evidence (format, size, unreadable).
    var rejectionMessage: String?
}

enum MMEvidencePicker {
    static func load(_ items: [PhotosPickerItem]) async -> MMEvidenceSelection {
        var selection = MMEvidenceSelection()
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                selection.rejectionMessage = MMEvidenceImportError.unreadable.errorDescription
                continue
            }
            #if DEBUG
            MMEvidenceAuditLog.record("library.picker", data)
            #endif
            do {
                selection.append(try MMEvidenceImport.source(from: data, captureSource: .library))
            } catch {
                selection.rejectionMessage = error.localizedDescription
            }
        }
        return selection
    }
}

extension MMEvidenceSelection {
    mutating func append(_ source: MMEvidenceSource) {
        guard let preview = MMEvidenceImport.preview(from: source) else {
            rejectionMessage = MMEvidenceImportError.unreadable.errorDescription
            return
        }
        sources.append(source)
        previews.append(preview)
    }
}
