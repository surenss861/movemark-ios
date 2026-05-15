//
//  ProPaywallView.swift
//  movemork
//
//  MoveMark — RevenueCat-backed Pro paywall.
//

import SwiftUI
import RevenueCat

struct ProPaywallView: View {
    let reason: PaywallReason
    let onClose: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var localErrorMessage: String? = nil
    @State private var selectedPackageID: String? = nil
    @State private var restoreOutcomeMessage: String? = nil
    /// False until the first `refresh()` tied to this paywall presentation finishes (avoids a one-frame “fake” plan placeholder).
    @State private var initialOfferingsFetchCompleted = false
    @State private var proofToast: MMProofToastMessage? = nil
    @State private var proofToastVisible = false

    /// Store product IDs — must match RevenueCat package products (App Store: monthly/yearly_subscription; Test Store mirror: testmonthly/testyearly).
    private static let monthlyProductIDs = ["monthly_subscription", "testmonthly"]
    private static let yearlyProductIDs = ["yearly_subscription", "testyearly"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MoveMarkTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        benefitsCard
                        pricingCard
                    }
                    .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                    .padding(.top, 14)
                    .padding(.bottom, 36)
                }
            }
            .task {
                initialOfferingsFetchCompleted = false
                await subscriptionManager.refresh()
                initialOfferingsFetchCompleted = true
            }
            .mmProofToast(message: proofToast, isVisible: proofToastVisible)
            .onChange(of: paywallPlansUnavailable) { wasUnavailable, isUnavailable in
                guard isUnavailable, !wasUnavailable else { return }
                MMProofToastPresenter.show(
                    .plansDidNotLoad(),
                    message: $proofToast,
                    isVisible: $proofToastVisible
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(MoveMarkTheme.Colors.mint.opacity(0.65))
                                .frame(width: 42, height: 42)

                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .disabled(subscriptionManager.isStoreKitBusy)
                    .opacity(subscriptionManager.isStoreKitBusy ? 0.45 : 1)
                }
            }
            .interactiveDismissDisabled(subscriptionManager.isStoreKitBusy)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MoveMark Pro")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MoveMarkTheme.Colors.accent)

            Text(reason.headline)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(reason.subheadline)
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 10)
    }

    private var benefitsCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(benefitsTitle)
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(benefits.enumerated()), id: \.offset) { _, item in
                        benefitRow(item.title, item.subtitle)
                    }
                }
            }
        }
    }

    private var pricingCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(reason == .moveOutExport ? "Choose your protection plan" : "Choose your plan")
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                paywallRestoreSection
                    .padding(.top, 10)

                plansLoadSection
                    .padding(.top, 12)

                if !displayPackages.isEmpty {
                    Text(
                        "MoveMark Pro is an auto-renewing subscription (monthly or annual). Prices below come from the App Store. Apple processes payment and renewal."
                    )
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                }

                if paywallPlansUnavailable {
                    plansUnavailableRecoveryBlock
                } else if let local = localErrorMessage, !displayPackages.isEmpty {
                    MMErrorBanner(message: paywallBannerMessage(local), retryTitle: nil, onRetry: nil)
                        .padding(.top, 14)
                }

                if let selectedPackage {
                    ZStack {
                        MMButton(
                            title: subscriptionManager.isStoreKitBusy ? "Starting…" : continuePurchaseTitle(for: selectedPackage),
                            action: { startPurchase(selectedPackage) },
                            kind: .primary,
                            size: .hero,
                            isDisabled: subscriptionManager.isStoreKitBusy || subscriptionManager.isRefreshingOfferings
                        )
                        .opacity(subscriptionManager.isStoreKitBusy ? 0.7 : 1)

                        if subscriptionManager.isStoreKitBusy {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .padding(.top, 16)
                }

                paywallLegalLinks
                    .padding(.top, 8)

                Text("Auto-renews until cancelled. Manage or cancel in Settings › Apple ID › Subscriptions.")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
        }
    }

    /// Empty catalog after at least one paywall fetch finished — never show silent placeholders.
    private var paywallPlansUnavailable: Bool {
        displayPackages.isEmpty
            && !subscriptionManager.isRefreshingOfferings
            && initialOfferingsFetchCompleted
    }

    private var paywallRestoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Already subscribed on this Apple ID? Restore before purchasing again.")
                .font(MoveMarkTheme.Typography.footnote)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                restorePurchases()
            } label: {
                Text(subscriptionManager.isStoreKitBusy ? "Restoring purchases…" : "Restore purchases")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(subscriptionManager.isStoreKitBusy)

            if let restoreOutcomeMessage {
                MMCompactCallout(
                    systemImage: "info.circle.fill",
                    title: "Restore result",
                    message: restoreOutcomeMessage
                )
            }
        }
    }

    private var plansUnavailableTechnicalDetail: String {
        if let local = localErrorMessage, !local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return paywallBannerMessage(local)
        }
        let server = subscriptionManager.lastErrorMessage ?? ""
        if !server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return paywallBannerMessage(server)
        }
        return "If this persists, confirm the Paid Apps Agreement is active in App Store Connect and that subscription products are attached to your RevenueCat offering."
    }

    private var privacyPolicyURL: URL? { legalURL(forInfoKey: "LegalPrivacyPolicyURL") }

    private var termsOfUseURL: URL? { legalURL(forInfoKey: "LegalTermsURL") }

    private func legalURL(forInfoKey key: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$("), let url = URL(string: trimmed) else { return nil }
        return url
    }

    @ViewBuilder
    private var paywallLegalLinks: some View {
        if termsOfUseURL != nil || privacyPolicyURL != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Legal")
                    .font(MoveMarkTheme.Typography.caption)
                    .tracking(0.9)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .textCase(.uppercase)

                HStack(spacing: 20) {
                    if let u = termsOfUseURL {
                        Button {
                            openURL(u)
                        } label: {
                            Text("Terms of Use")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                    }
                    if let p = privacyPolicyURL {
                        Button {
                            openURL(p)
                        } label: {
                            Text("Privacy Policy")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.92))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var plansUnavailableRecoveryBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plans didn’t load")
                .font(MoveMarkTheme.Typography.cardTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text("Try again in a minute. You can keep using Free for now.")
                .font(MoveMarkTheme.Typography.subheadline)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(plansUnavailableTechnicalDetail)
                .font(MoveMarkTheme.Typography.caption)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            MMButton(
                title: subscriptionManager.isRefreshingOfferings
                    ? "Trying…"
                    : MMNextBestActionMapper.paywallPlansUnavailable().title,
                action: {
                    localErrorMessage = nil
                    restoreOutcomeMessage = nil
                    Task { @MainActor in
                        await subscriptionManager.refresh()
                    }
                },
                kind: .primary,
                size: .standard,
                isDisabled: subscriptionManager.isRefreshingOfferings || subscriptionManager.isStoreKitBusy
            )

            MMButton(
                title: "Continue on Free",
                action: { onClose() },
                kind: .secondary,
                size: .standard,
                isDisabled: subscriptionManager.isStoreKitBusy
            )
        }
        .padding(.top, 14)
    }

    @ViewBuilder
    private var plansLoadSection: some View {
        if !displayPackages.isEmpty {
            VStack(spacing: 12) {
                ForEach(displayPackages, id: \.identifier) { package in
                    pricingOption(package)
                }
            }
        } else if subscriptionManager.isRefreshingOfferings || !initialOfferingsFetchCompleted {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(MoveMarkTheme.Colors.primary)

                    Text("Loading plans…")
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.92))
                }
                Text("Fetching subscription options from the App Store. This usually takes a few seconds.")
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else {
            EmptyView()
        }
    }

    private func paywallBannerMessage(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > 200 {
            return "Plans aren’t available right now. Try again later."
        }
        return t
    }

    private func continuePurchaseTitle(for package: Package) -> String {
        switch planKind(for: package) {
        case .monthly:
            return "Continue with Monthly"
        case .yearly:
            return "Continue with Yearly"
        case .other:
            return reason.ctaTitle
        }
    }

    private enum PlanKind {
        case monthly, yearly, other
    }

    private func planKind(for package: Package) -> PlanKind {
        let pid = package.storeProduct.productIdentifier
        if Self.yearlyProductIDs.contains(pid) || Self.infersAnnualBilling(package) { return .yearly }
        if Self.monthlyProductIDs.contains(pid) || Self.infersMonthlyBilling(package) { return .monthly }
        return .other
    }

    private func planDisplayTitle(for package: Package) -> String {
        switch planKind(for: package) {
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        case .other:
            let t = package.storeProduct.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "Pro" : t
        }
    }

    private var displayPackages: [Package] {
        let raw = subscriptionManager.currentOffering?.availablePackages ?? []
        return Self.sortedPackagesForDisplay(raw)
    }

    private static func sortedPackagesForDisplay(_ packages: [Package]) -> [Package] {
        packages.sorted { lhs, rhs in
            func rank(_ p: Package) -> Int {
                let pid = p.storeProduct.productIdentifier
                if yearlyProductIDs.contains(pid) { return 0 }
                if monthlyProductIDs.contains(pid) { return 1 }
                if p.packageType == .annual { return 0 }
                if p.packageType == .monthly { return 1 }
                if Self.infersAnnualBilling(p) { return 0 }
                if Self.infersMonthlyBilling(p) { return 1 }
                return 2
            }

            let delta = rank(lhs) - rank(rhs)
            if delta != 0 { return delta < 0 }
            return lhs.identifier < rhs.identifier
        }
    }

    private static func infersAnnualBilling(_ package: Package) -> Bool {
        guard let period = package.storeProduct.subscriptionPeriod else { return false }
        return period.unit == .year && period.value >= 1
    }

    private static func infersMonthlyBilling(_ package: Package) -> Bool {
        guard let period = package.storeProduct.subscriptionPeriod else { return false }
        return period.unit == .month && period.value == 1
    }

    private var selectedPackage: Package? {
        let packages = displayPackages
        guard !packages.isEmpty else { return nil }

        if let selectedPackageID,
           let explicit = packages.first(where: { $0.identifier == selectedPackageID }) {
            return explicit
        }

        return packages.first(where: { Self.yearlyProductIDs.contains($0.storeProduct.productIdentifier) })
            ?? packages.first(where: { Self.monthlyProductIDs.contains($0.storeProduct.productIdentifier) })
            ?? packages.first(where: { $0.packageType == .annual })
            ?? packages.first(where: { Self.infersAnnualBilling($0) })
            ?? packages.first(where: { $0.packageType == .monthly })
            ?? packages.first(where: { Self.infersMonthlyBilling($0) })
            ?? packages.first
    }

    private func pricingOption(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let product = package.storeProduct
        let isYearly = package.packageType == .annual || Self.infersAnnualBilling(package)
        let strokeWidth: CGFloat = (isSelected && isYearly) ? 1.8 : 1

        return Button {
            selectedPackageID = package.identifier
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MoveMark Pro")
                        .font(MoveMarkTheme.Typography.caption)
                        .tracking(0.85)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                        .textCase(.uppercase)

                    HStack(spacing: 8) {
                        Text(planDisplayTitle(for: package))
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        if isYearly {
                            Text("Best value")
                                .font(MoveMarkTheme.Typography.caption)
                                .foregroundStyle(MoveMarkTheme.Colors.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MoveMarkTheme.Colors.primary.opacity(0.16))
                                .clipShape(Capsule())
                        }
                    }

                    if let storeTitle = storeProductListingTitle(for: package, product: product) {
                        Text(storeTitle)
                            .font(MoveMarkTheme.Typography.footnote)
                            .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(priceCaption(for: package, product: product))
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.95))

                    Text(planSubtitle(for: package))
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                Spacer(minLength: 8)

                Circle()
                    .stroke(
                        isSelected ? MoveMarkTheme.Colors.primary : MoveMarkTheme.Colors.panelStroke,
                        lineWidth: 1.2
                    )
                    .background(
                        Circle()
                            .fill(isSelected ? MoveMarkTheme.Colors.primary : .clear)
                            .padding(4)
                    )
                    .frame(width: 22, height: 22)
                    .padding(.top, 2)
            }
            .padding(14)
            .background(isSelected ? MoveMarkTheme.Colors.mint.opacity(0.45) : MoveMarkTheme.Colors.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected
                            ? MoveMarkTheme.Colors.primary.opacity(isYearly ? 0.95 : 0.75)
                            : MoveMarkTheme.Colors.panelStroke,
                        lineWidth: strokeWidth
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "MoveMark Pro, \(planDisplayTitle(for: package)), \(priceCaption(for: package, product: product))"
        )
    }

    /// Shown when App Store localized title adds detail beyond our Monthly/Yearly label.
    private func storeProductListingTitle(for package: Package, product: StoreProduct) -> String? {
        let raw = product.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let plan = planDisplayTitle(for: package)
        if raw.caseInsensitiveCompare(plan) == .orderedSame { return nil }
        if raw.caseInsensitiveCompare("MoveMark Pro") == .orderedSame { return nil }
        return raw
    }

    private func benefitRow(_ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(MoveMarkTheme.Colors.primary.opacity(0.9))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                Text(subtitle)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
        }
    }

    private var benefitsTitle: String {
        switch reason {
        case .extraProperty:
            return "What Pro adds"
        case .unlimitedExports:
            return "What Pro exports unlock"
        case .disputePacket:
            return "What Pro adds to your case"
        case .moveOutExport:
            return "What Pro adds at move-out"
        }
    }

    private var benefits: [(title: String, subtitle: String)] {
        switch reason {
        case .extraProperty:
            return [
                ("More property vaults", "Separate proof trails for each rental."),
                ("Unlimited exports", "Save, share, or send proof PDFs anytime."),
                ("Case builder included", "Stronger dispute workflow from your evidence."),
            ]
        case .unlimitedExports:
            return [
                ("Unlimited move-in exports", "Fresh baseline reports as docs grow."),
                ("Move-out exports", "Before-and-after records for deposit disputes."),
                ("Case builder included", "Exports plus proof in one flow."),
            ]
        case .disputePacket:
            return [
                ("Case builder", "Organize proof into a clearer defense."),
                ("Unlimited exports", "Reports and files your case may need."),
                ("Move-out protection", "Proof where disputes usually hit."),
            ]
        case .moveOutExport:
            return [
                ("Move-out exports", "Before-and-after proof when risk is real."),
                ("Unlimited exports", "Update reports as you add evidence."),
                ("Case builder", "Move-out proof inside a stronger workflow."),
            ]
        }
    }

    private func priceCaption(for package: Package, product: StoreProduct) -> String {
        let period = periodLabel(for: package)
        return "\(product.localizedPriceString) / \(period)"
    }

    private func periodLabel(for package: Package) -> String {
        switch package.packageType {
        case .monthly:
            return "month"
        case .annual:
            return "year"
        case .weekly:
            return "week"
        case .twoMonth:
            return "2 months"
        case .threeMonth:
            return "3 months"
        case .sixMonth:
            return "6 months"
        default:
            break
        }

        guard let sub = package.storeProduct.subscriptionPeriod else {
            return "billing period"
        }

        let value = sub.value
        switch sub.unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return "billing period"
        }
    }

    private func planSubtitle(for package: Package) -> String {
        switch package.packageType {
        case .monthly:
            return "Start now with full Pro access"
        case .annual:
            return "Best value for full-term renter protection"
        default:
            if Self.infersAnnualBilling(package) {
                return "Best value for full-term renter protection"
            }
            if Self.infersMonthlyBilling(package) {
                return "Start now with full Pro access"
            }
            return "Full MoveMark Pro access for this billing period"
        }
    }

    private func startPurchase(_ package: Package) {
        localErrorMessage = nil
        restoreOutcomeMessage = nil

        Task { @MainActor in
            do {
                try await subscriptionManager.purchase(package: package)
                onClose()
            } catch {
                localErrorMessage = userFacingPaywallError(from: error)
            }
        }
    }

    private func restorePurchases() {
        localErrorMessage = nil
        restoreOutcomeMessage = nil

        Task { @MainActor in
            do {
                try await subscriptionManager.restorePurchases()
                if subscriptionManager.hasPro {
                    onClose()
                } else {
                    restoreOutcomeMessage = "No active subscription was found for this Apple ID."
                }
            } catch {
                localErrorMessage = userFacingPaywallError(from: error)
            }
        }
    }

    private func userFacingPaywallError(from error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "MoveMark.Subscription" {
            return paywallBannerMessage(ns.localizedDescription)
        }

        let raw = error.localizedDescription.lowercased()

        if raw.contains("cancel") {
            return "Purchase cancelled."
        }

        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }

        if raw.contains("metadata")
            || (raw.contains("product") && raw.contains("unavailable"))
            || raw.contains("configuration")
            || (raw.contains("store") && raw.contains("problem")) {
            return "Plans aren’t available right now. Try again later."
        }

        return "Purchase didn’t go through. Try again."
    }
}
