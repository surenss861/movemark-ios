//
//  PropertyVaultHeroStage.swift
//  movemork
//
//  MoveMark — quiet rental-record header for the pushed workspace.
//

import SwiftUI

struct PropertyVaultHeroStage: View {
    let property: PropertyRecord
    let namespace: Namespace.ID?
    let documentedRooms: Int
    let totalRooms: Int
    let nextRoomName: String?
    let missingSupportingDocs: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RENTAL RECORD")
                .font(MoveMarkTheme.Typography.sectionLabel)
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)

            titleView

            if let line = contextLine, !line.isEmpty {
                Text(line)
                    .font(MoveMarkTheme.Typography.body)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(roomsProgressLine)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                if totalRooms > 0 {
                    Text("\(Int(progress * 100))%")
                        .font(MoveMarkTheme.Typography.metadata)
                        .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                }
            }

            if totalRooms > 0 {
                ProgressView(value: progress)
                    .tint(MoveMarkTheme.Colors.primary)
            }

            if let guidanceLine {
                Text(guidanceLine)
                    .font(MoveMarkTheme.Typography.metadata)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var titleView: some View {
        let title = Text(displayTitle)
            .font(MoveMarkTheme.Typography.pageTitle)
            .tracking(-0.8)
            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

        if let namespace {
            title.matchedGeometryEffect(
                id: "vault-title-\(property.id.uuidString)",
                in: namespace,
                isSource: false
            )
        } else {
            title
        }
    }

    private var progress: Double {
        guard totalRooms > 0 else { return 0 }
        return min(1, max(0, Double(documentedRooms) / Double(totalRooms)))
    }

    private var displayTitle: String {
        let title = property.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }

        let address = property.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.isEmpty { return address }

        return "Rental"
    }

    private var contextLine: String? {
        let line = RentalLocation.line(city: property.city, province: property.provinceState)
        if !line.isEmpty { return line }

        let country = RentalLocation.meaningful(property.country) ?? ""
        return country.isEmpty ? nil : country
    }

    private var roomsProgressLine: String {
        if totalRooms == 0 { return "No rooms added yet" }
        return "\(documentedRooms) of \(totalRooms) rooms documented"
    }

    private var guidanceLine: String? {
        if totalRooms == 0 {
            return "Add rooms to start move-in proof."
        }

        if let nextRoomName,
           !nextRoomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           documentedRooms < totalRooms {
            return "Next: \(nextRoomName)"
        }

        if missingSupportingDocs > 0 {
            return missingSupportingDocs == 1
                ? "One key supporting record is still missing."
                : "\(missingSupportingDocs) key supporting records are still missing."
        }

        return documentedRooms == totalRooms ? "Room proof is complete." : nil
    }
}
