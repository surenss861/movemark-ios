//
//  MMRoomProofRow.swift
//  movemork
//
//  Room proof list row — documented vs next vs needs photos.
//

import SwiftUI

enum MMRoomProofStatus {
    case readyToReview(photoCount: Int, issueCount: Int)
    case nextUp
    case needsPhotos

    static func resolve(photoCount: Int, issueCount: Int, isNext: Bool) -> MMRoomProofStatus {
        if photoCount > 0 {
            return .readyToReview(photoCount: photoCount, issueCount: issueCount)
        }
        if isNext {
            return .nextUp
        }
        return .needsPhotos
    }

    var detailLine: String {
        switch self {
        case let .readyToReview(photoCount, issueCount):
            var parts = ["\(photoCount) \(photoCount == 1 ? "photo" : "photos")"]
            if issueCount > 0 {
                parts.append(issueCount == 1 ? "1 tag" : "\(issueCount) tags")
            }
            parts.append("Ready to review")
            return parts.joined(separator: " · ")
        case .nextUp:
            return "Needs photos"
        case .needsPhotos:
            return "Needs photos"
        }
    }
}

struct MMRoomProofRow: View {
    let index: Int
    let roomName: String
    let status: MMRoomProofStatus
    let showsNextBadge: Bool
    let onTap: () -> Void

    private var isDocumented: Bool {
        if case .readyToReview = status { return true }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 14) {
                indexBadge

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(roomName)
                            .font(MoveMarkTheme.Typography.rowTitle)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                            .lineLimit(1)

                        if showsNextBadge {
                            ProofStatusBadge(text: "Next", tone: .success)
                        }
                    }

                    Text(status.detailLine)
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .lineLimit(1)
                        .mmRowStatusTransition(value: status.detailLine)
                }

                Spacer(minLength: 0)

                Image(systemName: isDocumented ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: isDocumented ? 20 : 13, weight: .semibold))
                    .foregroundStyle(
                        isDocumented
                            ? MoveMarkTheme.Colors.primary
                            : MoveMarkTheme.Colors.textMuted
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous)
                    .fill(MoveMarkTheme.Surface.raised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous)
                    .stroke(showsNextBadge ? MoveMarkTheme.Stroke.selected : MoveMarkTheme.Stroke.normal, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: MoveMarkTheme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// Green only for the next room; done and pending rooms stay neutral.
    @ViewBuilder
    private var indexBadge: some View {
        let isNext = showsNextBadge
        ZStack {
            Circle()
                .fill(isNext ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Surface.interactive)
                .frame(width: 30, height: 30)

            Text("\(index)")
                .font(MoveMarkTheme.Typography.footnoteEmphasis)
                .foregroundStyle(isNext ? MoveMarkTheme.Colors.textOnPrimary : MoveMarkTheme.Colors.textSecondary)
        }
        .accessibilityHidden(true)
    }
}

enum MMRoomProofMetrics {
    static func photoCount(for room: RoomRecord) -> Int {
        room.evidence.reduce(0) { $0 + $1.photoCount }
    }

    static func issueCount(for room: RoomRecord) -> Int {
        room.evidence.flatMap(\.issueTags).count
    }

    static func isDocumented(_ room: RoomRecord) -> Bool {
        photoCount(for: room) > 0
    }
}
