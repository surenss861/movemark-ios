//
//  SupportingRecordRow.swift
//  movemork
//
//  Proof checklist row: icon well, title, optional subtitle, status pill, trailing action.
//

import SwiftUI

struct SupportingRecordRow: View {
    let title: String
    let subtitle: String?
    let isPresent: Bool
    @ViewBuilder let trailing: () -> AnyView

    init(
        title: String,
        subtitle: String? = nil,
        isPresent: Bool,
        @ViewBuilder trailing: @escaping () -> some View
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isPresent = isPresent
        self.trailing = { AnyView(trailing()) }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            iconWell

            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 3) {
                Text(title)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(MoveMarkTheme.Typography.footnoteRegular)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            HStack(spacing: 10) {
                statusPill
                trailing()
                    .fixedSize()
            }
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    private var iconWell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            MoveMarkTheme.Colors.fieldFill.opacity(0.98),
                            MoveMarkTheme.Colors.fieldFill.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.45), lineWidth: 0.8)
                )
                .frame(width: 38, height: 38)

            Image(systemName: isPresent ? "doc.fill" : "doc")
                .font(MoveMarkTheme.Typography.detailEmphasis)
                .foregroundStyle(isPresent ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Colors.textSecondary.opacity(0.82))
        }
    }

    private var statusPill: some View {
        ProofStatusBadge(text: isPresent ? "Added" : "Needed", tone: isPresent ? .success : .warning)
    }
}
