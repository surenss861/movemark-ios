//
//  MoveMarkTheme.swift
//  movemork
//
//  MoveMark — Dark Rental Proof Desk (warm charcoal, calm green, paper artifacts).
//
//  @file Design tokens: colors, type scale (sans / serif / mono voices), spacing, radii
//  @domain design-system
//  @status stable
//  @see [[VISUAL_STANDARD]] — rules these tokens implement
//  @see [[MMTypography.kt]] — Android counterpart
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum MoveMarkTheme {
    enum Colors {
        // Shell — Proof System v2 (lighter surfaces for depth, not glow)
        static let appBackground = Color(red: 0.027, green: 0.071, blue: 0.055)           // #07120E
        static let appBackgroundRaised = Color(red: 0.039, green: 0.090, blue: 0.071)   // #0A1712
        static let surface = Color(red: 0.063, green: 0.137, blue: 0.106)               // #10231B

        // Cards — green-tinted (legacy) + neutral evidence surfaces (Evidence OS)
        static let card = Color(red: 0.063, green: 0.137, blue: 0.106)                  // #10231B
        static let cardRaised = Color(red: 0.075, green: 0.161, blue: 0.122)             // #13291F
        /// Welcome proof receipt. Near-neutral graphite so the artifact reads as a document
        /// rather than as another green surface; deliberately outside the card family above.
        static let evidenceReceipt = Color(red: 0.051, green: 0.063, blue: 0.055)      // #0D100E
        /// Welcome launch control body. The control is graphite, never emerald — emerald is
        /// worth more as the action indicator precisely because there is less of it.
        static let controlGraphite = Color(red: 0.067, green: 0.082, blue: 0.071)      // #111512
        /// The action chip. The only saturated brand colour in the dock.
        static let ctaActionEmerald = Color(red: 0.086, green: 0.600, blue: 0.345)     // #169958
        static let evidenceCard = Color(red: 0.082, green: 0.090, blue: 0.086)           // warm charcoal
        static let evidenceCardRaised = Color(red: 0.102, green: 0.110, blue: 0.106)
        static let cardStroke = Color.white.opacity(0.08)
        static let subtleStroke = Color.white.opacity(0.06)
        static let tabBarFill = Color(red: 0.031, green: 0.075, blue: 0.059).opacity(0.94) // #08130F

        static let forestGreen = Color(red: 0.039, green: 0.125, blue: 0.082)

        // Brand — calm green, lime only for tiny success accents
        static let primary = Color(red: 0.129, green: 0.722, blue: 0.400)               // #21B866
        static let primaryPressed = Color(red: 0.094, green: 0.588, blue: 0.310)       // #18A957-ish pressed

        static let limeAccent = Color(red: 0.608, green: 0.788, blue: 0.604)           // muted sage accent
        static let proofMint = Color(red: 0.545, green: 0.722, blue: 0.600)

        // Text (dark UI)
        static let textPrimary = Color(red: 0.949, green: 0.973, blue: 0.945)
        static let textSecondary = Color(red: 0.702, green: 0.757, blue: 0.718)        // lifted for contrast
        static let textMuted = Color(red: 0.494, green: 0.565, blue: 0.518)
        /// Body copy that must not compete with the CTA. `textSecondary` is sage, which reads
        /// as a third brand colour wherever it sits beside emerald; this is that value with
        /// the green pulled out. Warm ivory rather than white — white goes flat over video.
        static let textBodyNeutral = Color(red: 0.894, green: 0.886, blue: 0.863)       // #E4E2DC
        static let textOnPrimary = Color.white
        static let textOnLight = Color(red: 0.12, green: 0.18, blue: 0.14)
        static let textDarkGreen = proofMint
        static let textDeepGreen = proofMint

        /// Report / lease preview only — warm paper, never main card fill.
        static let paperSurface = Color(red: 0.910, green: 0.937, blue: 0.898)          // #E8EFE5

        /// Muted warm sage for thumbnails on dark cards.
        static let artifactPaper = Color(red: 0.867, green: 0.910, blue: 0.855)         // #DDE8DA

        static let divider = subtleStroke.opacity(0.75)
        static let fieldFill = Color(red: 0.055, green: 0.118, blue: 0.090)

        // Semantic
        static let semanticSuccess = primary
        static let semanticWarning = Color(red: 0.847, green: 0.604, blue: 0.118)
        static let semanticDanger = Color(red: 0.937, green: 0.357, blue: 0.357)
        static let semanticInfo = Color(red: 0.502, green: 0.729, blue: 0.886)
    }

    /// The four surface levels. Everything the user sees sits on exactly one of these;
    /// green is never a surface — it is reserved for the primary action and positive state.
    enum Surface {
        /// Level 0 — screen background.
        static let background = Colors.appBackground
        /// Level 1 — raised section / card. Near-neutral so green stays meaningful.
        static let raised = Color(red: 0.071, green: 0.094, blue: 0.082)           // #121815
        /// Level 2 — interactive row inside or beside a card.
        static let interactive = Color(red: 0.090, green: 0.114, blue: 0.102)      // #171D1A
        /// Level 3 — primary action fill.
        static let primaryAction = Colors.primary
    }

    enum Stroke {
        static let normal = Color.white.opacity(0.08)
        static let interactive = Color.white.opacity(0.12)
        static let selected = Colors.primary.opacity(0.26)
    }

    enum Radius {
        static let hero: CGFloat = 24
        static let card: CGFloat = 20
        static let row: CGFloat = 16
        static let button: CGFloat = 16
    }

    enum Spacing {
        static let screenHorizontal: CGFloat = 20
        static let panelPadding: CGFloat = 18
        static let cornerRadius: CGFloat = Radius.card
        /// Gap between top-level sections on a screen.
        static let sectionGap: CGFloat = 30
        /// Gap between sibling cards / rows in one section.
        static let cardGap: CGFloat = 10
        /// Vertical padding inside a list row.
        static let rowVertical: CGFloat = 14
        static let fieldHeight: CGFloat = 58
        static let buttonHeight: CGFloat = 58
        static let heroButtonHeight: CGFloat = 68
        static let heroTopInset: CGFloat = 4

        static let headerToFirstCard: CGFloat = 28
        static let cardStack: CGFloat = 12
        static let titleToSubtitle: CGFloat = 8
        static let subtitleToContent: CGFloat = 28

        /// Root tab rail content height (icons + labels; safe area is additional).
        static let rootTabBarContentHeight: CGFloat = 60
        /// Floating root dock footprint (height + gap above the home indicator).
        static let floatingDockHeight: CGFloat = 66
        static let floatingDockBottomInset: CGFloat = 12
        /// Scroll tail when the floating dock is visible. The shell's safe-area inset does not reach the
        /// tabs' scroll views (measured: they see only the home indicator), so the tail clears the whole
        /// dock and leaves breathing room above it.
        static let scrollTailRootTabChrome: CGFloat = floatingDockHeight + floatingDockBottomInset + 28
        static let scrollTailReportsTabChrome: CGFloat = scrollTailRootTabChrome
        static let scrollTailAccountTabChrome: CGFloat = scrollTailRootTabChrome
        /// Pushed signed-in flows (room proof, property detail) without tab bar.
        static let scrollTailFocusedSignedIn: CGFloat = 180
        static let scrollTailFocusedFlow: CGFloat = 24
        static let vaultExpansionScrollExtra: CGFloat = 0
    }

    enum Typography {
        #if os(iOS)
        // UIFontMetrics scales each size relative to the user's preferred text size,
        // respecting the Accessibility > Display & Text Size setting.
        private static func scaled(_ size: CGFloat, for style: UIFont.TextStyle) -> CGFloat {
            UIFontMetrics(forTextStyle: style).scaledValue(for: size)
        }

        // Redesign scale: page title → hero title → card title → row title → body → metadata → section label.
        static var pageTitle: Font { .system(size: scaled(38, for: .largeTitle), weight: .bold) }
        static var heroTitle: Font { .system(size: scaled(28, for: .title1), weight: .bold) }
        static var cardTitleCompact: Font { .system(size: scaled(20, for: .title3), weight: .semibold) }
        static var rowTitle: Font { .system(size: scaled(17, for: .body), weight: .semibold) }
        static var metadata: Font { .system(size: scaled(14, for: .footnote), weight: .regular) }
        static var sectionLabel: Font { .system(size: scaled(13, for: .footnote), weight: .semibold) }

        static var hero: Font { .system(size: scaled(36, for: .largeTitle), weight: .bold) }
        static var heroLarge: Font { .system(size: scaled(38, for: .largeTitle), weight: .bold) }
        static var screenTitle: Font { .system(size: scaled(34, for: .largeTitle), weight: .bold) }
        static var screenSubtitle: Font { .system(size: scaled(18, for: .title2), weight: .regular) }
        static var cardTitle: Font { .system(size: scaled(22, for: .title2), weight: .semibold) }
        static var cardValue: Font { .system(size: scaled(28, for: .title1), weight: .bold) }
        static var sectionTitle: Font { .system(size: scaled(18, for: .headline), weight: .semibold) }
        static var body: Font { .system(size: scaled(17, for: .body), weight: .regular) }
        static var bodyMedium: Font { .system(size: scaled(17, for: .body), weight: .medium) }
        static var subheadline: Font { .system(size: scaled(15, for: .subheadline), weight: .regular) }
        static var subheadlineMedium: Font { .system(size: scaled(15, for: .subheadline), weight: .semibold) }
        static var button: Font { .system(size: scaled(17, for: .callout), weight: .semibold) }
        static var footnote: Font { .system(size: scaled(13, for: .footnote), weight: .medium) }
        static var footnoteRegular: Font { .system(size: scaled(13, for: .footnote), weight: .regular) }
        static var footnoteEmphasis: Font { .system(size: scaled(13, for: .footnote), weight: .semibold) }
        static var caption: Font { .system(size: scaled(12, for: .caption1), weight: .medium) }
        static var captionEmphasis: Font { .system(size: scaled(12, for: .caption1), weight: .semibold) }
        static var subtitleLarge: Font { .system(size: scaled(20, for: .title3), weight: .semibold) }
        /// Wordmark — SF Pro, not rounded. Rounded read as playful against evidence positioning.
        static var wordmark: Font { .system(size: scaled(28, for: .title2), weight: .semibold) }
        /// Welcome editorial headline. Set on two lines by the screen, never one.
        static var welcomeHeadline: Font { .system(size: scaled(46, for: .largeTitle), weight: .bold) }
        static var welcomeBody: Font { .system(size: scaled(18, for: .body), weight: .regular) }
        static var welcomeControl: Font { .system(size: scaled(18, for: .callout), weight: .semibold) }
        static var welcomeSupporting: Font { .system(size: scaled(15.5, for: .subheadline), weight: .regular) }
        static var welcomeSupportingEmphasis: Font { .system(size: scaled(15.5, for: .subheadline), weight: .semibold) }
        // Proof receipt scale
        static var receiptLabel: Font { .system(size: scaled(14, for: .footnote), weight: .semibold) }
        static var receiptAmount: Font { .system(size: scaled(18, for: .callout), weight: .semibold) }
        static var receiptStatus: Font { .system(size: scaled(15.5, for: .subheadline), weight: .semibold) }
        static var receiptMeta: Font { .system(size: scaled(14.5, for: .footnote), weight: .regular) }
        static var receiptFooter: Font { .system(size: scaled(16, for: .callout), weight: .semibold) }
        static var bodySmallEmphasis: Font { .system(size: scaled(16, for: .callout), weight: .semibold) }
        static var detail: Font { .system(size: scaled(14, for: .footnote), weight: .regular) }
        static var detailMedium: Font { .system(size: scaled(14, for: .footnote), weight: .medium) }
        static var detailEmphasis: Font { .system(size: scaled(14, for: .footnote), weight: .semibold) }
        static var tiny: Font { .system(size: scaled(11, for: .caption2), weight: .regular) }
        static var tinyMedium: Font { .system(size: scaled(11, for: .caption2), weight: .medium) }
        static var tinyEmphasis: Font { .system(size: scaled(11, for: .caption2), weight: .semibold) }
        static var microLabel: Font { .system(size: scaled(10, for: .caption2), weight: .semibold) }
        /// Case-file display. Serif so evidence headings are not another SF label.
        static var editorialTitle: Font { .system(size: scaled(32, for: .title1), weight: .semibold, design: .serif) }
        static var coverageFigure: Font { .system(size: scaled(44, for: .largeTitle), weight: .medium, design: .serif) }
        static var statFigure: Font { .system(size: scaled(22, for: .title2), weight: .medium, design: .serif) }
        static var monoMeta: Font { .system(size: scaled(12, for: .caption1), weight: .medium, design: .monospaced) }
        static var kicker: Font { .system(size: scaled(11, for: .caption2), weight: .semibold) }
        /// Large sans hero heading ("Primary Bedroom"). Replaces the retired editorial serif on redesigned screens.
        static var roomTitle: Font { .system(size: scaled(34, for: .largeTitle), weight: .bold) }
        #else
        static let pageTitle: Font = .system(size: 38, weight: .bold)
        static let heroTitle: Font = .system(size: 28, weight: .bold)
        static let cardTitleCompact: Font = .system(size: 20, weight: .semibold)
        static let rowTitle: Font = .system(size: 17, weight: .semibold)
        static let metadata: Font = .system(size: 14, weight: .regular)
        static let sectionLabel: Font = .system(size: 13, weight: .semibold)
        static let hero: Font = .system(size: 36, weight: .bold)
        static let heroLarge: Font = .system(size: 38, weight: .bold)
        static let screenTitle: Font = .system(size: 34, weight: .bold)
        static let screenSubtitle: Font = .system(size: 18, weight: .regular)
        static let cardTitle: Font = .system(size: 22, weight: .semibold)
        static let cardValue: Font = .system(size: 28, weight: .bold)
        static let sectionTitle: Font = .system(size: 18, weight: .semibold)
        static let body: Font = .system(size: 17, weight: .regular)
        static let bodyMedium: Font = .system(size: 17, weight: .medium)
        static let subheadline: Font = .system(size: 15, weight: .regular)
        static let subheadlineMedium: Font = .system(size: 15, weight: .semibold)
        static let button: Font = .system(size: 17, weight: .semibold)
        static let footnote: Font = .system(size: 13, weight: .medium)
        static let footnoteRegular: Font = .system(size: 13, weight: .regular)
        static let footnoteEmphasis: Font = .system(size: 13, weight: .semibold)
        static let caption: Font = .system(size: 12, weight: .medium)
        static let captionEmphasis: Font = .system(size: 12, weight: .semibold)
        static let subtitleLarge: Font = .system(size: 20, weight: .semibold)
        static let wordmark: Font = .system(size: 28, weight: .semibold)
        static let welcomeHeadline: Font = .system(size: 46, weight: .bold)
        static let welcomeBody: Font = .system(size: 18, weight: .regular)
        static let welcomeControl: Font = .system(size: 18, weight: .semibold)
        static let welcomeSupporting: Font = .system(size: 15.5, weight: .regular)
        static let welcomeSupportingEmphasis: Font = .system(size: 15.5, weight: .semibold)
        static let receiptLabel: Font = .system(size: 14, weight: .semibold)
        static let receiptAmount: Font = .system(size: 18, weight: .semibold)
        static let receiptStatus: Font = .system(size: 15.5, weight: .semibold)
        static let receiptMeta: Font = .system(size: 14.5, weight: .regular)
        static let receiptFooter: Font = .system(size: 16, weight: .semibold)
        static let bodySmallEmphasis: Font = .system(size: 16, weight: .semibold)
        static let detail: Font = .system(size: 14, weight: .regular)
        static let detailMedium: Font = .system(size: 14, weight: .medium)
        static let detailEmphasis: Font = .system(size: 14, weight: .semibold)
        static let tiny: Font = .system(size: 11, weight: .regular)
        static let tinyMedium: Font = .system(size: 11, weight: .medium)
        static let tinyEmphasis: Font = .system(size: 11, weight: .semibold)
        static let microLabel: Font = .system(size: 10, weight: .semibold)
        static let editorialTitle: Font = .system(size: 32, weight: .semibold, design: .serif)
        static let coverageFigure: Font = .system(size: 44, weight: .medium, design: .serif)
        static let statFigure: Font = .system(size: 22, weight: .medium, design: .serif)
        static let monoMeta: Font = .system(size: 12, weight: .medium, design: .monospaced)
        static let roomTitle: Font = .system(size: 34, weight: .bold)
        static let kicker: Font = .system(size: 11, weight: .semibold)
        #endif
    }
}

// MARK: - Rental proof desk background

struct MMEmeraldBackground: View {
    var emphasizesHeroZone: Bool = false
    var emphasizesCTABloom: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    MoveMarkTheme.Colors.appBackgroundRaised,
                    MoveMarkTheme.Colors.appBackground,
                    MoveMarkTheme.Colors.surface
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    MoveMarkTheme.Colors.primary.opacity(emphasizesHeroZone ? 0.08 : 0.04),
                    MoveMarkTheme.Colors.proofMint.opacity(emphasizesHeroZone ? 0.03 : 0.02),
                    .clear
                ],
                center: UnitPoint(x: 0.42, y: emphasizesHeroZone ? 0.28 : 0.2),
                startRadius: 20,
                endRadius: reduceMotion ? 240 : (emphasizesHeroZone ? 420 : 340)
            )

            proofGridLayer.opacity(emphasizesHeroZone ? 0.08 : 0.05)

            grainLayer.opacity(0.03)

            if emphasizesCTABloom {
                RadialGradient(
                    colors: [
                        MoveMarkTheme.Colors.primary.opacity(0.06),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 1.0),
                    startRadius: 24,
                    endRadius: 280
                )
            }

            edgeVignette
        }
        .ignoresSafeArea()
    }

    private var edgeVignette: some View {
        RadialGradient(
            colors: [
                .clear,
                MoveMarkTheme.Colors.appBackground.opacity(0.28),
                MoveMarkTheme.Colors.appBackground.opacity(0.55)
            ],
            center: .center,
            startRadius: 160,
            endRadius: 560
        )
    }

    private var proofGridLayer: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(
                path,
                with: .color(MoveMarkTheme.Colors.cardStroke.opacity(0.18)),
                lineWidth: 0.45
            )
        }
        .allowsHitTesting(false)
    }

    private var grainLayer: some View {
        Canvas { context, size in
            // Larger step (fewer pixels) + Path(rect) instead of ellipseIn avoids
            // bezier-curve overhead for 1pt dots that are invisible at 0.03 opacity.
            let step: CGFloat = 6
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    if Int((x + y) / step) % 9 == 0 {
                        let rect = CGRect(x: x, y: y, width: 1, height: 1)
                        context.fill(
                            Path(rect),
                            with: .color(Color.white.opacity(0.025))
                        )
                    }
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

struct MMProofShellBackground: View {
    var emphasizesHeroZone: Bool = false
    var emphasizesCTABloom: Bool = false

    var body: some View {
        MMEmeraldBackground(
            emphasizesHeroZone: emphasizesHeroZone,
            emphasizesCTABloom: emphasizesCTABloom
        )
    }
}

extension View {
    func mmEmeraldBackground(heroFocus: Bool = false, ctaBloom: Bool = false) -> some View {
        background(
            MMEmeraldBackground(
                emphasizesHeroZone: heroFocus,
                emphasizesCTABloom: ctaBloom
            )
        )
    }

    func mmProofShellBackground(heroFocus: Bool = false, ctaBloom: Bool = false) -> some View {
        mmEmeraldBackground(heroFocus: heroFocus, ctaBloom: ctaBloom)
    }

    /// Layered case-file surface. Green stays out of the fill; emphasis only adds a soft light.
    func mmCaseFilePlate(cornerRadius: CGFloat = MoveMarkTheme.Radius.hero, emphasis: Bool = false) -> some View {
        modifier(MMCaseFilePlate(cornerRadius: cornerRadius, emphasis: emphasis))
    }

    /// Keeps scroll content below status bar / TestFlight chrome.
    func mmScrollContentTopInset(_ extra: CGFloat = 0) -> some View {
        safeAreaPadding(.top, extra)
    }
}

/// Clear spacer so scroll content clears the floating tab bar or bottom chrome.
struct MMSignedInScrollTailSpacer: View {
    enum Kind {
        case rootTab
        case reportsTab
        case accountTab
        case focusedSignedIn
    }

    let kind: Kind

    var body: some View {
        Color.clear.frame(height: height)
    }

    private var height: CGFloat {
        switch kind {
        case .rootTab:
            MoveMarkTheme.Spacing.scrollTailRootTabChrome
        case .reportsTab:
            MoveMarkTheme.Spacing.scrollTailReportsTabChrome
        case .accountTab:
            MoveMarkTheme.Spacing.scrollTailAccountTabChrome
        case .focusedSignedIn:
            MoveMarkTheme.Spacing.scrollTailFocusedSignedIn
        }
    }
}

private struct MMCaseFilePlate: ViewModifier {
    var cornerRadius: CGFloat
    var emphasis: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(MoveMarkTheme.Surface.raised)
                    .overlay {
                        if emphasis {
                            RadialGradient(
                                colors: [
                                    MoveMarkTheme.Colors.primary.opacity(0.11),
                                    .clear
                                ],
                                center: UnitPoint(x: 0.12, y: 0.0),
                                startRadius: 4,
                                endRadius: 240
                            )
                            .clipShape(shape)
                            .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .top) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.07), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 36)
                        .clipShape(shape)
                        .allowsHitTesting(false)
                    }
            }
            .overlay {
                shape.stroke(Color.white.opacity(emphasis ? 0.12 : 0.08), lineWidth: 0.5)
            }
            .compositingGroup()
            .shadow(
                color: Color(red: 0.012, green: 0.035, blue: 0.024).opacity(emphasis ? 0.55 : 0.28),
                radius: emphasis ? 22 : 8,
                x: 0,
                y: emphasis ? 14 : 4
            )
    }
}
