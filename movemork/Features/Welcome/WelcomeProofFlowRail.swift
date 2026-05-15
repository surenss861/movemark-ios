//
//  WelcomeProofFlowRail.swift
//  movemork
//
//  Premium flow strip — Photos → Proof → Report.
//

import SwiftUI

struct WelcomeProofFlowRail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            flowLine
            supportingLine
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 78)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            MoveMarkTheme.Colors.cardRaised.opacity(0.96),
                            MoveMarkTheme.Colors.card.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.75), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                .padding(1)
        }
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.08), radius: 10, y: 3)
    }

    private var flowLine: some View {
        HStack(spacing: 0) {
            flowNode(icon: "camera.fill", label: "Photos")
            flowArrow
            flowNode(icon: "checkmark.shield.fill", label: "Proof")
            flowArrow
            flowNode(icon: "doc.text.fill", label: "Report")
        }
        .frame(maxWidth: .infinity)
    }

    private var supportingLine: some View {
        Text("Save room photos. Lock your proof. Share a PDF.")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.72))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func flowNode(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.proofMint)
            }
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .lineLimit(1)
        }
    }

    private var flowArrow: some View {
        Text("→")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.7))
            .padding(.horizontal, 6)
    }
}
