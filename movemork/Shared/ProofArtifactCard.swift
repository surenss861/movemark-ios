//
//  ProofArtifactCard.swift
//  movemork
//
//  MoveMark proof artifact — photo-first evidence object with metadata strip.
//

import SwiftUI

struct ProofArtifactModel {
    var phaseEyebrow: String = "Room Proof"
    var phaseLabel: String = "Move-in"
    var roomName: String
    var photoCount: Int
    var issueCount: Int
    var verifiedLabel: String
    var savedLabel: String = "Saved to vault"
    var statusLabel: String?
    var statusTone: ProofStatusTone = .success
    var issueTags: [String] = []
}

struct ProofArtifactCard: View {
    let model: ProofArtifactModel
    var photoHeight: CGFloat = 168
    var cornerRadius: CGFloat = 20
    var imageName: String?
    var imageURL: URL?
    var showReportPeek: Bool = false
    var tagsVisible: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if showReportPeek {
                reportPeekLayer
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
            }
            artifactSurface
        }
    }

    private var reportPeekLayer: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MoveMarkTheme.Colors.paperSurface.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
                )
                .frame(height: 28)
                .offset(y: 6)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MoveMarkTheme.Colors.paperSurface.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.6), lineWidth: 1)
                )
                .frame(height: 36)
                .offset(y: 2)
        }
    }

    private var artifactSurface: some View {
        VStack(spacing: 0) {
            artifactHeader
            photoPane
            artifactFooter
        }
        .background(MoveMarkTheme.Colors.evidenceCard)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(MoveMarkTheme.Colors.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var artifactHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text("\(model.phaseEyebrow.uppercased()) · \(model.phaseLabel.uppercased())")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let statusLabel = model.statusLabel {
                    ProofStatusBadge(text: statusLabel, tone: model.statusTone)
                }
            }
            Text(model.roomName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var photoPane: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            MoveMarkTheme.Colors.fieldFill
                        }
                    }
                } else {
                    MoveMarkTheme.Colors.fieldFill
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.65))
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 64)

            if tagsVisible, !model.issueTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(model.issueTags.prefix(2).enumerated()), id: \.offset) { index, tag in
                        Text(tag)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .scaleEffect(reduceMotion ? 1 : (tagsVisible ? 1 : 0.92))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.34).delay(Double(index) * 0.04), value: tagsVisible)
                    }
                }
                .padding(10)
            }
        }
        .frame(height: photoHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 14)
    }

    private var artifactFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(MoveMarkTheme.Colors.cardStroke.opacity(0.65))
                .frame(height: 1)
                .padding(.top, 12)
            HStack(alignment: .center, spacing: 8) {
                Text("\(model.photoCount) photos · \(model.issueCount) issues")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                Spacer(minLength: 8)
                Text(model.savedLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.98))
            }
            .padding(.top, 10)
            Text(model.verifiedLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textMuted)
                .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}
