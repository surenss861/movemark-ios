//
//  MMLightComponents.swift
//  movemork
//
//  @file Light design system primitives: spacing/radius tokens, surface, icon container,
//        photo card, action tile, metric item, section header, press style
//  @domain design-system
//  @status wip
//  @see [[VISUAL_STANDARD]] — canonical reference design-refs/proof.jpg
//  @see [[ProofHomeView.swift]] — first screen built from these
//

import SwiftUI

extension MoveMarkTheme.Light {
    /// Spacing scale. Screens use these, not per-screen numbers.
    enum Space {
        static let inset: CGFloat = 20       // screen side margin
        static let tight: CGFloat = 8        // grid gaps, label-to-control
        static let row: CGFloat = 12         // inside rows/tiles
        static let section: CGFloat = 18     // between sections
    }

    /// Radius scale: one value per role.
    enum Radius {
        static let control: CGFloat = 12     // small controls, viewer thumbs
        static let card: CGFloat = 14        // photo cards, tiles, grouped lists
        static let sheet: CGFloat = 28       // the sheet over a hero
    }
}

// MARK: - Type

/// SF Pro at a design size that scales with Dynamic Type like the given text style. Reads the
/// environment, so previews and snapshot traits drive it too.
private struct MMScaledFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let style: UIFont.TextStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let scaled = UIFontMetrics(forTextStyle: style).scaledValue(for: size, compatibleWith: traits)
        return content.font(.system(size: scaled, weight: weight))
    }
}

extension View {
    func mmFont(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: UIFont.TextStyle? = nil) -> some View {
        modifier(MMScaledFont(size: size, weight: weight, style: style ?? MMTextStyle.for(size)))
    }
}

enum MMTextStyle {
    /// The text style a design size scales with.
    static func `for`(_ size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case 26...: return .largeTitle
        case 19..<26: return .title3
        case 16..<19: return .headline
        case 14..<16: return .subheadline
        case 12..<14: return .footnote
        default: return .caption1
        }
    }
}

// MARK: - Surface

extension View {
    /// A white tile that separates from the sheet by the faintest elevation, not an outline.
    func mmLightSurface(radius: CGFloat = MoveMarkTheme.Light.Radius.card) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(MoveMarkTheme.Light.surface)
                .shadow(color: .black.opacity(0.045), radius: 10, x: 0, y: 3)
                .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 0)
        }
    }
}

// MARK: - Icon container

/// The one icon-container shape: a soft circle. Used for room glyphs and status marks.
struct MMIconCircle: View {
    let systemName: String
    var size: CGFloat = 56
    var tint: Color = MoveMarkTheme.Light.textPrimary.opacity(0.7)
    var fill: Color = MoveMarkTheme.Light.fill

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.38, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Photo card

/// Evidence photo as media: edge-to-edge fill, soft bottom shade, label left, count right.
struct MMPhotoCard: View {
    let path: String
    let title: String
    let count: Int
    let size: CGSize
    let resolve: (String) async -> URL?

    var body: some View {
        MMEvidenceImage(path: path, resolve: resolve, size: size)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .bottom) {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 36)
                    HStack(spacing: 3) {
                        Text(title)
                            .mmFont(11, .medium)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Image(systemName: "photo.on.rectangle").mmFont(9, .medium)
                        Text("\(count)").mmFont(11, .medium).monospacedDigit()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 7)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: MoveMarkTheme.Light.Radius.card, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(count) \(count == 1 ? "photo" : "photos")")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Action tile (light)

struct MMLightActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var needed: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .mmFont(18, .light)
                .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                .frame(width: 24)
                .overlay(alignment: .topTrailing) {
                    if needed {
                        Circle().fill(MoveMarkTheme.Light.attention).frame(width: 6, height: 6)
                            .offset(x: 3, y: -2)
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .mmFont(13, .medium)
                    .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                Text(subtitle)
                    .mmFont(11)
                    .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .mmFont(11, .medium)
                .foregroundStyle(MoveMarkTheme.Light.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 52)
        .mmLightSurface()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(needed ? "Needed" : "")
    }
}

// MARK: - Metric

struct MMMetricItem: View {
    let icon: String
    let value: Int
    let label: String
    var tint: Color = MoveMarkTheme.Light.textPrimary
    /// Centered in the three-column row; leading when stacked at accessibility sizes.
    var alignment: Alignment = .center

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .mmFont(19, .light)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: -1) {
                Text("\(value)")
                    .mmFont(18, .semibold)
                    .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .mmFont(11)
                    .foregroundStyle(MoveMarkTheme.Light.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Section header

struct MMLightSectionHeader: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .mmFont(17, .semibold)
                .foregroundStyle(MoveMarkTheme.Light.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(trailing)
                        Image(systemName: "chevron.right").mmFont(11, .semibold)
                    }
                    .mmFont(13)
                    .foregroundStyle(MoveMarkTheme.Light.textSecondary)
                }
            }
        }
    }
}

// MARK: - Press

struct MMLightPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
