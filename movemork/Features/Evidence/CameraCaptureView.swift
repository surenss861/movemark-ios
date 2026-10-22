//
//  CameraCaptureView.swift
//  movemork
//
//  MoveMark — Camera capture for evidence photos (AVFoundation).
//  Present only after `MoveMarkCameraPermission.requestPresentationIfEligible` succeeds.
//
//  Returns the camera's encoded capture file — `AVCapturePhoto.fileDataRepresentation()` — which
//  becomes the immutable source evidence as-is. That is the processed photo file the camera pipeline
//  writes (HEIF where the device supports HEVC, otherwise JPEG), not RAW sensor data. It is captured at
//  the format's full resolution with quality prioritised; orientation comes from the rotation
//  coordinator and is recorded in the file's metadata, never by rotating pixels.
//
//  The screen mirrors the system camera it replaces: live preview, shutter, cancel, flip, flash, then
//  Retake / Use Photo.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    /// The encoded capture file's bytes.
    var onCapture: (Data) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> EvidenceCameraViewController {
        EvidenceCameraViewController(onCapture: onCapture, onCancel: onCancel)
    }

    func updateUIViewController(_ uiViewController: EvidenceCameraViewController, context: Context) {}
}

final class EvidenceCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let onCapture: (Data) -> Void
    private let onCancel: () -> Void

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "movemark.evidence-camera")
    private var device: AVCaptureDevice?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private var captured: Data?

    private let previewView = CameraPreviewView()
    private let reviewImageView = UIImageView()
    private let shutterButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let flipButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let retakeButton = UIButton(type: .system)
    private let useButton = UIButton(type: .system)
    private let unavailableLabel = UILabel()

    init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
        self.onCapture = onCapture
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildInterface()
        sessionQueue.async { [weak self] in self?.configureSession(position: .back) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    // MARK: Session

    private func configureSession(position: AVCaptureDevice.Position) {
        guard let camera = applyConfiguration(position: position) else {
            DispatchQueue.main.async { self.showUnavailable() }
            return
        }
        device = camera
        DispatchQueue.main.async { self.attachRotation(to: camera) }
        // Only after commitConfiguration(): startRunning() inside a configuration block raises an exception.
        if !session.isRunning { session.startRunning() }
    }

    /// One configuration transaction: input for `position`, photo output at the format's full resolution.
    private func applyConfiguration(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        session.inputs.forEach { session.removeInput($0) }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input)
        else { return nil }
        session.addInput(input)
        if !session.outputs.contains(output), session.canAddOutput(output) {
            session.addOutput(output)
        }
        output.maxPhotoQualityPrioritization = .quality
        if let largest = camera.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
            output.maxPhotoDimensions = largest  // the format's full resolution; never reduced
        }
        return camera
    }

    private func attachRotation(to camera: AVCaptureDevice) {
        previewView.previewLayer.session = session
        let coordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: previewView.previewLayer)
        rotation = coordinator
        previewRotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            DispatchQueue.main.async {
                if let connection = self?.previewView.previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }
        }
        flipButton.isEnabled = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
        updateFlashButton()
    }

    // MARK: Capture

    @objc private func shutterTapped() {
        guard device != nil else { return }
        shutterButton.isEnabled = false
        let captureAngle = rotation?.videoRotationAngleForHorizonLevelCapture
        let requestedFlash = flashMode
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // HEIF where supported (the iPhone camera's own default), JPEG otherwise.
            let settings = self.output.availablePhotoCodecTypes.contains(.hevc)
                ? AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                : AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            settings.maxPhotoDimensions = self.output.maxPhotoDimensions
            if self.output.supportedFlashModes.contains(requestedFlash) {
                settings.flashMode = requestedFlash
            }
            if let angle = captureAngle, let connection = self.output.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = error == nil ? photo.fileDataRepresentation() : nil
        #if DEBUG
        if let data { MMEvidenceAuditLog.record("camera.fileDataRepresentation", data) }
        #endif
        DispatchQueue.main.async {
            self.shutterButton.isEnabled = true
            guard let data, let preview = UIImage(data: data) else { return }
            self.captured = data
            self.reviewImageView.image = preview
            self.setReviewing(true)
        }
    }

    @objc private func useTapped() {
        guard let captured else { return }
        onCapture(captured)
    }

    @objc private func retakeTapped() {
        captured = nil
        reviewImageView.image = nil
        setReviewing(false)
    }

    @objc private func cancelTapped() { onCancel() }

    @objc private func flipTapped() {
        guard let current = device else { return }
        let next: AVCaptureDevice.Position = current.position == .back ? .front : .back
        sessionQueue.async { [weak self] in self?.configureSession(position: next) }
    }

    @objc private func flashTapped() {
        flashMode = switch flashMode {
        case .auto: .on
        case .on: .off
        default: .auto
        }
        updateFlashButton()
    }

    private func updateFlashButton() {
        let symbol = switch flashMode {
        case .on: "bolt.fill"
        case .off: "bolt.slash.fill"
        default: "bolt.badge.automatic.fill"
        }
        flashButton.setImage(UIImage(systemName: symbol), for: .normal)
        flashButton.accessibilityValue = switch flashMode { case .on: "On"; case .off: "Off"; default: "Auto" }
        flashButton.isHidden = !(device?.hasFlash ?? false)
    }

    // MARK: Interface

    private func setReviewing(_ reviewing: Bool) {
        reviewImageView.isHidden = !reviewing
        [retakeButton, useButton].forEach { $0.isHidden = !reviewing }
        [shutterButton, cancelButton, flipButton].forEach { $0.isHidden = reviewing }
        flashButton.isHidden = reviewing || !(device?.hasFlash ?? false)
    }

    private func showUnavailable() {
        unavailableLabel.isHidden = false
        shutterButton.isEnabled = false
        flipButton.isEnabled = false
    }

    private func buildInterface() {
        previewView.previewLayer.videoGravity = .resizeAspect  // show the whole frame; nothing is cropped
        reviewImageView.contentMode = .scaleAspectFit
        reviewImageView.backgroundColor = .black
        reviewImageView.isHidden = true

        shutterButton.setImage(UIImage(systemName: "circle.inset.filled",
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)), for: .normal)
        shutterButton.tintColor = .white
        shutterButton.accessibilityLabel = "Take Photo"
        shutterButton.accessibilityIdentifier = "camera.shutter"
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.accessibilityIdentifier = "camera.cancel"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        flipButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        flipButton.accessibilityLabel = "Switch Camera"
        flipButton.accessibilityIdentifier = "camera.flip"
        flipButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)

        flashButton.accessibilityLabel = "Flash"
        flashButton.accessibilityIdentifier = "camera.flash"
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)

        retakeButton.setTitle("Retake", for: .normal)
        retakeButton.accessibilityIdentifier = "camera.retake"
        retakeButton.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        useButton.setTitle("Use Photo", for: .normal)
        useButton.accessibilityIdentifier = "camera.use"
        useButton.addTarget(self, action: #selector(useTapped), for: .touchUpInside)
        [retakeButton, useButton].forEach { $0.isHidden = true }

        unavailableLabel.text = "Camera unavailable"
        unavailableLabel.textColor = .white
        unavailableLabel.isHidden = true

        for control in [cancelButton, flipButton, flashButton, retakeButton, useButton] {
            control.tintColor = .white
            control.titleLabel?.font = .preferredFont(forTextStyle: .body)
        }
        for subview in [previewView, reviewImageView, shutterButton, cancelButton, flipButton, flashButton, retakeButton, useButton, unavailableLabel] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 44),
            previewView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -120),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            reviewImageView.topAnchor.constraint(equalTo: previewView.topAnchor),
            reviewImageView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor),
            reviewImageView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            reviewImageView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),

            flashButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            flashButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),

            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -24),
            cancelButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            flipButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            flipButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),

            retakeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            retakeButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            useButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            useButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),

            unavailableLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            unavailableLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        updateFlashButton()
    }
}

/// A view whose backing layer is the camera preview, so it resizes with Auto Layout.
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }  // swiftlint:disable:this force_cast
}
