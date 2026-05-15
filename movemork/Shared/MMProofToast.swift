//
//  MMProofToast.swift
//  movemork
//
//  Shared proof feedback toasts — success, warning, danger, info.
//

import SwiftUI
import UIKit

struct MMProofToastMessage: Equatable, Identifiable {
    let id = UUID()
    let kind: Kind
    let title: String
    var message: String?

    enum Kind: Equatable {
        case success
        case warning
        case danger
        case info

        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger: return "xmark.octagon.fill"
            case .info: return "info.circle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .success: return MoveMarkTheme.Colors.primary
            case .warning: return MoveMarkTheme.Colors.semanticWarning
            case .danger: return MoveMarkTheme.Colors.semanticDanger
            case .info: return MoveMarkTheme.Colors.textDarkGreen
            }
        }

        var borderColor: Color {
            switch self {
            case .success: return MoveMarkTheme.Colors.primary.opacity(0.35)
            case .warning: return MoveMarkTheme.Colors.semanticWarning.opacity(0.45)
            case .danger: return MoveMarkTheme.Colors.semanticDanger.opacity(0.4)
            case .info: return MoveMarkTheme.Colors.panelStroke
            }
        }

        var backgroundTint: Color {
            switch self {
            case .success: return MoveMarkTheme.Colors.mint.opacity(0.75)
            case .warning: return MoveMarkTheme.Colors.semanticWarning.opacity(0.14)
            case .danger: return MoveMarkTheme.Colors.semanticDanger.opacity(0.1)
            case .info: return MoveMarkTheme.Colors.panel
            }
        }

        func playHaptic() {
            switch self {
            case .success: MMHaptics.success()
            case .warning: MMHaptics.warning()
            case .danger: MMHaptics.error()
            case .info: MMHaptics.soft()
            }
        }
    }

    // MARK: - Factory helpers

    static func proofSaved(moveOut: Bool = false) -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .success,
            title: "Proof saved",
            message: moveOut ? "Move-out proof is on this room." : "Photos are saved on this room."
        )
    }

    static func photosAdded(count: Int) -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .success,
            title: "Photos added",
            message: count == 1 ? "1 photo added." : "\(count) photos added."
        )
    }

    static func roomComplete(name: String) -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .success,
            title: "\(name) done",
            message: "Keep going with the next room."
        )
    }

    static func reportQueued() -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .info,
            title: "Report queued",
            message: "It will show up here when ready."
        )
    }

    static func reportReady() -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .success,
            title: "Report ready",
            message: "You can share it now."
        )
    }

    static func reportFailed() -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .danger,
            title: "Report failed",
            message: "Try making a new report."
        )
    }

    static func plansDidNotLoad() -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .warning,
            title: "Plans didn’t load",
            message: "Try again in a minute."
        )
    }

    static func documentUploaded(name: String) -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .success,
            title: "\(name) uploaded",
            message: "Your docs are getting stronger."
        )
    }

    static func exportsUnlocked() -> MMProofToastMessage {
        MMProofToastMessage(
            kind: .success,
            title: "Ready to make a report",
            message: "Your proof is strong enough."
        )
    }

    static func fromVaultFeedback(_ event: VaultFeedbackEvent) -> MMProofToastMessage {
        switch event {
        case .roomCompleted(let roomName):
            return roomComplete(name: roomName)
        case .moveOutRoomCompleted(let roomName):
            return MMProofToastMessage(
                kind: .success,
                title: "\(roomName) move-out done",
                message: "Move-out proof saved."
            )
        case .documentUploaded(let name):
            return documentUploaded(name: name)
        case .readinessImproved(let oldScore, let newScore):
            return MMProofToastMessage(
                kind: .success,
                title: "Proof progress up",
                message: "\(oldScore)% → \(newScore)%"
            )
        case .exportsUnlocked:
            return exportsUnlocked()
        }
    }
}

struct MMProofToast: View {
    let message: MMProofToastMessage

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: message.kind.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(message.kind.iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                if let subtitle = message.message, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(message.kind.backgroundTint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(message.kind.borderColor, lineWidth: 1)
        )
        .shadow(color: MoveMarkTheme.Colors.textPrimary.opacity(0.08), radius: 16, y: 8)
    }
}

// MARK: - Presenter helper

@MainActor
enum MMProofToastPresenter {
    static func show(
        _ toast: MMProofToastMessage,
        message: Binding<MMProofToastMessage?>,
        isVisible: Binding<Bool>,
        duration: TimeInterval = 2.2
    ) {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let messageID = toast.id
        toast.kind.playHaptic()
        message.wrappedValue = toast

        if reduceMotion {
            isVisible.wrappedValue = true
        } else {
            withAnimation(MMMotion.proofToastIn) {
                isVisible.wrappedValue = true
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if reduceMotion {
                isVisible.wrappedValue = false
            } else {
                withAnimation(MMMotion.proofToastOut) {
                    isVisible.wrappedValue = false
                }
            }
            try? await Task.sleep(for: .seconds(0.22))
            if message.wrappedValue?.id == messageID {
                message.wrappedValue = nil
            }
        }
    }
}

extension View {
    /// Top overlay for a single proof toast.
    func mmProofToast(
        message: MMProofToastMessage?,
        isVisible: Bool,
        horizontalPadding: CGFloat = MoveMarkTheme.Spacing.screenHorizontal
    ) -> some View {
        overlay(alignment: .top) {
            if isVisible, let message {
                MMProofToast(message: message)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
