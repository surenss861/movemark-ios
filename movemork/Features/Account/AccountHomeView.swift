//
//  AccountHomeView.swift
//  movemork
//
//  @file Account tab — calm native settings inside the MoveMark system: identity, plan, support, legal,
//        sign out, and a separated Delete account
//  @domain account
//  @status wip
//  @see [[VISUAL_STANDARD]]
//  @see [[AccountView.swift]] — owns session, subscription and deletion; feeds this view
//

import SwiftUI

/// Everything Account shows, already computed. Presentational only.
struct AccountHomeModel {
    struct Feedback: Equatable {
        let message: String
        var isError: Bool = false
    }

    var email: String
    var name: String?
    /// From the RevenueCat entitlement, never optimistic local state.
    var isPro: Bool
    var isRestoring: Bool = false
    var restoreFeedback: Feedback?
    var hasSupport: Bool = true
    var hasPrivacyPolicy: Bool = true
    var hasTerms: Bool = true
    var appVersion: String
}

/// The Account tab: who is signed in and on which plan, then grouped native rows. Lime marks only the
/// Pro status; Sign out stays neutral; Delete account sits apart in calm red.
struct AccountHomeView: View {
    enum Action { case editName, subscription, restore, support, privacy, terms, signOut, deleteAccount }

    let model: AccountHomeModel
    var onAction: (Action) -> Void = { _ in }
    /// Snapshot tests open the scroll at its end to check the tail clears the dock.
    var initialScrollAnchor: UnitPoint? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.mmRootTabBarVisible) private var rootTabBarVisible
    private var isAX: Bool { dynamicTypeSize.isAccessibilitySize }
    @State private var k: CGFloat = 1

    fileprivate enum Ink {
        static let hero = Color(red: 0.086, green: 0.094, blue: 0.090)          // #161817, as the Vault
        static let heroSecondary = Color.white.opacity(0.62)
        static let sheet = Color(red: 0.973, green: 0.973, blue: 0.973)          // #F8F8F8
        static let card = Color.white
        static let cardStroke = Color(red: 0.925, green: 0.925, blue: 0.925)     // #ECECEC
        static let text = Color(red: 0.078, green: 0.078, blue: 0.082)           // #141415
        static let secondary = Color(red: 0.494, green: 0.498, blue: 0.502)      // #7E7F80
        static let separator = Color(red: 0.918, green: 0.918, blue: 0.922)      // #EAEAEB
        static let limeMark = Color(red: 0.757, green: 0.914, blue: 0.298)       // #C1E94C
        static let danger = Color(red: 0.776, green: 0.243, blue: 0.204)
    }

    /// The header's dark, for a navigation bar that sits on it when Account is pushed.
    static let headerColor = Ink.hero

    private var inset: CGFloat { 20 * k }
    private var sheetRadius: CGFloat { 22 * k }
    private var groupRadius: CGFloat { 14 * k }
    private var rowHeight: CGFloat { 50 * k }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                sheet.padding(.top, -sheetRadius)
            }
        }
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(initialScrollAnchor)
        // A solid band of the header colour under the status bar: scrolled content never runs under the clock.
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: 0).background(Ink.hero.ignoresSafeArea(edges: .top))
        }
        .background(alignment: .top) { Ink.hero.frame(height: 360).ignoresSafeArea(edges: .top) }
        .background(Ink.sheet.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            k = min(max(width / 402, 0.92), 1.12)
        }
    }

    // MARK: - Header

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MoveMark")
                .font(.system(size: 17 * k, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: 44 * k)
            if !isAX {
                Text("ACCOUNT")
                    .mmFont(11, .semibold)
                    .tracking(0.6)
                    .foregroundStyle(Ink.heroSecondary)
                    .padding(.top, 22 * k)
            }
            Text("Your account")
                .mmFont(27, .semibold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, isAX ? 14 * k : 6 * k)
        }
        .padding(.horizontal, inset)
        .padding(.bottom, 28 * k + sheetRadius)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.hero)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    // MARK: - Sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            identity
            section("MoveMark") {
                row("Name", value: model.name ?? "Add", action: .editName)
                divider
                row("Subscription", value: model.isPro ? "Pro" : "Free", external: model.isPro, action: .subscription)
                divider
                restoreRow
            } footer: {
                if let feedback = model.restoreFeedback {
                    Text(feedback.message)
                        .foregroundStyle(feedback.isError ? Ink.danger : Ink.secondary)
                }
            }
            .padding(.top, 26 * k)
            section("Support") {
                row("Contact support", external: true, isDisabled: !model.hasSupport, action: .support)
            }
            .padding(.top, 26 * k)
            section("Legal") {
                row("Privacy Policy", external: true, isDisabled: !model.hasPrivacyPolicy, action: .privacy)
                divider
                row("Terms of Use", external: true, isDisabled: !model.hasTerms, action: .terms)
            }
            .padding(.top, 26 * k)
            group {
                row("Sign out", showsChevron: false, action: .signOut)
            }
            .padding(.top, 34 * k)
            section(nil) {
                row("Delete account", tint: Ink.danger, showsChevron: false, action: .deleteAccount)
            } footer: {
                Text("Permanently deletes your account, proof, reports and stored evidence.")
                    .foregroundStyle(Ink.secondary)
            }
            .padding(.top, 34 * k)
            about.padding(.top, 30 * k)
            if rootTabBarVisible {
                MMSignedInScrollTailSpacer(kind: .accountTab)
            } else {
                Color.clear.frame(height: 32)
            }
        }
        .padding(.horizontal, inset)
        .padding(.top, 24 * k)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: sheetRadius, topTrailingRadius: sheetRadius, style: .continuous)
                .fill(Ink.sheet)
        )
    }

    /// Who is signed in, and on which plan. Plain text on the sheet: not a card.
    private var identity: some View {
        VStack(alignment: .leading, spacing: 5 * k) {
            Text(model.email.isEmpty ? "Signed in" : model.email)
                .mmFont(19, .semibold)
                .foregroundStyle(Ink.text)
                .lineLimit(isAX ? 3 : 1)
                .truncationMode(.middle)
                .minimumScaleFactor(isAX ? 1 : 0.75)
            HStack(spacing: 7 * k) {
                if model.isPro { Circle().fill(Ink.limeMark).frame(width: 8 * k, height: 8 * k) }
                Text(model.isPro ? "MoveMark Pro" : "Free plan")
                    .mmFont(14.5, model.isPro ? .medium : .regular)
                    .foregroundStyle(model.isPro ? Ink.text : Ink.secondary)
            }
        }
        .padding(.horizontal, 4 * k)
        .accessibilityElement(children: .combine)
    }

    private var restoreRow: some View {
        Button { onAction(.restore) } label: {
            HStack(spacing: 10 * k) {
                Text(model.isRestoring ? "Restoring purchases…" : "Restore purchases")
                    .mmFont(16)
                    .foregroundStyle(Ink.text)
                Spacer(minLength: 8 * k)
                if model.isRestoring { ProgressView().controlSize(.small).tint(Ink.secondary) }
            }
            .rowFrame(height: rowHeight, inset: 16 * k, isAX: isAX)
        }
        .buttonStyle(MMLightPressStyle())
        .disabled(model.isRestoring)
    }

    private var about: some View {
        VStack(spacing: 4 * k) {
            Text("MoveMark \(model.appVersion)")
            Text("MoveMark organizes rental evidence. It does not provide legal advice.")
        }
        .mmFont(12)
        .foregroundStyle(Ink.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12 * k)
    }

    // MARK: - Native grouped rows

    private func section<Content: View>(_ title: String?, @ViewBuilder _ content: () -> Content) -> some View {
        section(title, content, footer: { EmptyView() })
    }

    private func section<Content: View, Footer: View>(
        _ title: String?,
        @ViewBuilder _ content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(alignment: .leading, spacing: 7 * k) {
            if let title {
                Text(title.uppercased())
                    .mmFont(12, .medium)
                    .tracking(0.3)
                    .foregroundStyle(Ink.secondary)
                    .padding(.leading, 16 * k)
                    .accessibilityAddTraits(.isHeader)
            }
            group(content)
            footer()
                .mmFont(12.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16 * k)
        }
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(Ink.card, in: RoundedRectangle(cornerRadius: groupRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: groupRadius, style: .continuous).strokeBorder(Ink.cardStroke, lineWidth: 0.75))
    }

    private var divider: some View {
        Rectangle().fill(Ink.separator).frame(height: 0.75).padding(.leading, 16 * k)
    }

    private func row(_ title: String, value: String? = nil, tint: Color = Ink.text, external: Bool = false,
                     showsChevron: Bool = true, isDisabled: Bool = false, action: Action) -> some View {
        Button { onAction(action) } label: {
            HStack(spacing: 10 * k) {
                Text(title).mmFont(16).foregroundStyle(tint).lineLimit(isAX ? 3 : 1)
                Spacer(minLength: 8 * k)
                if let value {
                    Text(value).mmFont(15).foregroundStyle(Ink.secondary).lineLimit(1)
                }
                if external {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12 * k, weight: .semibold))
                        .foregroundStyle(Ink.secondary.opacity(0.75))
                } else if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12 * k, weight: .semibold))
                        .foregroundStyle(Ink.secondary.opacity(0.6))
                }
            }
            .rowFrame(height: rowHeight, inset: 16 * k, isAX: isAX)
        }
        .buttonStyle(MMLightPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(external ? .isLink : .isButton)
    }
}

private extension View {
    func rowFrame(height: CGFloat, inset: CGFloat, isAX: Bool) -> some View {
        padding(.horizontal, inset)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
            .padding(.vertical, isAX ? 8 : 0)
            .contentShape(Rectangle())
    }
}

/// Delete account: what goes, what doesn't (Apple billing), and one red action behind a final confirmation.
struct DeleteAccountContent: View {
    let isDeleting: Bool
    let errorMessage: String?
    var onDelete: () -> Void = {}
    var onCancel: () -> Void = {}
    var onManageSubscription: () -> Void = {}

    private typealias Ink = AccountHomeView.Ink

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Delete your account")
                    .mmFont(26, .semibold)
                    .foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
                Text("This permanently deletes your MoveMark account, proof vaults, reports, photos and stored evidence. It cannot be undone.")
                    .mmFont(16)
                    .foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                Text("Deleting your account does not cancel an Apple subscription. Manage or cancel it with Apple.")
                    .mmFont(14)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
                Button("Manage Apple subscription", action: onManageSubscription)
                    .mmFont(14.5, .medium)
                    .foregroundStyle(Ink.text)
                    .underline()
                    .frame(minHeight: 44)
                    .disabled(isDeleting)
                if let errorMessage {
                    Text(errorMessage)
                        .mmFont(14)
                        .foregroundStyle(Ink.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }
                VStack(spacing: 6) {
                    Button(action: onDelete) {
                        HStack(spacing: 8) {
                            if isDeleting { ProgressView().controlSize(.small).tint(.white) }
                            Text(isDeleting ? "Deleting…" : "Delete account permanently").mmFont(16, .semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Ink.danger, in: Capsule())
                    }
                    .buttonStyle(MMLightPressStyle())
                    Button(action: onCancel) {
                        Text("Cancel").mmFont(16, .medium).foregroundStyle(Ink.text)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .disabled(isDeleting)
                .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        }
        .background(Ink.sheet.ignoresSafeArea())
    }
}
