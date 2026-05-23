//
//  ProofImageHeader.swift
//  movemork
//
//  Photo/document evidence header — hero, thumbnail, or PDF preview.
//

import SwiftUI

enum ProofPhotoPaneSize {
    case large
    case medium
    case receipt
    case thumbnail
}

enum ProofImageHeaderSize {
    case thumbnail
    case hero
}

struct ProofIssueTag: Identifiable {
    let id: String
    let label: String
    var priorDamage: Bool = false
    var leadingInset: CGFloat = 0
}

struct ProofPhotoPane: View {
    var size: ProofPhotoPaneSize = .thumbnail
    var imageName: String? = nil
    var imageURL: URL? = nil
    var roomName: String? = nil
    var phaseLabel: String? = nil
    var phaseBadge: String? = nil
    var issueTags: [ProofIssueTag] = []
    var tagsVisible: Bool = true
    var showScanCorners: Bool = false
    var topCornerRadius: CGFloat = MoveMarkTheme.Spacing.cornerRadius

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let inspectionGreen = Color(red: 0.10, green: 0.48, blue: 0.32)

    var body: some View {
        switch size {
        case .thumbnail:
            thumbnailBody
        case .large, .medium, .receipt:
            heroBody
        }
    }

    private var thumbnailBody: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var thumbnailPlaceholder: some View {
        ZStack {
            MoveMarkTheme.Colors.fieldFill.opacity(0.95)
            Image(systemName: "camera.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.7))
        }
    }

    private var heroBody: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.black.opacity(0.35)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            VStack {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.22), Color.black.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 96)
            }
            .allowsHitTesting(false)

            if showScanCorners {
                focusBrackets
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let roomName {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(MoveMarkTheme.Colors.primary)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                                Text(roomName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                        }
                        if let phaseLabel {
                            Text(phaseLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                        }
                    }
                    Spacer(minLength: 8)
                    if let phaseBadge {
                        Text(phaseBadge)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)

                Spacer(minLength: 0)

                if !issueTags.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(issueTags.enumerated()), id: \.element.id) { index, tag in
                            evidenceMarker(tag.label, priorDamage: tag.priorDamage)
                                .padding(.leading, tag.leadingInset)
                                .scaleEffect(tagScale(for: index))
                                .animation(
                                    reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.78)
                                        .delay(0.04 + Double(index) * 0.05),
                                    value: tagsVisible
                                )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                topTrailingRadius: topCornerRadius
            )
        )
    }

    private func tagScale(for index: Int) -> CGFloat {
        guard !reduceMotion else { return 1 }
        return tagsVisible ? 1 : 0.9
    }

    private func evidenceMarker(_ label: String, priorDamage: Bool) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Circle()
                    .fill(priorDamage ? Color.white : inspectionGreen)
                    .frame(width: priorDamage ? 7 : 5, height: priorDamage ? 7 : 5)
                Rectangle()
                    .fill(Color.white.opacity(0.65))
                    .frame(width: 1, height: priorDamage ? 10 : 7)
            }
            .padding(.trailing, 5)

            Text(label)
                .font(.system(size: priorDamage ? 12 : 11, weight: priorDamage ? .bold : .semibold))
                .foregroundStyle(Color.white.opacity(priorDamage ? 1 : 0.96))
                .padding(.horizontal, priorDamage ? 10 : 9)
                .padding(.vertical, 5)
                .background {
                    if priorDamage {
                        Capsule().fill(Color.black.opacity(0.82))
                        Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1.15)
                    } else {
                        Capsule().fill(inspectionGreen.opacity(0.92))
                        Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
                }
        }
        .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)
    }

    private var focusBrackets: some View {
        let len: CGFloat = 18
        let pad: CGFloat = 12
        return ZStack {
            bracketView(length: len, corner: .topLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(pad)
            bracketView(length: len, corner: .topRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(pad)
            bracketView(length: len, corner: .bottomLeft)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(pad)
            bracketView(length: len, corner: .bottomRight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(pad)
        }
        .allowsHitTesting(false)
    }

    private func bracketView(length: CGFloat, corner: ProofBracketCorner) -> some View {
        ProofFocusBracket(length: length, corner: corner)
            .stroke(Color.white.opacity(0.58), lineWidth: 1.5)
            .frame(width: length, height: length)
    }
}

private enum ProofBracketCorner {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct ProofFocusBracket: Shape {
    let length: CGFloat
    let corner: ProofBracketCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = min(length, min(rect.width, rect.height))
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: 0, y: l))
            path.addLine(to: .zero)
            path.addLine(to: CGPoint(x: l, y: 0))
        case .topRight:
            path.move(to: CGPoint(x: rect.width - l, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: l))
        case .bottomLeft:
            path.move(to: CGPoint(x: 0, y: rect.height - l))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.addLine(to: CGPoint(x: l, y: rect.height))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.width, y: rect.height - l))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: rect.width - l, y: rect.height))
        }
        return path
    }
}

/// Stacked PDF preview for report case cards (not a room photo).
struct ProofDocumentPreview: View {
    var large: Bool = true
    var isBright: Bool = true
    var isProcessing: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if large {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MoveMarkTheme.Colors.evidenceCardRaised.opacity(0.9))
                    .frame(width: 58, height: 88)
                    .offset(x: 10, y: -8)
                    .rotationEffect(.degrees(5))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MoveMarkTheme.Colors.evidenceCardRaised.opacity(0.95))
                    .frame(width: 60, height: 92)
                    .offset(x: 5, y: -4)
                    .rotationEffect(.degrees(2.5))
            }
            sheet
        }
        .frame(width: large ? 88 : 52, height: large ? 116 : 68)
        .opacity(isProcessing && !reduceMotion ? processingAlpha : 1)
    }

    @State private var processingAlpha: Double = 0.88

    private var sheet: some View {
        RoundedRectangle(cornerRadius: large ? 14 : 10, style: .continuous)
            .fill(MoveMarkTheme.Colors.paperSurface.opacity(isBright ? 0.98 : 0.9))
            .frame(width: large ? 72 : 52, height: large ? 108 : 68)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: large ? 6 : 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isBright ? MoveMarkTheme.Colors.primary.opacity(0.85) : MoveMarkTheme.Colors.semanticWarning.opacity(0.75))
                        .frame(width: large ? 36 : 28, height: large ? 5 : 4)
                    ForEach(0..<(large ? 3 : 2), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.08))
                            .frame(width: large ? 40 : 32, height: large ? 4 : 3)
                    }
                    Spacer(minLength: 0)
                    Text("PDF")
                        .font(.system(size: large ? 10 : 9, weight: .bold))
                        .foregroundStyle(large && isBright ? MoveMarkTheme.Colors.primaryPressed : MoveMarkTheme.Colors.textMuted)
                }
                .padding(large ? 12 : 8)
            }
    }
}

typealias ProofImageHeader = ProofPhotoPane
