//
//  MMRoomProofRow.swift
//  movemork
//
//  Proof Sprint rooms. Completed stays quiet, the current room is the star, the rest compress.
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
                parts.append(issueCount == 1 ? "1 issue" : "\(issueCount) issues")
            }
            parts.append("Documented")
            return parts.joined(separator: " · ")
        case .nextUp:
            return "Needs proof"
        case .needsPhotos:
            return "Needs proof"
        }
    }
}

struct MMRoomProofRow: View {
    let index: Int
    let roomName: String
    let status: MMRoomProofStatus
    let showsNextBadge: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Weight: Equatable {
        case current
        case stamped
        case upcoming
    }

    private var weight: Weight {
        if showsNextBadge { return .current }
        switch status {
        case .nextUp: return .current
        case .readyToReview: return .stamped
        case .needsPhotos: return .upcoming
        }
    }

    private var isDocumented: Bool {
        if case .readyToReview = status { return true }
        return false
    }

    var body: some View {
        Button(action: onTap) {
            rowLabel
        }
        .buttonStyle(MMCasePressStyle())
        .accessibilityElement(children: .combine)
        .animation(reduceMotion ? nil : MMMotion.expand, value: weight)
    }

    @ViewBuilder
    private var rowLabel: some View {
        switch weight {
        case .current:
            currentRoom
        case .stamped:
            quietRoom(stamped: true)
        case .upcoming:
            quietRoom(stamped: false)
        }
    }

    private var currentRoom: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT ROOM")
                .font(MoveMarkTheme.Typography.kicker)
                .tracking(1.15)
                .foregroundStyle(MoveMarkTheme.Colors.primary)

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(format: "%02d", index))
                    .font(MoveMarkTheme.Typography.monoMeta)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)

                Text(roomName)
                    .font(MoveMarkTheme.Typography.editorialTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            Text(status.detailLine)
                .font(MoveMarkTheme.Typography.metadata)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .mmRowStatusTransition(value: status.detailLine)

            statusTrack(filled: false)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mmCaseFilePlate(cornerRadius: MoveMarkTheme.Radius.card, emphasis: true)
    }

    private func quietRoom(stamped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(String(format: "%02d", index))
                    .font(MoveMarkTheme.Typography.monoMeta)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .fixedSize()

                VStack(alignment: .leading, spacing: 2) {
                    Text(roomName)
                        .font(MoveMarkTheme.Typography.rowTitle)
                        .foregroundStyle(
                            stamped
                                ? MoveMarkTheme.Colors.textPrimary.opacity(0.82)
                                : MoveMarkTheme.Colors.textSecondary
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(status.detailLine)
                        .font(MoveMarkTheme.Typography.caption)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                        .lineLimit(2)
                        .mmRowStatusTransition(value: status.detailLine)
                }

                Spacer(minLength: 0)

                Image(systemName: stamped ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: stamped ? 16 : 12, weight: .semibold))
                    .foregroundStyle(
                        stamped
                            ? MoveMarkTheme.Colors.primary
                            : MoveMarkTheme.Colors.textMuted.opacity(0.7)
                    )
            }

            if stamped {
                statusTrack(filled: true)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, stamped ? 8 : 6)
        .frame(minHeight: 44, alignment: .center)
        .opacity(stamped ? 1 : 0.78)
    }

    private func statusTrack(filled: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(MoveMarkTheme.Colors.primary.opacity(filled ? 0.85 : 0))
                    .frame(width: filled ? geo.size.width : 0)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

private struct MMCasePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(MMMotion.press, value: configuration.isPressed)
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
