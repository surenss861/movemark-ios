//
//  MMProofEffects.swift
//  movemork
//
//  Core Animation polish — scanline, CTA glint, proof ring (app-wide).
//

import SwiftUI
import UIKit

// MARK: - Scanline

struct MMScanlineOverlay: UIViewRepresentable {
    var trigger: Int
    var intensity: CGFloat = 0.14

    func makeUIView(context: Context) -> ScanlineView {
        let view = ScanlineView(intensity: intensity)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ScanlineView, context: Context) {
        guard trigger > 0, trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger
        uiView.runScan()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastTrigger = 0
    }

    final class ScanlineView: UIView {
        private let intensity: CGFloat

        init(intensity: CGFloat) {
            self.intensity = intensity
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            intensity = 0.14
            super.init(coder: coder)
        }

        func runScan() {
            layer.sublayers?.filter { $0.name == "mm-scanline" }.forEach { $0.removeFromSuperlayer() }

            let line = CAGradientLayer()
            line.name = "mm-scanline"
            line.colors = [
                UIColor.clear.cgColor,
                UIColor.white.withAlphaComponent(intensity).cgColor,
                UIColor.clear.cgColor
            ]
            line.locations = [0, 0.5, 1]
            line.startPoint = CGPoint(x: 0, y: 0.5)
            line.endPoint = CGPoint(x: 1, y: 0.5)
            line.frame = CGRect(x: 0, y: -30, width: bounds.width, height: 36)
            layer.addSublayer(line)

            let move = CABasicAnimation(keyPath: "position.y")
            move.fromValue = -10
            move.toValue = bounds.height + 20
            move.duration = 0.85
            move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            line.add(move, forKey: "scan")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                line.removeFromSuperlayer()
            }
        }
    }
}

// MARK: - CTA glint

struct MMCTAGlintOverlay: UIViewRepresentable {
    var trigger: Int

    func makeUIView(context: Context) -> GlintView {
        let view = GlintView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: GlintView, context: Context) {
        guard trigger > 0, trigger != context.coordinator.lastTrigger else { return }
        context.coordinator.lastTrigger = trigger
        uiView.runGlint()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastTrigger = 0
    }

    final class GlintView: UIView {
        func runGlint() {
            layer.sublayers?.filter { $0.name == "mm-glint" }.forEach { $0.removeFromSuperlayer() }

            let glint = CAGradientLayer()
            glint.name = "mm-glint"
            glint.colors = [
                UIColor.clear.cgColor,
                UIColor.white.withAlphaComponent(0.2).cgColor,
                UIColor.clear.cgColor
            ]
            glint.locations = [0.35, 0.5, 0.65]
            glint.startPoint = CGPoint(x: 0, y: 0.5)
            glint.endPoint = CGPoint(x: 1, y: 0.5)
            glint.frame = CGRect(x: -bounds.width * 0.4, y: 0, width: bounds.width * 0.35, height: bounds.height)
            layer.addSublayer(glint)

            let move = CABasicAnimation(keyPath: "position.x")
            move.fromValue = -bounds.width * 0.2
            move.toValue = bounds.width * 1.1
            move.duration = 0.7
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)
            glint.add(move, forKey: "glint")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                glint.removeFromSuperlayer()
            }
        }
    }
}

// MARK: - Proof ring

struct MMProofRingOverlay: UIViewRepresentable {
    var progress: CGFloat

    func makeUIView(context: Context) -> RingView {
        let view = RingView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: RingView, context: Context) {
        uiView.setProgress(progress)
    }

    final class RingView: UIView {
        private let track = CAShapeLayer()
        private let ring = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            [track, ring].forEach { layer.addSublayer($0) }
            track.strokeColor = UIColor(white: 1, alpha: 0.12).cgColor
            track.fillColor = UIColor.clear.cgColor
            track.lineWidth = 2
            ring.strokeColor = UIColor(red: 0.718, green: 0.969, blue: 0.455, alpha: 0.85).cgColor
            ring.fillColor = UIColor.clear.cgColor
            ring.lineWidth = 2
            ring.lineCap = .round
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            let path = UIBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2)).cgPath
            track.path = path
            ring.path = path
        }

        func setProgress(_ value: CGFloat) {
            ring.strokeEnd = max(0, min(1, value))
        }
    }
}

// MARK: - View extensions

extension View {
    func mmScanline(trigger: Int, intensity: CGFloat = 0.14) -> some View {
        overlay {
            MMScanlineOverlay(trigger: trigger, intensity: intensity)
                .allowsHitTesting(false)
        }
    }

    func mmCTAGlint(trigger: Int) -> some View {
        overlay {
            MMCTAGlintOverlay(trigger: trigger)
                .allowsHitTesting(false)
        }
    }

    /// Back-compat for Welcome.
    func welcomeScanline(trigger: Int) -> some View {
        mmScanline(trigger: trigger)
    }

    func welcomeCTAGlint(trigger: Int) -> some View {
        mmCTAGlint(trigger: trigger)
    }
}
