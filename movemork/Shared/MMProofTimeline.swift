//
//  MMProofTimeline.swift
//  movemork
//
//  Signature proof trail — what happened, what’s next, what’s missing.
//

import SwiftUI

struct MMProofTimelineRow: Identifiable, Equatable {
    let id: String
    let iconName: String
    let title: String
    let message: String
    var timestamp: String? = nil
    let status: Status

    enum Status: Equatable {
        case done
        case next
        case missing
        case failed

        var iconColor: Color {
            switch self {
            case .done:
                return MoveMarkTheme.Colors.primary
            case .next, .missing:
                return MoveMarkTheme.Colors.semanticWarning
            case .failed:
                return MoveMarkTheme.Colors.semanticDanger
            }
        }

        var railColor: Color {
            switch self {
            case .done:
                return MoveMarkTheme.Colors.primary.opacity(0.35)
            case .next, .missing:
                return MoveMarkTheme.Colors.semanticWarning.opacity(0.4)
            case .failed:
                return MoveMarkTheme.Colors.semanticDanger.opacity(0.35)
            }
        }
    }
}

struct MMProofTimeline: View {
    let title: String
    let rows: [MMProofTimelineRow]
    var highlightedRowID: String? = nil
    var appeared: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        MMCard(tone: .elevated, padding: 18, spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(MoveMarkTheme.Typography.caption)
                    .tracking(0.9)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .textCase(.uppercase)

                if rows.isEmpty {
                    Text("Your proof trail will show up here.")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            timelineRow(row, isLast: index == rows.count - 1)
                                .mmStaggeredAppear(isVisible: appeared, index: index)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timelineRow(_ row: MMProofTimelineRow, isLast: Bool) -> some View {
        let highlighted = highlightedRowID == row.id

        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(row.status.iconColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(MoveMarkTheme.Colors.subtleStroke, lineWidth: 1)
                        )
                    Image(systemName: row.iconName)
                        .font(MoveMarkTheme.Typography.button)
                        .foregroundStyle(row.status.iconColor)
                }

                if !isLast {
                    Rectangle()
                        .fill(row.status.railColor)
                        .frame(width: 2.5)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.title)
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if let timestamp = row.timestamp, !timestamp.isEmpty {
                        Text(timestamp)
                            .font(MoveMarkTheme.Typography.tinyMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.75))
                    }
                }

                Text(row.message)
                    .font(MoveMarkTheme.Typography.footnoteRegular)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    highlighted
                        ? MoveMarkTheme.Colors.primary.opacity(reduceMotion ? 0.12 : 0.18)
                        : Color.clear
                )
                .overlay {
                    if highlighted {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MoveMarkTheme.Colors.proofMint.opacity(0.35), lineWidth: 1)
                    }
                }
        )
        .animation(reduceMotion ? nil : MMMotion.fastFade, value: highlighted)
    }
}

// MARK: - Builders

enum MMProofTimelineBuilder {

    private static let trailDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func formatTimestamp(_ date: Date?) -> String? {
        guard let date else { return nil }
        return trailDateFormatter.string(from: date)
    }

    static func photoIssueLine(photos: Int, issues: Int) -> String {
        var parts: [String] = []
        parts.append(photos == 1 ? "1 photo" : "\(photos) photos")
        if issues > 0 {
            parts.append(issues == 1 ? "1 issue" : "\(issues) issues")
        }
        return parts.joined(separator: " · ")
    }

    static func vaultTrail(
        property: PropertyRecord,
        nextRoom: RoomRecord?,
        isExportReady: Bool
    ) -> [MMProofTimelineRow] {
        var rows: [MMProofTimelineRow] = []
        let uploaded = Set(property.vaultDocuments)

        let documentedRooms = property.rooms.filter { MMRoomProofMetrics.isDocumented($0) }
        let recentRooms = documentedRooms.sorted { lhs, rhs in
            let left = lhs.evidence.map(\.createdAt).max() ?? .distantPast
            let right = rhs.evidence.map(\.createdAt).max() ?? .distantPast
            return left > right
        }

        for room in recentRooms.prefix(3) {
            let photos = room.evidence.reduce(0) { $0 + $1.photoCount }
            let issues = room.evidence.flatMap(\.issueTags).count
            rows.append(
                MMProofTimelineRow(
                    id: "room-\(room.id.uuidString)",
                    iconName: "checkmark.circle.fill",
                    title: "\(room.name) proof saved",
                    message: photoIssueLine(photos: photos, issues: issues),
                    timestamp: formatTimestamp(room.evidence.map(\.createdAt).max()),
                    status: .done
                )
            )
        }

        if let nextRoom, !MMRoomProofMetrics.isDocumented(nextRoom) {
            rows.append(
                MMProofTimelineRow(
                    id: "room-\(nextRoom.id.uuidString)",
                    iconName: "camera.fill",
                    title: "\(nextRoom.name) still missing",
                    message: "Next step · add room photos",
                    timestamp: nil,
                    status: .next
                )
            )
        }

        if DocumentRepository.documentTypeQueryKeys(VaultDocumentType.lease.rawValue)
            .contains(where: { uploaded.contains($0) }) {
            rows.append(
                MMProofTimelineRow(
                    id: "doc-\(VaultDocumentType.lease.rawValue)",
                    iconName: "doc.fill",
                    title: "\(VaultDocumentType.lease.displayTitle) uploaded",
                    message: "PDF or file added",
                    timestamp: nil,
                    status: .done
                )
            )
        }

        if let missingDoc = PropertyStore.moveInRequiredDocumentTypes.first(where: { type in
            !DocumentRepository.documentTypeQueryKeys(type.rawValue).contains { uploaded.contains($0) }
        }) {
            rows.append(
                MMProofTimelineRow(
                    id: "doc-missing-\(missingDoc.rawValue)",
                    iconName: "doc.badge.plus",
                    title: "\(missingDoc.displayTitle) missing",
                    message: "Add receipts & lease docs",
                    timestamp: nil,
                    status: .missing
                )
            )
        }

        if isExportReady {
            rows.append(
                MMProofTimelineRow(
                    id: "report-ready",
                    iconName: "doc.richtext.fill",
                    title: "Report ready to make",
                    message: "Old damage is documented — you can make your report.",
                    timestamp: nil,
                    status: .next
                )
            )
        }

        return Array(rows.prefix(6))
    }

    static func roomProofTrail(
        rooms: [RoomRecord],
        nextRoom: RoomRecord?
    ) -> [MMProofTimelineRow] {
        guard !rooms.isEmpty else {
            return [
                MMProofTimelineRow(
                    id: "rooms-empty",
                    iconName: "door.left.hand.open",
                    title: "No rooms yet",
                    message: "Add a room to photograph move-in condition.",
                    timestamp: nil,
                    status: .missing
                )
            ]
        }

        return rooms.map { room in
            let photos = room.evidence.reduce(0) { $0 + $1.photoCount }
            let issues = room.evidence.flatMap(\.issueTags).count
            let isDone = photos > 0
            let isNext = nextRoom?.id == room.id && !isDone

            if isDone {
                return MMProofTimelineRow(
                    id: "room-\(room.id.uuidString)",
                    iconName: "checkmark.circle.fill",
                    title: "\(room.name) proof saved",
                    message: photoIssueLine(photos: photos, issues: issues),
                    timestamp: formatTimestamp(room.evidence.map(\.createdAt).max()),
                    status: .done
                )
            }

            if isNext {
                return MMProofTimelineRow(
                    id: "room-\(room.id.uuidString)",
                    iconName: "camera.fill",
                    title: "\(room.name) is next",
                    message: "Tap to add photos",
                    timestamp: nil,
                    status: .next
                )
            }

            return MMProofTimelineRow(
                id: "room-\(room.id.uuidString)",
                iconName: "circle.dashed",
                title: "\(room.name) not started",
                message: "Still needs photos",
                timestamp: nil,
                status: .missing
            )
        }
    }

    static func reportTrail(
        property: PropertyRecord?,
        readiness: MMNextBestActionMapper.ReportReadiness,
        latestExportLabel: String?
    ) -> [MMProofTimelineRow] {
        guard let property else {
            return [
                MMProofTimelineRow(
                    id: "no-vault",
                    iconName: "archivebox",
                    title: "No vault open",
                    message: "Open a vault to see your proof trail.",
                    timestamp: nil,
                    status: .missing
                )
            ]
        }

        var rows: [MMProofTimelineRow] = []
        let documented = property.rooms.filter { MMRoomProofMetrics.isDocumented($0) }.count
        let total = property.rooms.count
        let photos = property.rooms.flatMap(\.evidence).reduce(0) { $0 + $1.photoCount }

        rows.append(
            MMProofTimelineRow(
                id: "rooms-progress",
                iconName: documented == total && total > 0 ? "checkmark.circle.fill" : "camera.fill",
                title: total == 0 ? "No rooms yet" : "\(documented) of \(total) rooms ready",
                message: photos == 0 ? "Photograph what was already there in each room." : photoIssueLine(photos: photos, issues: property.rooms.flatMap(\.evidence).flatMap(\.issueTags).count),
                timestamp: nil,
                status: documented > 0 ? .done : .missing
            )
        )

        let uploaded = propertyStoreUploadedDocCount(property)
        let required = PropertyStore.moveInRequiredDocumentTypes.count
        rows.append(
            MMProofTimelineRow(
                id: "docs-progress",
                iconName: uploaded >= required ? "doc.fill" : "doc.badge.plus",
                title: uploaded >= required ? "Docs look good" : "Docs still needed",
                message: "\(uploaded) of \(required) key docs uploaded",
                timestamp: nil,
                status: uploaded >= required ? .done : .missing
            )
        )

        switch readiness {
        case .noVault:
            break
        case .notReady:
            rows.append(
                MMProofTimelineRow(
                    id: "report-blocked",
                    iconName: "lock.fill",
                    title: "Report not ready",
                    message: "Finish room proof and key docs first.",
                    timestamp: nil,
                    status: .missing
                )
            )
        case .readyToMake:
            rows.append(
                MMProofTimelineRow(
                    id: "report-ready",
                    iconName: "sparkles",
                    title: "Report ready to make",
                    message: "Your move-in evidence is strong enough.",
                    timestamp: nil,
                    status: .next
                )
            )
        case .processing:
            rows.append(
                MMProofTimelineRow(
                    id: "report-processing",
                    iconName: "clock.fill",
                    title: "Report processing",
                    message: "It will show up here when ready.",
                    timestamp: nil,
                    status: .next
                )
            )
        case .readyToShare:
            rows.append(
                MMProofTimelineRow(
                    id: "report-done",
                    iconName: "checkmark.seal.fill",
                    title: "Report ready",
                    message: latestExportLabel ?? "You can share it now.",
                    timestamp: nil,
                    status: .done
                )
            )
        case .failed:
            rows.append(
                MMProofTimelineRow(
                    id: "report-failed",
                    iconName: "xmark.octagon.fill",
                    title: "Report failed",
                    message: "Try making a new report.",
                    timestamp: nil,
                    status: .failed
                )
            )
        }

        return rows
    }

    private static func propertyStoreUploadedDocCount(_ property: PropertyRecord) -> Int {
        let uploaded = Set(property.vaultDocuments)
        return PropertyStore.moveInRequiredDocumentTypes.filter { type in
            DocumentRepository.documentTypeQueryKeys(type.rawValue).contains { uploaded.contains($0) }
        }.count
    }
}
