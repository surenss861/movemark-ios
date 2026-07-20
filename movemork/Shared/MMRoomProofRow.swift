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
            var parts = ["Ready to review"]
            parts.append("\(photoCount) \(photoCount == 1 ? "photo" : "photos")")
            if issueCount > 0 {
                parts.append(issueCount == 1 ? "1 tag" : "\(issueCount) tags")
            }
            return parts.joined(separator: " · ")
        case .nextUp:
            return "Needs photos — tap to capture proof"
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
            MMCard(tone: .quiet, padding: 14, spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    indexBadge

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(roomName)
                                .font(MoveMarkTheme.Typography.cardTitle)
                                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                                .lineLimit(2)

                            if showsNextBadge {
                                MMPill(text: "Next", tone: .warning)
                            }
                        }

                        Text(status.detailLine)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                            .lineLimit(2)
                            .mmRowStatusTransition(value: status.detailLine)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isDocumented ? "checkmark.circle.fill" : "chevron.right")
                        .font(.system(size: isDocumented ? 22 : 14, weight: .medium))
                        .foregroundStyle(
                            isDocumented
                                ? MoveMarkTheme.Colors.semanticSuccess
                                : MoveMarkTheme.Colors.textSecondary
                        )
                }
                .frame(minHeight: 60)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var indexBadge: some View {
        let isNext = showsNextBadge
        ZStack {
            Circle()
                .fill(
                    isNext
                        ? MoveMarkTheme.Colors.primary.opacity(0.16)
                        : MoveMarkTheme.Colors.cardRaised.opacity(0.55)
                )
                .frame(width: 34, height: 34)

            Text("\(index)")
                .font(MoveMarkTheme.Typography.footnoteEmphasis)
                .foregroundStyle(
                    isNext
                        ? MoveMarkTheme.Colors.primary
                        : MoveMarkTheme.Colors.textSecondary
                )
        }
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
