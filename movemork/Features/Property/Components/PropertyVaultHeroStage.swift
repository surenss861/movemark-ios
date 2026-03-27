//
//  PropertyVaultHeroStage.swift
//  movemork
//
//  Compact vault header: title always visible, context optional, status secondary.
//

import SwiftUI

struct PropertyVaultHeroStage: View {
    let property: PropertyRecord
    let namespace: Namespace.ID?
    let heroStatusLine: String

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
            titleView(namespace: namespace)

            if let line = contextLine, !line.isEmpty {
                Text(line)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.62))
                    .lineLimit(1)
            }

            Text(heroStatusLine)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Group {
                if let namespace {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MoveMarkTheme.Colors.panel.opacity(0.78))
                        .matchedGeometryEffect(
                            id: "vault-bg-\(property.id.uuidString)",
                            in: namespace,
                            isSource: false
                        )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(MoveMarkTheme.Colors.panel.opacity(0.78))
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.34), lineWidth: 0.6)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func titleView(namespace: Namespace.ID?) -> some View {
        let baseTitle = Text(displayTitle)
            .font(.system(size: 24, weight: .bold))
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

        if !city.isEmpty && !province.isEmpty {
            return "\(city), \(province)"
        }

        if !city.isEmpty { return city }
        if !province.isEmpty { return province }

        let country = property.country.trimmingCharacters(in: .whitespacesAndNewlines)
        return country.isEmpty ? nil : country
    }
}
