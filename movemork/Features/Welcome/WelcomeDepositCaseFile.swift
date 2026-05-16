//
//  WelcomeDepositCaseFile.swift
//  movemork
//
//  Dark evidence desk — deposit case file hero (no lifestyle photo).
//

import SwiftUI

struct WelcomeDepositCaseFile: View {
    let maxWidth: CGFloat
    var cardVisible: Bool = true
    var statsVisible: Bool = true
    var scanlineTrigger: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cornerRadius: CGFloat = 30

    var body: some View {
        ZStack(alignment: .topLeading) {
            caseFileDropShadow
                .opacity(cardVisible ? 1 : 0)

            backingReportLayer
                .opacity(cardVisible ? 0.92 : 0)
                .offset(x: 10, y: 18)
                .rotationEffect(.degrees(-3.5))

            backingPaperSlab
                .opacity(cardVisible ? 1 : 0)
                .offset(x: 4, y: 12)
                .rotationEffect(.degrees(-1.4))

            VStack(alignment: .leading, spacing: 0) {
                folderTab
                    .padding(.leading, 22)
                    .padding(.bottom, -7)
                    .opacity(cardVisible ? 1 : 0)

                mainCaseFile
            }
            .opacity(cardVisible ? 1 : 0)
            .offset(y: cardVisible ? 0 : 12)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.5).delay(0.04), value: cardVisible)
        }
        .frame(maxWidth: maxWidth)
    }

    private var caseFileDropShadow: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.55))
            .frame(maxWidth: maxWidth)
            .frame(minHeight: 228)
            .blur(radius: 22)
            .offset(y: 16)
            .padding(.horizontal, 6)
    }

    private var backingReportLayer: some View {
        RoundedRectangle(cornerRadius: cornerRadius - 6, style: .continuous)
            .fill(MoveMarkTheme.Colors.paperSurface.opacity(0.055))
            .frame(maxWidth: maxWidth * 0.9, minHeight: 194)
            .overlay(reportLineTexture(opacity: 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 6, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.4), lineWidth: 0.7)
            )
    }

    private var backingPaperSlab: some View {
        RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Colors.paperSurface.opacity(0.07),
                        MoveMarkTheme.Colors.cardRaised.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(maxWidth: maxWidth * 0.96, minHeight: 204)
            .overlay(reportLineTexture(opacity: 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 4, style: .continuous)
                    .stroke(MoveMarkTheme.Colors.cardStroke.opacity(0.42), lineWidth: 0.65)
            )
    }

    private var folderTab: some View {
        ZStack(alignment: .leading) {
            WelcomeFolderTabShape()
                .fill(
                    LinearGradient(
                        colors: [
                            MoveMarkTheme.Colors.cardRaised,
                            MoveMarkTheme.Colors.card.opacity(0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 84, height: 20)
                .overlay(
                    WelcomeFolderTabShape()
                        .stroke(MoveMarkTheme.Colors.limeAccent.opacity(0.22), lineWidth: 0.8)
                )

            Text("CASE")
                .font(.system(size: 8, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(MoveMarkTheme.Colors.proofMint.opacity(0.85))
                .padding(.leading, 14)
                .padding(.bottom, 2)
        }
    }

    private var mainCaseFile: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("DEPOSIT CASE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.25)
                    .foregroundStyle(MoveMarkTheme.Colors.proofMint.opacity(0.9))

                Spacer(minLength: 0)

                Text("MM-2401")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.88))
            }

            Text("Move-in proof · Apr 14")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
                .padding(.top, 4)

            Text("$2,400")
                .font(.system(size: 42, weight: .bold))
                .tracking(-1.1)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .padding(.top, 12)

            Text("Ready to defend")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.98))
                .padding(.top, 5)

            Text("Proof file prepared")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.98))
                .padding(.top, 3)

            Rectangle()
                .fill(MoveMarkTheme.Colors.divider.opacity(0.55))
                .frame(height: 1)
                .padding(.top, 14)
                .padding(.bottom, 11)

            evidenceStatsRow
                .opacity(statsVisible ? 1 : 0)
                .offset(y: statsVisible ? 0 : 6)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.42).delay(0.12), value: statsVisible)

            evidenceArtifactRow
                .padding(.top, 10)
                .opacity(statsVisible ? 1 : 0)
                .offset(y: statsVisible ? 0 : 6)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.42).delay(0.16), value: statsVisible)
        }
        .padding(.horizontal, 20)
        .padding(.top, 17)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { caseFileRuledTexture }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(MoveMarkTheme.Colors.card.opacity(0.99))
        )
        .overlay { welcomeCaseFileTopHighlight }
        .overlay { welcomeCaseFileBorder }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.48), radius: 26, y: 14)
        .shadow(color: MoveMarkTheme.Colors.primary.opacity(0.12), radius: 18, y: 8)
        .mmScanline(trigger: reduceMotion ? 0 : scanlineTrigger, intensity: 0.1)
    }

    private var caseFileRuledTexture: some View {
        Canvas { context, size in
            let spacing: CGFloat = 16
            var y: CGFloat = 72
            while y < size.height - 10 {
                var path = Path()
                path.move(to: CGPoint(x: 14, y: y))
                path.addLine(to: CGPoint(x: size.width - 14, y: y))
                context.stroke(
                    path,
                    with: .color(MoveMarkTheme.Colors.cardStroke.opacity(0.16)),
                    lineWidth: 0.45
                )
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }

    private func reportLineTexture(opacity: Double) -> some View {
        Canvas { context, size in
            let spacing: CGFloat = 11
            var y: CGFloat = 18
            while y < size.height - 12 {
                var path = Path()
                path.move(to: CGPoint(x: 16, y: y))
                path.addLine(to: CGPoint(x: size.width - 16, y: y))
                context.stroke(
                    path,
                    with: .color(MoveMarkTheme.Colors.cardStroke.opacity(opacity)),
                    lineWidth: 0.4
                )
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }

    private var welcomeCaseFileTopHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.08),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.32)
                ),
                lineWidth: 1.2
            )
    }

    private var welcomeCaseFileBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        MoveMarkTheme.Colors.limeAccent.opacity(0.32),
                        MoveMarkTheme.Colors.cardStroke.opacity(0.95),
                        MoveMarkTheme.Colors.primary.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.15
            )
    }

    private var evidenceStatsRow: some View {
        HStack(spacing: 0) {
            statLabel("12 photos", emphasized: false)
            statSeparator
            statLabel("Lease saved", emphasized: true)
            statSeparator
            statLabel("Report ready", emphasized: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statLabel(_ text: String, emphasized: Bool) -> some View {
        Text(text)
            .font(.system(size: 13, weight: emphasized ? .semibold : .medium))
            .foregroundStyle(
                emphasized
                    ? MoveMarkTheme.Colors.textPrimary.opacity(0.94)
                    : MoveMarkTheme.Colors.textSecondary.opacity(0.96)
            )
    }

    private var statSeparator: some View {
        Text("·")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(MoveMarkTheme.Colors.textMuted.opacity(0.75))
            .padding(.horizontal, 8)
    }

    private var evidenceArtifactRow: some View {
        HStack(spacing: 9) {
            photosArtifactTile
            leaseArtifactTile
            reportArtifactTile
        }
    }

    private var photosArtifactTile: some View {
        artifactTileShell(label: "Photos") {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(MoveMarkTheme.Colors.fieldFill)
                    .frame(width: 34, height: 42)
                    .offset(x: 8, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(MoveMarkTheme.Colors.surface)
                    .frame(width: 36, height: 44)
                    .offset(x: 4, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                Image("welcome-kitchen-main")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.65)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 6)
            .padding(.horizontal, 8)
        }
    }

    private var leaseArtifactTile: some View {
        artifactTileShell(label: "Lease") {
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(MoveMarkTheme.Colors.primary.opacity(0.55))
                    .frame(width: 22, height: 3)

                docPreviewLine(width: 52, onPaper: true)
                docPreviewLine(width: 44, onPaper: true)
                docPreviewLine(width: 36, onPaper: true)

                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(MoveMarkTheme.Colors.artifactPaper.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(6)
        }
    }

    private var reportArtifactTile: some View {
        artifactTileShell(label: "Report") {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 5) {
                    docPreviewLine(width: 50, onPaper: true)
                    docPreviewLine(width: 42, onPaper: true)
                    docPreviewLine(width: 32, onPaper: true)
                    Spacer(minLength: 0)
                }
                .padding(9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(MoveMarkTheme.Colors.artifactPaper.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(6)

                ZStack {
                    Circle()
                        .stroke(MoveMarkTheme.Colors.primary.opacity(0.45), lineWidth: 1)
                        .background(Circle().fill(MoveMarkTheme.Colors.primary.opacity(0.12)))
                    Text("PDF")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(MoveMarkTheme.Colors.primaryPressed)
                }
                .frame(width: 22, height: 22)
                .offset(x: -10, y: 10)
            }
        }
    }

    private func docPreviewLine(width: CGFloat, onPaper: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(
                onPaper
                    ? MoveMarkTheme.Colors.cardStroke.opacity(0.55)
                    : MoveMarkTheme.Colors.textMuted.opacity(0.35)
            )
            .frame(width: width, height: 3)
    }

    private func artifactTileShell<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .frame(height: 52)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(MoveMarkTheme.Colors.surface.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(MoveMarkTheme.Colors.fieldFill.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(MoveMarkTheme.Colors.subtleStroke.opacity(0.75), lineWidth: 0.7)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

// MARK: - Folder tab shape

private struct WelcomeFolderTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = 6
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Desk ruled paper (screen backdrop)

struct WelcomeEvidenceDeskRuledPaper: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            var y: CGFloat = size.height * 0.1
            let endY = size.height * 0.5
            while y < endY {
                var path = Path()
                path.move(to: CGPoint(x: 28, y: y))
                path.addLine(to: CGPoint(x: size.width - 28, y: y))
                context.stroke(
                    path,
                    with: .color(MoveMarkTheme.Colors.cardStroke.opacity(0.1)),
                    lineWidth: 0.5
                )
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
