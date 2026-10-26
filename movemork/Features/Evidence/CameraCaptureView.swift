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
//  Continuous capture: every shot goes straight into the room's pending photos and the camera stays live
//  (aim → shoot → shoot → Done). The top band names the room, counts the photos and suggests the next shot
//  from the room's checklist; the preview shows the whole frame (nothing cropped). Review, removal and
//  retakes happen on the room screen, reached from the latest-photo thumbnail or Done.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    var roomName: String = ""
    /// Photos already pending for this entry before the camera opened.
    var pendingCount: Int = 0
    /// Suggested shots, in order; the next one is shown above the preview.
    var prompts: [String] = []
    /// The encoded capture file's bytes; returns whether it joined the pending photos.
    var onCapture: (Data) -> Bool
    /// Back to the room with the photos taken (Done, or the thumbnail to review them).
    var onDone: () -> Void = {}
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> EvidenceCameraViewController {
        EvidenceCameraViewController(roomName: roomName, pendingCount: pendingCount, prompts: prompts,
                                     onCapture: onCapture, onDone: onDone, onCancel: onCancel)
    }

    func updateUIViewController(_ uiViewController: EvidenceCameraViewController, context: Context) {}
}

final class EvidenceCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let roomName: String
    private let prompts: [String]
    private let onCapture: (Data) -> Bool
    private let onDone: () -> Void
    private let onCancel: () -> Void
    private var total: Int
    private var takenHere = 0

    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "movemark.evidence-camera")
    private var device: AVCaptureDevice?
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var flashMode: AVCaptureDevice.FlashMode = .auto

    private let previewView = CameraPreviewView()
    private let roomLabel = UILabel()
    private let countLabel = UILabel()
    private let suggestionLabel = UILabel()
    private let shutterButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let thumbnailButton = UIButton(type: .custom)
    private let doneButton = UIButton(type: .system)
    private let flipButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let addedLabel = PaddedLabel()
    private let unavailableLabel = UILabel()

    /// The Vault's action colour (#CAE36C) and the ink on it.
    private static let lime = UIColor(red: 0.792, green: 0.890, blue: 0.424, alpha: 1)
    private static let onLime = UIColor(red: 0.067, green: 0.086, blue: 0.035, alpha: 1)

    init(roomName: String, pendingCount: Int, prompts: [String],
         onCapture: @escaping (Data) -> Bool, onDone: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.roomName = roomName
        self.total = pendingCount
        self.prompts = prompts
        self.onCapture = onCapture
        self.onDone = onDone
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
            guard let data, let preview = UIImage(data: data), self.onCapture(data) else {
                self.flash(message: "Couldn’t add that photo. Try again.")
                return
            }
            self.total += 1
            self.takenHere += 1
            self.thumbnailButton.setImage(preview.preparingThumbnail(of: CGSize(width: 120, height: 120)) ?? preview, for: .normal)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self.flash(message: "Photo added")
            self.refreshProgress()
        }
    }

    @objc private func cancelTapped() { onCancel() }

    @objc private func doneTapped() { onDone() }

    /// "Photo added" (or a failure) over the preview for a moment; VoiceOver hears it too.
    private func flash(message: String) {
        addedLabel.text = message
        UIAccessibility.post(notification: .announcement, argument: message)
        addedLabel.layer.removeAllAnimations()
        addedLabel.alpha = 1
        UIView.animate(withDuration: 0.3, delay: 1.1, options: [.beginFromCurrentState]) { self.addedLabel.alpha = 0 }
    }

    /// Room, count, next suggestion; Cancel until a photo is taken here, then the latest-photo thumbnail.
    private func refreshProgress() {
        countLabel.text = total == 0 ? "No photos yet" : total == 1 ? "1 photo captured" : "\(total) photos captured"
        suggestionLabel.text = total < prompts.count ? "Next: \(prompts[total])" : "Anything else worth recording"
        cancelButton.isHidden = takenHere > 0
        thumbnailButton.isHidden = takenHere == 0
        doneButton.isHidden = total == 0
    }

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

    private func showUnavailable() {
        unavailableLabel.isHidden = false
        shutterButton.isEnabled = false
        flipButton.isEnabled = false
    }

    private func buildInterface() {
        previewView.previewLayer.videoGravity = .resizeAspect  // show the whole frame; nothing is cropped

        roomLabel.text = roomName
        roomLabel.font = .preferredFont(forTextStyle: .headline)
        roomLabel.textColor = .white
        roomLabel.accessibilityTraits = .header
        countLabel.font = .preferredFont(forTextStyle: .footnote)
        countLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        countLabel.accessibilityIdentifier = "camera.count"
        suggestionLabel.font = .preferredFont(forTextStyle: .subheadline)
        suggestionLabel.textColor = .white
        suggestionLabel.numberOfLines = 2
        suggestionLabel.accessibilityIdentifier = "camera.suggestion"
        [roomLabel, countLabel, suggestionLabel].forEach { $0.adjustsFontForContentSizeCategory = true; $0.maximumContentSizeCategory = .accessibilityMedium }

        shutterButton.setImage(UIImage(systemName: "circle.inset.filled",
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 68, weight: .regular)), for: .normal)
        shutterButton.tintColor = .white
        shutterButton.accessibilityLabel = "Take Photo"
        shutterButton.accessibilityIdentifier = "camera.shutter"
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.accessibilityIdentifier = "camera.cancel"
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        thumbnailButton.imageView?.contentMode = .scaleAspectFill
        thumbnailButton.clipsToBounds = true
        thumbnailButton.layer.cornerRadius = 10
        thumbnailButton.layer.borderWidth = 1.5
        thumbnailButton.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        thumbnailButton.accessibilityLabel = "Review photos"
        thumbnailButton.accessibilityIdentifier = "camera.thumbnail"
        thumbnailButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        var done = UIButton.Configuration.filled()
        done.title = "Done"
        done.baseBackgroundColor = Self.lime
        done.baseForegroundColor = Self.onLime
        done.cornerStyle = .capsule
        done.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        doneButton.configuration = done
        doneButton.accessibilityIdentifier = "camera.done"
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        flipButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        flipButton.accessibilityLabel = "Switch Camera"
        flipButton.accessibilityIdentifier = "camera.flip"
        flipButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)

        flashButton.accessibilityLabel = "Flash"
        flashButton.accessibilityIdentifier = "camera.flash"
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)

        addedLabel.font = .preferredFont(forTextStyle: .subheadline)
        addedLabel.textColor = .white
        addedLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        addedLabel.layer.cornerRadius = 16
        addedLabel.clipsToBounds = true
        addedLabel.alpha = 0
        addedLabel.isAccessibilityElement = false

        unavailableLabel.text = "Camera unavailable"
        unavailableLabel.textColor = .white
        unavailableLabel.isHidden = true

        for control in [cancelButton, flipButton, flashButton] {
            control.tintColor = .white
            control.titleLabel?.font = .preferredFont(forTextStyle: .body)
        }
        let header = UIStackView(arrangedSubviews: [roomLabel, countLabel])
        header.axis = .vertical
        header.spacing = 2
        for subview in [previewView, header, suggestionLabel, shutterButton, cancelButton, thumbnailButton, doneButton,
                        flipButton, flashButton, addedLabel, unavailableLabel] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(lessThanOrEqualTo: flashButton.leadingAnchor, constant: -12),
            flipButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            flipButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 10),
            flashButton.trailingAnchor.constraint(equalTo: flipButton.leadingAnchor, constant: -20),
            flashButton.centerYAnchor.constraint(equalTo: flipButton.centerYAnchor),
            suggestionLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            suggestionLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            suggestionLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),

            previewView.topAnchor.constraint(equalTo: suggestionLabel.bottomAnchor, constant: 12),
            previewView.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -16),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            addedLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addedLabel.bottomAnchor.constraint(equalTo: previewView.bottomAnchor, constant: -16),

            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            cancelButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            thumbnailButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            thumbnailButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            thumbnailButton.widthAnchor.constraint(equalToConstant: 52),
            thumbnailButton.heightAnchor.constraint(equalToConstant: 52),
            doneButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            doneButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),

            unavailableLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            unavailableLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        updateFlashButton()
        refreshProgress()
    }
}

/// A label with room around its text (the "Photo added" capsule).
final class PaddedLabel: UILabel {
    private let insets = UIEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}

/// A view whose backing layer is the camera preview, so it resizes with Auto Layout.
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }  // swiftlint:disable:this force_cast
}
