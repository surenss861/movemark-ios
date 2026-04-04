//
//  MoveMarkCameraPermission.swift
//  movemork
//
//  MoveMark — Central gate before presenting UIImagePickerController with `.camera`.
//

import AVFoundation
import UIKit

enum MoveMarkCameraPermission {
    /// Call before presenting camera UI. Handles hardware check, `notDetermined` prompt, and denied/restricted.
    @MainActor
    static func requestPresentationIfEligible(
        onPresentCamera: @escaping () -> Void,
        onNeedsSettingsAlert: @escaping () -> Void,
        onUnavailableMessage: @escaping (String) -> Void
    ) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            onUnavailableMessage("Camera isn’t available on this device.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onPresentCamera()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        onPresentCamera()
                    } else {
                        onNeedsSettingsAlert()
                    }
                }
            }

        case .denied, .restricted:
            onNeedsSettingsAlert()

        @unknown default:
            onUnavailableMessage("Camera isn’t available right now.")
        }
    }

    @MainActor
    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
