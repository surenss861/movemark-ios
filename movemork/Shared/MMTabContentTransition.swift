//
//  MMTabContentTransition.swift
//  movemork
//
//  Root-tab page switching (1.4.1). The rules this file exists to keep:
//  - Pages never crossfade against each other. The shell swaps the visible page in one frame; the page being
//    left is gone in the same frame the new one appears, so two titles are never on screen together.
//  - The dark header is never animated. Every root page draws the same dark band with the wordmark in the same
//    place, so swapping pages in one frame reads as a fixed header whose title is replaced.
//  - The only thing that may move is the new page's content region (the light sheet's contents), and only in
//    the directional / dissolve variants: see ``MMNavVariant``.
//
//  Why the 1.4 switch showed a grey wash and ghost titles: it put the incoming page on top of the outgoing one
//  and faded it in with `.opacity(incomingOpacity)` on the page root. SwiftUI's `.opacity` on a container is
//  not a group opacity; it is applied to every layer of the page separately. The incoming page's bottom layer
//  is a full-screen light sheet colour (`.background(Ink.sheet.ignoresSafeArea())`), so mid-fade that light
//  layer lay translucently over the whole outgoing page (grey wash over the dark header, the whole screen
//  dimmed/greyed), then the incoming dark header and white title were drawn translucently on top of it while
//  the outgoing title stayed fully opaque underneath (two titles, ghosting).
//

import SwiftUI

// MARK: - Variants

/// How the new page's content region arrives. The header and the page swap itself are the same in every one.
enum MMNavVariant: String, CaseIterable, Identifiable {
    /// A: the content switches instantly; only the dock animates.
    case instant = "A"
    /// B: the new content region moves a few points in the direction of travel while it resolves.
    case directional = "B"
    /// C: the new content region resolves in place, no movement.
    case dissolve = "C"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instant: "A · Instant"
        case .directional: "B · Directional"
        case .dissolve: "C · Dissolve"
        }
    }

    /// What ships when the internal nav lab is compiled out. See the 1.4.1 nav report for why.
    static let shipping: MMNavVariant = .directional

    /// The variant in use. Only internal `MM_NAV_LAB` builds can change it (Account row, or the
    /// `-MMNavVariant A|B|C` launch argument); every other build, including the App Store build, uses ``shipping``.
    static var current: MMNavVariant {
        #if MM_NAV_LAB
        if let raw = UserDefaults.standard.string(forKey: MMNavLab.variantKey), let v = MMNavVariant(rawValue: raw) {
            return v
        }
        #endif
        return shipping
    }
}

// MARK: - Entrance (shell → page)

/// What the shell asks the newly selected page's content region to do. A new `token` restarts it, so the latest
/// tap always wins and nothing queues.
struct MMTabEntrance: Equatable {
    enum Style: Equatable {
        /// Content is already in place (variant A, Reduce Motion with A, or a tap that interrupted a switch).
        case none
        /// Content moves `MMMotion.tabContentShift` points along x; `fromTrailing` when the destination is to the right.
        case directional(fromTrailing: Bool)
        /// Content resolves in place.
        case dissolve
        /// Reduce Motion: a short dissolve, no spatial motion.
        case reducedDissolve
    }

    var token = 0
    var style: Style = .none

    static let rest = MMTabEntrance()

    static func style(for variant: MMNavVariant, from: RootTab, to: RootTab, reduceMotion: Bool) -> Style {
        switch variant {
        case .instant:
            return .none
        case .directional:
            return reduceMotion ? .reducedDissolve : .directional(fromTrailing: to.dockIndex > from.dockIndex)
        case .dissolve:
            return reduceMotion ? .reducedDissolve : .dissolve
        }
    }
}

extension RootTab {
    /// Left-to-right position in the dock; gives the directional variant its direction.
    var dockIndex: Int {
        switch self {
        case .vaults: 0
        case .exports: 1
        case .account: 2
        }
    }
}

extension EnvironmentValues {
    /// Set by the root-tab shell on each page; read by ``View/mmTabContentRegion(cover:)``.
    @Entry var mmTabEntrance: MMTabEntrance = .rest
}

extension View {
    /// Marks a root page's content region (the sheet's contents, inside the sheet background, never the header).
    /// On a tab switch only this region moves / resolves; at rest it is an exact no-op (zero balanced padding,
    /// a fully transparent cover), so settled pages render pixel-identically.
    ///
    /// `cover` is the colour directly behind the content (the sheet). Resolving is a sheet-coloured cover
    /// fading off the content rather than `.opacity` on the content: that is what a flattened fade of the
    /// content over its sheet looks like, without SwiftUI fading each layer separately or an offscreen pass.
    func mmTabContentRegion(cover: Color) -> some View {
        modifier(MMTabContentRegionModifier(cover: cover))
    }
}

private struct MMTabContentRegionModifier: ViewModifier {
    let cover: Color
    @Environment(\.mmTabEntrance) private var entrance

    struct Frame {
        /// Horizontal displacement of the content (pt). Balanced padding, never `.offset`: even a zero offset
        /// changes how text is rasterised and breaks the snapshot goldens.
        var shift: CGFloat = 0
        /// Opacity of the sheet-coloured cover over the content (0 = content fully visible).
        var cover: Double = 0
    }

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Frame(), trigger: entrance) { content, frame in
            content
                .padding(.leading, frame.shift)
                .padding(.trailing, -frame.shift)
                .overlay {
                    cover.opacity(frame.cover)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
        } keyframes: { _ in
            let style = entrance.style
            KeyframeTrack(\.shift) {
                switch style {
                case .directional(let fromTrailing):
                    MoveKeyframe(fromTrailing ? MMMotion.tabContentShift : -MMMotion.tabContentShift)
                    CubicKeyframe(0, duration: MMMotion.tabContentMoveDuration)
                default:
                    MoveKeyframe(0)
                }
            }
            KeyframeTrack(\.cover) {
                switch style {
                case .none:
                    MoveKeyframe(0)
                case .directional:
                    MoveKeyframe(MMMotion.tabContentCoverStart)
                    CubicKeyframe(0, duration: MMMotion.tabContentFadeDuration)
                case .dissolve:
                    MoveKeyframe(MMMotion.tabContentCoverStart)
                    CubicKeyframe(0, duration: MMMotion.tabContentDissolveDuration)
                case .reducedDissolve:
                    MoveKeyframe(MMMotion.tabContentCoverStart)
                    LinearKeyframe(0, duration: MMMotion.tabContentReducedDuration)
                }
            }
        }
    }
}

// MARK: - Internal nav lab (MM_NAV_LAB builds only)

#if MM_NAV_LAB
/// Internal builds compiled with `MM_NAV_LAB` only: pick the content variant and dock style on a device.
/// Never compiled into the App Store configuration (MoveMarkApp.xcconfig blanks the flag for Release).
enum MMNavLab {
    /// Also a launch argument: `-MMNavVariant A|B|C` (the argument domain wins over the stored value).
    static let variantKey = "MMNavVariant"
    /// Also a launch argument: `-MMNavDock classic|pill`.
    static let dockKey = "MMNavDock"
}

/// The Account row in internal builds: content variant + dock style, applied on the next tab switch.
struct MMNavLabRow: View {
    @AppStorage(MMNavLab.variantKey) private var variant: String = MMNavVariant.shipping.rawValue
    @AppStorage(MMNavLab.dockKey) private var dock: String = MMDockStyle.shipping.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAV LAB (internal build)")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Picker("Tab content", selection: $variant) {
                ForEach(MMNavVariant.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("navlab.variant")
            Picker("Dock", selection: $dock) {
                ForEach(MMDockStyle.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("navlab.dock")
            Text("A instant · B directional · C dissolve. Applies on the next tab switch; dock on next launch.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}
#endif
