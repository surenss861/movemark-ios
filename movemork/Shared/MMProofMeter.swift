//
//  MMProofMeter.swift
//  movemork
//
//  Signature MoveMark component: a simple “how protected am I?” meter.
//

import SwiftUI

struct MMProofMeter: View {
    let title: String
    let valueLine: String
    var subtitle: String? = nil
    /// 0...1
    let progress: Double
    var tone: Tone = .primary

    enum Tone {
        case primary
        case warning
        case neutral

        var barFill: Color {
            switch self {
            case .primary:
                return MoveMarkTheme.Colors.primary
            case .warning:
                return MoveMarkTheme.Colors.semanticWarning
            case .neutral:
                return MoveMarkTheme.Colors.panelStroke
            }
        }

        var badgeFill: Color {
            switch self {
            case .primary:
                return MoveMarkTheme.Colors.primary.opacity(0.16)
            case .warning:
                return MoveMarkTheme.Colors.semanticWarning.opacity(0.22)
            case .neutral:
                return MoveMarkTheme.Colors.mint.opacity(0.55)
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double {
        min(1, max(0, progress))
    }

    var body: some View {
        MMCard(tone: .artifact, padding: 18, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(tone.badgeFill)
                            .frame(width: 34, height: 34)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MoveMarkTheme.Colors.textDarkGreen)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(MoveMarkTheme.Typography.caption)
                            .tracking(0.8)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .textCase(.uppercase)

                        Text(valueLine)
                            .font(MoveMarkTheme.Typography.cardValue)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(MoveMarkTheme.Typography.subheadline)
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(MoveMarkTheme.Colors.panelStroke)
                            .frame(height: 6)

                        Capsule()
                            .fill(tone.barFill)
                            .frame(width: geo.size.width * clampedProgress, height: 6)
                            .animation(reduceMotion ? nil : MMMotion.proofProgress, value: clampedProgress)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

