//
//  ProofCaseChrome.swift
//  movemork
//

import SwiftUI

enum ProofCaseAccentRail {
    case none
    case saved
    case needsProof
}

struct ProofCaseHeader {
    var eyebrow: String
    var statusLabel: String?
    var statusTone: ProofStatusTone = .neutral
    var accentRail: ProofCaseAccentRail = .none
}

struct ProofCaseMetadataRow: View {
    let eyebrow: String
    var statusLabel: String?
    var statusTone: ProofStatusTone = .neutral

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(eyebrow.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let statusLabel {
                if statusTone == .success || statusTone == .warning {
                    ProofStatusBadge(text: statusLabel, tone: statusTone)
                } else {
                    Text(statusLabel.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusColor: Color {
        switch statusTone {
        case .success: MoveMarkTheme.Colors.primary.opacity(0.92)
        case .warning: MoveMarkTheme.Colors.semanticWarning
        case .danger: MoveMarkTheme.Colors.semanticDanger
        case .neutral: MoveMarkTheme.Colors.textMuted
        }
    }
}

struct ProofCaseDivider: View {
    var body: some View {
        Rectangle()
            .fill(MoveMarkTheme.Colors.cardStroke.opacity(0.65))
            .frame(height: 1)
    }
}

struct ProofCaseDetailSection: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ProofCaseReceiptRow: View {
    let savedTitle: String
    var timestampLabel: String?
    var statusBadge: String?
    var statusTone: ProofStatusTone = .success

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(savedTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                if let timestampLabel {
                    Text(timestampLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }

            Spacer(minLength: 8)

            if let statusBadge {
                ProofStatusBadge(text: statusBadge, tone: statusTone)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ProofCaseAccentRailOverlay: View {
    let rail: ProofCaseAccentRail
    let cornerRadius: CGFloat

    var body: some View {
        if rail == .none { EmptyView() } else {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(railColor)
                    .frame(width: 2)
                Spacer(minLength: 0)
            }
        }
    }

    private var railColor: Color {
        switch rail {
        case .saved: MoveMarkTheme.Colors.primary.opacity(0.72)
        case .needsProof: MoveMarkTheme.Colors.semanticWarning.opacity(0.72)
        case .none: .clear
        }
    }
}
