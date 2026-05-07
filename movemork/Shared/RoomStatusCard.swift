//
//  RoomStatusCard.swift
//  movemork
//
//  Queue-style room card: next head, completed quieter, unfinished non-next with life.
//

import SwiftUI

struct RoomStatusCard: View {
    let room: RoomRecord
    let isNext: Bool
    /// When true, card briefly pulses (e.g. new queue head after room completion).
    var isPulsing: Bool = false
    let onTap: () -> Void

    private var isDone: Bool { !room.evidence.isEmpty }

    private var issueCount: Int {
        room.evidence.flatMap(\.issueTags).count + room.moveOutEvidence.flatMap(\.issueTags).count
    }

    private var photoCount: Int {
        room.evidence.reduce(0) { $0 + $1.photoCount } +
        room.moveOutEvidence.reduce(0) { $0 + $1.photoCount }
    }

    private var cardWidth: CGFloat { isNext ? 164 : 144 }

    private var needsMoreProof: Bool {
        isDone && photoCount < 2
    }

    private var stateLabel: String {
        if isNext { return "Next" }
        if !isDone { return "Not started" }
        if needsMoreProof { return "Needs more proof" }
        return "Captured"
    }

    private var topSurfaceColors: [Color] {
        if isNext {
            return [
                MoveMarkTheme.Colors.primary.opacity(0.20),
                MoveMarkTheme.Colors.fieldFill.opacity(0.88)
            ]
        } else if isDone {
            return [
                Color.white.opacity(0.08),
                Color.white.opacity(0.025)
            ]
        } else {
            return [
                MoveMarkTheme.Colors.fieldFill.opacity(0.95),
                MoveMarkTheme.Colors.fieldFill.opacity(0.72)
            ]
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: topSurfaceColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 94)

                    LinearGradient(
                        colors: [
                            .clear,
                            Color.black.opacity(isNext ? 0.48 : 0.56)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 94)

                    badge
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(room.name)
                        .font(isNext ? .system(size: 17, weight: .semibold) : .system(size: 15.5, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .lineLimit(1)

                    metadataLine
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: cardWidth, height: 154)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        isNext
                            ? MoveMarkTheme.Colors.panel.opacity(1.0)
                            : MoveMarkTheme.Colors.panel.opacity(isDone ? 0.88 : 0.93)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(
                        isNext
                            ? MoveMarkTheme.Colors.primary.opacity(0.38)
                            : MoveMarkTheme.Colors.panelStroke.opacity(isDone ? 0.42 : 0.62),
                        lineWidth: isNext ? 1.2 : 0.8
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .scaleEffect(isPulsing ? 1.02 : 1.0)
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(
                        MoveMarkTheme.Colors.primary.opacity(isPulsing ? 0.28 : 0.0),
                        lineWidth: 1.2
                    )
            }
            .animation(.easeInOut(duration: 0.22), value: isPulsing)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var badge: some View {
        if isDone {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.16))
                    .frame(width: 26, height: 26)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
            }
        } else if isNext {
            Text("NEXT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(MoveMarkTheme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    @ViewBuilder
    private var metadataLine: some View {
        if isDone {
            HStack(spacing: 8) {
                Text(stateLabel)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(
                        needsMoreProof
                            ? MoveMarkTheme.Colors.semanticWarning.opacity(0.92)
                            : MoveMarkTheme.Colors.textSecondary.opacity(0.88)
                    )

                Text("\(photoCount) photos")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.82))

                if issueCount > 0 {
                    Text("\(issueCount) issues")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(MoveMarkTheme.Colors.semanticWarning.opacity(0.92))
                }
            }
        } else if isNext {
            Text(stateLabel)
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
        } else {
            Text(stateLabel)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.72))
        }
    }
}
