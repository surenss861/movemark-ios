//
//  VaultCoverCard.swift
//  movemork
//
//  Compact cover + fold-out tray. Chevron at bottom seam; one card expanded at a time.
//

import SwiftUI

struct VaultCoverCard: View {
    let model: VaultCoverCardModel
    var expansion: VaultCoverExpansionContent? = nil
    @Binding var expandedVaultId: UUID?
    var namespace: Namespace.ID? = nil
    let onTap: () -> Void
    var onPreviewImageFailure: (() -> Void)? = nil

    private let nonFeaturedCornerRadius: CGFloat = 22
    private let featuredCornerRadius: CGFloat = 24
    private var cornerRadius: CGFloat { model.isEmphasized ? featuredCornerRadius : nonFeaturedCornerRadius }
    /// Secondary vaults: compact summary, not mini-heroes.
    private let nonFeaturedHeight: CGFloat = 152
    /// Active workspace: slightly shorter image slot; band carries proof hierarchy.
    private let featuredHeight: CGFloat = 220
    private var cardHeight: CGFloat { model.isEmphasized ? featuredHeight : nonFeaturedHeight }
    private let expandedTrayHeight: CGFloat = 94
    private let chevronStripHeight: CGFloat = 15

    private var isExpanded: Bool {
        expansion != nil && expandedVaultId == model.id
    }

    private var totalHeight: CGFloat {
        isExpanded ? cardHeight + expandedTrayHeight : cardHeight
    }

    var body: some View {
        PressResponsiveCard(action: onTap) { isPressed in
            VStack(spacing: 0) {
                coverSection(isPressed: isPressed)
                if let expansion, isExpanded {
                    VaultCoverExpandedTray(content: expansion)
                        .frame(height: expandedTrayHeight)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                }
            }
            .frame(height: totalHeight)
            .animation(MMMotion.expand, value: totalHeight)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        model.isEmphasized
                            ? MoveMarkTheme.Colors.primary.opacity(0.20)
                            : Color.white.opacity(0.04),
                        lineWidth: model.isEmphasized ? 1.0 : 0.5
                    )
            )
            .overlay(alignment: .top) {
                if model.isEmphasized {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 1)
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: .black.opacity(
                    isPressed
                        ? (model.isEmphasized ? 0.22 : 0.1)
                        : (model.isEmphasized ? 0.28 : 0.08)
                ),
                radius: isPressed
                    ? (model.isEmphasized ? 12 : 6)
                    : (model.isEmphasized ? 20 : 7),
                y: isPressed
                    ? (model.isEmphasized ? 5 : 2)
                    : (model.isEmphasized ? 11 : 4)
            )
            .animation(MMMotion.expand, value: isExpanded)
        }
    }

    private func coverSection(isPressed: Bool) -> some View {
        ZStack(alignment: .bottom) {
            backgroundLayer(isPressed: isPressed)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if let chipText = model.chipText, !chipText.isEmpty {
                        VaultStatusChip(text: chipText, showDot: model.isRecent)
                            .scaleEffect(isPressed && model.isEmphasized ? 0.985 : 1.0)
                            .animation(MMMotion.press, value: isPressed)
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
                Spacer(minLength: 0)

                VaultCoverBottomBand(
                    title: model.title,
                    city: model.city,
                    statusLine: model.statusLine,
                    workflowHeadline: model.workflowHeadline,
                    proofMetricsLine: model.proofMetricsLine,
                    nextAction: model.nextAction,
                    ctaTitle: model.ctaTitle,
                    isPressed: isPressed,
                    isEmphasized: model.isEmphasized,
                    namespace: namespace,
                    vaultId: model.id
                )

                if expansion != nil {
                    chevronHinge
                }
            }
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity)
    }

    private var chevronHinge: some View {
        Button {
            MMHaptics.soft()
            withAnimation(MMMotion.expand) {
                expandedVaultId = isExpanded ? nil : model.id
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.30))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(MMMotion.expand, value: isExpanded)
                .frame(maxWidth: .infinity)
                .frame(height: chevronStripHeight)
        }
        .buttonStyle(.plain)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func backgroundLayer(isPressed: Bool) -> some View {
        let background = VaultCoverBackground(
            propertyId: model.id,
            imageURL: model.previewImageURL,
            fallbackStyle: model.fallbackStyle,
            isPressed: isPressed,
            isEmphasized: model.isEmphasized,
            onPreviewReloadRequested: onPreviewImageFailure
        )
        if let ns = namespace {
            background
                .matchedGeometryEffect(id: "vault-bg-\(model.id.uuidString)", in: ns, isSource: true)
        } else {
            background
        }
    }
}
