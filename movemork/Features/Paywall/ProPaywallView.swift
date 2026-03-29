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

    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var localErrorMessage: String? = nil
    @State private var selectedPackageID: String? = nil

    /// App Store product IDs — must match App Store Connect and RevenueCat packages exactly.
    private static let monthlyProductIDs = ["monthly_subscription"]
    private static let yearlyProductIDs = ["yearly_subscription"]

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
                if subscriptionManager.currentOffering == nil {
                    await subscriptionManager.refresh()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.05))
                                .frame(width: 42, height: 42)

                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.86))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
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

                plansLoadSection
                    .padding(.top, 12)

                if let local = localErrorMessage {
                    MMErrorBanner(message: paywallBannerMessage(local))
                        .padding(.top, 14)
                } else if let err = subscriptionManager.lastErrorMessage {
                    MMErrorBanner(message: paywallBannerMessage(err))
                        .padding(.top, 14)
                }

                if let selectedPackage {
                    ZStack {
                        MMButton(
                            title: subscriptionManager.isLoading ? "Starting…" : continuePurchaseTitle(for: selectedPackage),
                            action: { startPurchase(selectedPackage) },
                            kind: .primary,
                            size: .hero,
                            isDisabled: subscriptionManager.isLoading
                        )
                        .opacity(subscriptionManager.isLoading ? 0.7 : 1)

                        if subscriptionManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                    }
                    .padding(.top, 16)
                }

                Button {
                    restorePurchases()
                } label: {
                    Text("Restore purchases")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.92))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(subscriptionManager.isLoading)
                .padding(.top, 18)

                Text("Auto-renews until cancelled. Manage or cancel in Settings › Apple ID › Subscriptions.")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
            }
        }
    }

    private var isPlansLoadingIndicatorShowing: Bool {
        subscriptionManager.isLoading &&
            displayPackages.isEmpty &&
            subscriptionManager.lastErrorMessage == nil &&
            localErrorMessage == nil
    }

    @ViewBuilder
    private var plansLoadSection: some View {
        if !displayPackages.isEmpty {
            VStack(spacing: 12) {
                ForEach(displayPackages, id: \.identifier) { package in
                    pricingOption(package)
                }
            }
        } else if isPlansLoadingIndicatorShowing {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(MoveMarkTheme.Colors.primary)

                Text("Loading plans…")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        } else {
            placeholderPlanRows()
        }
    }

    private func placeholderPlanRows() -> some View {
        VStack(spacing: 12) {
            placeholderPlanRow(
                title: "Yearly",
                subtitle: "Best value when you stay a full lease term",
                isBestValue: true
            )

            placeholderPlanRow(
                title: "Monthly",
                subtitle: "Full Pro access, billed monthly",
                isBestValue: false
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plans unavailable. Yearly and Monthly placeholders shown.")
    }

    private func placeholderPlanRow(title: String, subtitle: String, isBestValue: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(MoveMarkTheme.Typography.subheadlineMedium)
                        .foregroundStyle(MoveMarkTheme.Colors.textPrimary.opacity(0.82))

                    if isBestValue {
                        Text("Best value")
                            .font(MoveMarkTheme.Typography.caption)
                            .foregroundStyle(MoveMarkTheme.Colors.primary.opacity(0.88))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MoveMarkTheme.Colors.primary.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }

                Text("—")
                    .font(MoveMarkTheme.Typography.subheadline)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.58))

                Text(subtitle)
                    .font(MoveMarkTheme.Typography.footnote)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary.opacity(0.74))
            }

            Spacer(minLength: 8)

            Circle()
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.78), lineWidth: 1)
                .frame(width: 22, height: 22)
                .padding(.top, 2)
        }
        .padding(14)
        .background(MoveMarkTheme.Colors.fieldFill.opacity(0.96))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MoveMarkTheme.Colors.panelStroke.opacity(0.82), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(false)
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
            .background(MoveMarkTheme.Colors.fieldFill)
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

        Task { @MainActor in
            do {
                try await subscriptionManager.restorePurchases()
                if subscriptionManager.hasPro {
                    onClose()
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
