//
//  MMSystem.swift
//  movemork
//
//  @file The final MoveMark visual system as shared building blocks, taken from the locked screens (Proof,
//        Reports, Account): a quiet dark header over a light working sheet, native grouped rows, lime only
//        on the one primary action, calm notices. Every first-party screen outside the locked set is built
//        from these so the product reads as one system.
//  @domain design-system
//  @see [[VISUAL_STANDARD]]
//

import SwiftUI

/// Colour tokens of the final system (the locked screens carry identical private copies).
enum MMInk {
    static let hero = Color(red: 0.086, green: 0.094, blue: 0.090)            // #161817 header / evidence dark
    static let heroSecondary = Color.white.opacity(0.62)
    static let sheet = Color(red: 0.973, green: 0.973, blue: 0.973)           // #F8F8F8 working surface
    static let card = Color.white
    static let cardStroke = Color(red: 0.925, green: 0.925, blue: 0.925)      // #ECECEC
    static let text = Color(red: 0.078, green: 0.078, blue: 0.082)            // #141415
    static let secondary = Color(red: 0.494, green: 0.498, blue: 0.502)       // #7E7F80
    static let separator = Color(red: 0.918, green: 0.918, blue: 0.922)       // #EAEAEB
    static let field = Color(red: 0.953, green: 0.953, blue: 0.949)           // #F3F3F2 input fill
    static let lime = Color(red: 0.792, green: 0.890, blue: 0.424)            // #CAE36C the one action
    static let limeMark = Color(red: 0.757, green: 0.914, blue: 0.298)        // #C1E94C status signal
    static let onLime = Color(red: 0.067, green: 0.086, blue: 0.035)          // #111608
    static let danger = Color(red: 0.776, green: 0.243, blue: 0.204)
    static let warning = Color(red: 0.725, green: 0.494, blue: 0.098)         // amber readable on white
    static let paper = Color(red: 0.949, green: 0.949, blue: 0.941)           // document tile
    /// Dark (evidence) surfaces.
    static let evidence = Color(red: 0.067, green: 0.075, blue: 0.071)        // #111312 room / viewer
    static let evidenceRaised = Color.white.opacity(0.06)
    static let evidenceStroke = Color.white.opacity(0.12)
}

enum MMMetrics {
    static let inset: CGFloat = 20
    static let sheetRadius: CGFloat = 22
    static let groupRadius: CGFloat = 14
    static let cardRadius: CGFloat = 16
    static let rowHeight: CGFloat = 50
    static let ctaHeight: CGFloat = 50
}

// MARK: - Screen scaffold

/// A screen in the system: the dark header (eyebrow, title, optional line) running under the status bar,
/// then the light working sheet. Root screens hide the navigation bar; pushed screens keep the system back
/// button on a dark bar of the header colour.
struct MMScreen<Trailing: View, Content: View>: View {
    var eyebrow: String?
    var title: String
    var subtitle: String?
    var isPushed: Bool = false
    /// Extra space at the end of the scroll (e.g. the dock's footprint on a root tab).
    var tail: CGFloat = 32
    /// Shows the MoveMark wordmark on a pushed screen too (root screens always show it).
    var showsWordmark = false
    /// Quiet content under the title inside the dark header (e.g. a dark Progress Strip).
    var headerAccessory: AnyView? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                VStack(alignment: .leading, spacing: 0) {
                    content()
                    Color.clear.frame(height: tail)
                }
                .padding(.horizontal, MMMetrics.inset)
                .padding(.top, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .environment(\.colorScheme, .light)
                .tint(MMInk.text)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: MMMetrics.sheetRadius, topTrailingRadius: MMMetrics.sheetRadius,
                                           style: .continuous).fill(MMInk.sheet)
                )
                .padding(.top, -MMMetrics.sheetRadius)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(MMInk.hero.ignoresSafeArea(edges: .top))
        }
        .background(MMInk.sheet.ignoresSafeArea())
        .toolbar(isPushed ? .automatic : .hidden, for: .navigationBar)
        .toolbarBackground(MMInk.hero, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isPushed || showsWordmark {
                HStack {
                    Text("MoveMark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    trailing()
                }
                .frame(height: isPushed ? 30 : 44)
            } else {
                HStack { Spacer(); trailing() }
            }
            if let eyebrow, !dynamicTypeSize.isAccessibilitySize {
                Text(eyebrow.uppercased())
                    .mmFont(11, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(MMInk.heroSecondary)
                    .padding(.top, isPushed ? 6 : 22)
            }
            Text(title)
                .mmFont(27, .semibold)
                .foregroundStyle(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 6)
            if let subtitle {
                Text(subtitle)
                    .mmFont(14.5)
                    .foregroundStyle(MMInk.heroSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            if let headerAccessory {
                headerAccessory.padding(.top, 20)
            }
        }
        .padding(.horizontal, MMMetrics.inset)
        .padding(.bottom, 28 + MMMetrics.sheetRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The header's dark runs up past the top so pulling down never shows the light sheet colour above it;
        // below a short sheet there is only the sheet colour (no dark band).
        .background(alignment: .bottom) { MMInk.hero.frame(height: 2000) }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension MMScreen where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String, subtitle: String? = nil, isPushed: Bool = false, tail: CGFloat = 32,
         showsWordmark: Bool = false, headerAccessory: AnyView? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, isPushed: isPushed, tail: tail,
                  showsWordmark: showsWordmark, headerAccessory: headerAccessory,
                  trailing: { EmptyView() }, content: content)
    }
}

/// A sheet in the system: light surface, plain title, native toolbar (Cancel / Save). Sheets only (see below).
struct MMSheetScaffold<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(.horizontal, MMMetrics.inset)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(MMInk.sheet.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MMInk.sheet, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(MMInk.text)
        // The app runs dark; a sheet is its own presentation, so it asks for light as a whole — bar, pickers,
        // menus, keyboard. Only for content presented as a sheet: in the main window this would flip the app.
        .preferredColorScheme(.light)
    }
}

// MARK: - Actions

/// The one primary action on a screen: lime, ink text.
struct MMPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().controlSize(.small).tint(MMInk.onLime)
                } else if let icon {
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .mmFont(15.5, .semibold)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(MMInk.onLime)
            .frame(maxWidth: .infinity)
            .frame(minHeight: MMMetrics.ctaHeight)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
            .background(MMInk.lime.opacity(isDisabled ? 0.45 : 1), in: Capsule())
        }
        .buttonStyle(MMLightPressStyle())
        .disabled(isDisabled || isLoading)
    }
}

/// A secondary action: plain ink text, full width, no fill.
struct MMSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = MMInk.text
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .medium)) }
                Text(title).mmFont(15.5, .medium)
            }
            .foregroundStyle(tint.opacity(isDisabled ? 0.4 : 1))
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Grouped content

/// A titled group of native rows on the sheet: section caption, white rounded container, optional footer.
struct MMGroup<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let title {
                Text(title.uppercased())
                    .mmFont(12, .medium)
                    .tracking(0.3)
                    .foregroundStyle(MMInk.secondary)
                    .padding(.leading, 16)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) { content() }
                .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.groupRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MMMetrics.groupRadius, style: .continuous)
                    .strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
            if let footer {
                Text(footer)
                    .mmFont(12.5)
                    .foregroundStyle(MMInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
        }
    }
}

/// A white container without a caption (a card of content, never nested in another).
struct MMPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous)
                .strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
    }
}

struct MMRowDivider: View {
    var leading: CGFloat = 16
    var body: some View {
        Rectangle().fill(MMInk.separator).frame(height: 0.75).padding(.leading, leading)
    }
}

/// A native row: optional icon, title + optional subtitle, optional value, chevron / external mark.
struct MMRow: View {
    enum Accessory { case chevron, external, none }

    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var value: String? = nil
    var tint: Color = MMInk.text
    var accessory: Accessory = .chevron
    var isDisabled = false
    var action: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }.buttonStyle(MMLightPressStyle()).disabled(isDisabled)
            } else {
                label
            }
        }
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityElement(children: .combine)
    }

    private var label: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(tint.opacity(0.75))
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).mmFont(16).foregroundStyle(tint)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).mmFont(13).foregroundStyle(MMInk.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 5 : 2)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value).mmFont(15).foregroundStyle(MMInk.secondary).lineLimit(1)
            }
            switch accessory {
            case .chevron where action != nil:
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MMInk.secondary.opacity(0.6))
            case .external:
                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MMInk.secondary.opacity(0.75))
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: MMMetrics.rowHeight, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Section title on the sheet (sentence case, semibold), as the locked screens use.
struct MMSectionTitle: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).mmFont(16, .semibold).foregroundStyle(MMInk.text).accessibilityAddTraits(.isHeader)
            Spacer()
            if let trailing, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(trailing)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .mmFont(13).foregroundStyle(MMInk.secondary)
                }
            }
        }
    }
}

// MARK: - Inputs

/// A light text field: caption above, quiet filled control.
struct MMField: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var axis: Axis = .horizontal
    var accessibilityID: String? = nil
    /// The keyboard's return key: label and what it does (next field, or the screen's primary action).
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).mmFont(13, .medium).foregroundStyle(MMInk.secondary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text, axis: axis)
                        .lineLimit(axis == .vertical ? 3...8 : 1...1)
                }
            }
            .mmFont(16)
            .foregroundStyle(MMInk.text)
            .tint(MMInk.text)
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalization)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(minHeight: 50)
            .background(MMInk.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MMInk.cardStroke, lineWidth: 1))
            .accessibilityIdentifier(accessibilityID ?? title)
        }
    }
}

/// A selectable chip (room names, issue tags, conditions): ink when selected, never green.
struct MMChip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .mmFont(14, isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.white : MMInk.text)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(isSelected ? MMInk.text : MMInk.card, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : MMInk.cardStroke, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(MMLightPressStyle())
        .clipShape(Capsule())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - States

/// A calm inline notice: error (red mark), warning (amber) or info, with an optional action.
struct MMNotice: View {
    enum Tone { case error, warning, info, success }
    let message: String
    var tone: Tone = .error
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    private var mark: (String, Color) {
        switch tone {
        case .error: ("exclamationmark.circle.fill", MMInk.danger)
        case .warning: ("exclamationmark.triangle.fill", MMInk.warning)
        case .info: ("info.circle.fill", MMInk.secondary)
        case .success: ("checkmark.circle.fill", MMInk.text)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mark.0).foregroundStyle(mark.1).font(.system(size: 15))
            Text(message).mmFont(14).foregroundStyle(MMInk.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action).mmFont(14, .semibold).foregroundStyle(MMInk.text)
            }
        }
        .padding(12)
        .background(MMInk.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
        .accessibilityElement(children: .combine)
    }
}

/// An empty state on the sheet: a quiet glyph, one line of what's missing, one line of why, one action.
struct MMEmptyBlock: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.system(size: 22, weight: .regular)).foregroundStyle(MMInk.text.opacity(0.55))
            Text(title).mmFont(17, .semibold).foregroundStyle(MMInk.text)
            if let message {
                Text(message).mmFont(14).foregroundStyle(MMInk.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                MMPrimaryButton(title: actionTitle, action: action).padding(.top, 8)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MMInk.card, in: RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MMMetrics.cardRadius, style: .continuous).strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
    }
}

/// A full-screen loading state on the light surface.
struct MMLoadingBlock: View {
    var message: String? = nil
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().controlSize(.large).tint(MMInk.secondary)
            if let message { Text(message).mmFont(14).foregroundStyle(MMInk.secondary) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MMInk.sheet.ignoresSafeArea())
        .accessibilityElement(children: .combine)
    }
}
