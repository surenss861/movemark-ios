//
//  PropertyVaultHeroStage.swift
//  movemork
//
//  Property vault header — rental proof folder, rooms + next step.
//

import SwiftUI

struct PropertyVaultHeroStage: View {
    let property: PropertyRecord
    let namespace: Namespace.ID?
    let documentedRooms: Int
    let totalRooms: Int
    let nextRoomName: String?
    let missingSupportingDocs: Int

    private let cornerRadius: CGFloat = 18

    var body: some View {
        Group {
            if let namespace {
                header(namespace: namespace)
            } else {
                header(namespace: nil)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func header(namespace: Namespace.ID?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Move-in proof")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.9))

            titleView(namespace: namespace)

            if let line = contextLine, !line.isEmpty {
                Text(line)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.75))
                    .lineLimit(1)
            }

            Text(roomsProgressLine)
                .font(MoveMarkTheme.Typography.subheadlineMedium)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.95))

            if let next = nextRoomName, !next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               totalRooms > 0, documentedRooms < totalRooms {
                Text("Next: \(next)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.92))
            }

            if missingSupportingDocs > 0 {
                Text(
                    missingSupportingDocs == 1
                        ? "Add your lease or deposit receipt when you can."
                        : "A few supporting records are still missing."
                )
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.85))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Group {
                if let namespace {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MoveMarkTheme.Colors.card.opacity(0.92))
                        .matchedGeometryEffect(
                            id: "vault-bg-\(property.id.uuidString)",
                            in: namespace,
                            isSource: false
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MoveMarkTheme.Colors.card.opacity(0.92))
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.55), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func titleView(namespace: Namespace.ID?) -> some View {
        let baseTitle = Text(displayTitle)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
            .lineLimit(2)
            .minimumScaleFactor(0.88)
            .fixedSize(horizontal: false, vertical: true)

        if let namespace {
            baseTitle
                .matchedGeometryEffect(
                    id: "vault-title-\(property.id.uuidString)",
                    in: namespace,
                    isSource: false
                )
        } else {
            baseTitle
        }
    }

    private var displayTitle: String {
        let title = property.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        let address = property.addressLine1.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.isEmpty { return address }
        return "Property"
    }

    private var contextLine: String? {
        let city = property.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let province = property.provinceState.trimmingCharacters(in: .whitespacesAndNewlines)
        if !city.isEmpty && !province.isEmpty { return "\(city), \(province)" }
        if !city.isEmpty { return city }
        if !province.isEmpty { return province }
        let country = property.country.trimmingCharacters(in: .whitespacesAndNewlines)
        return country.isEmpty ? nil : country
    }

    private var roomsProgressLine: String {
        if totalRooms == 0 { return "Add rooms to start move-in proof" }
        return "\(documentedRooms) of \(totalRooms) rooms ready"
    }
}
