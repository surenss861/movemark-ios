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

    var body: some View {
        NavigationStack {
            ZStack {
                MoveMarkTheme.Colors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        benefitsCard
                        pricingCard
                        restoreBlock
                    }
                    .padding(.horizontal, MoveMarkTheme.Spacing.screenHorizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
            }
            .task {
                if subscriptionManager.currentOffering == nil {
                    await subscriptionManager.refresh()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { onClose() }
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MoveMark Pro")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(MoveMarkTheme.Colors.accent)

            Text(reason.headline)
                .font(MoveMarkTheme.Typography.screenTitle)
                .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

            Text(reason.subheadline)
                .font(MoveMarkTheme.Typography.body)
                .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitsCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(benefitsTitle)
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                ForEach(Array(benefits.enumerated()), id: \.offset) { _, item in
                    benefitRow(item.title, item.subtitle)
                }
            }
        }
    }

    private var pricingCard: some View {
        MMCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(reason == .moveOutExport ? "Choose your protection plan" : "Choose your plan")
                    .font(MoveMarkTheme.Typography.cardTitle)
                    .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                if !displayPackages.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(displayPackages, id: \.identifier) { package in
                            pricingOption(package)
                        }
                    }
                } else {
                    Text("Loading plans…")
                        .font(MoveMarkTheme.Typography.subheadline)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                if let localErrorMessage {
                    MMErrorBanner(message: localErrorMessage)
                } else if let error = subscriptionManager.lastErrorMessage {
                    MMErrorBanner(message: error)
                }

                if let selectedPackage {
                    ZStack {
                        MMButton(
                            title: subscriptionManager.isLoading ? "Starting…" : reason.ctaTitle,
                            action: { startPurchase(selectedPackage) },
                            kind: .primary,
                            size: .hero,
                            isDisabled: subscriptionManager.isLoading
                        )
                        .opacity(subscriptionManager.isLoading ? 0.65 : 1)

                        if subscriptionManager.isLoading {
                            ProgressView().tint(.white)
                        }
                    }
                }

                Text("Subscriptions renew automatically unless cancelled. Restore purchases anytime.")
                    .font(MoveMarkTheme.Typography.caption)
                    .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var restoreBlock: some View {
        VStack(spacing: 10) {
            Button {
                restorePurchases()
            } label: {
                Text("Restore purchases")
                    .font(MoveMarkTheme.Typography.subheadlineMedium)
                    .foregroundStyle(MoveMarkTheme.Colors.primary)
            }
            .buttonStyle(.plain)
            .disabled(subscriptionManager.isLoading)
        }
        .frame(maxWidth: .infinity)
    }

    /// Annual first (best value), then monthly — matches common RevenueCat offerings with custom display names.
    private var displayPackages: [Package] {
        let raw = subscriptionManager.currentOffering?.availablePackages ?? []
        return Self.sortedPackagesForDisplay(raw)
    }

    private static func sortedPackagesForDisplay(_ packages: [Package]) -> [Package] {
        packages.sorted { lhs, rhs in
            func rank(_ p: Package) -> Int {
                if p.packageType == .annual { return 0 }
                if p.packageType == .monthly { return 1 }
                if Self.infersAnnualBilling(p) { return 0 }
                if Self.infersMonthlyBilling(p) { return 1 }
                return 2
            }
            let d = rank(lhs) - rank(rhs)
            if d != 0 { return d < 0 }
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

        return packages.first(where: { $0.packageType == .annual })
            ?? packages.first(where: { Self.infersAnnualBilling($0) })
            ?? packages.first(where: { $0.packageType == .monthly })
            ?? packages.first(where: { Self.infersMonthlyBilling($0) })
            ?? packages.first
    }

    private func pricingOption(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let product = package.storeProduct

        return Button {
            selectedPackageID = package.identifier
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(priceCaption(for: package, product: product))
                            .font(MoveMarkTheme.Typography.subheadlineMedium)
                            .foregroundStyle(MoveMarkTheme.Colors.textPrimary)

                        if package.packageType == .annual || Self.infersAnnualBilling(package) {
                            Text("Best value")
                                .font(MoveMarkTheme.Typography.caption)
                                .foregroundStyle(MoveMarkTheme.Colors.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(MoveMarkTheme.Colors.primary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    Text(planSubtitle(for: package))
                        .font(MoveMarkTheme.Typography.footnote)
                        .foregroundStyle(MoveMarkTheme.Colors.textSecondary)
                }

                Spacer()

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
            }
            .padding(14)
            .background(MoveMarkTheme.Colors.fieldFill)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? MoveMarkTheme.Colors.primary.opacity(0.7) : MoveMarkTheme.Colors.panelStroke,
                        lineWidth: 1
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
                (
                    "More property vaults",
                    "Protect more than one rental with separate proof trails and records."
                ),
                (
                    "Unlimited exports",
                    "Generate updated reports whenever you need to save, share, or send proof."
                ),
                (
                    "Case builder included",
                    "Turn your captured evidence into a clearer, stronger dispute workflow."
                ),
                (
                    "Full renter protection access",
                    "Unlock premium tools across your rental timeline."
                )
            ]
        case .unlimitedExports:
            return [
                (
                    "Unlimited move-in exports",
                    "Keep generating fresh baseline reports as your documentation grows."
                ),
                (
                    "Move-out exports included",
                    "Export before-and-after records when deposit disputes are most likely."
                ),
                (
                    "Case builder included",
                    "Use exports and captured proof together in a stronger dispute flow."
                ),
                (
                    "More than one vault",
                    "Upgrade once and keep protection across multiple rentals."
                )
            ]
        case .disputePacket:
            return [
                (
                    "Case builder included",
                    "Organize your proof into a stronger renter defense workflow."
                ),
                (
                    "Unlimited exports",
                    "Generate the reports and supporting files your case may need."
                ),
                (
                    "Move-out protection included",
                    "Use before-and-after proof where deposit disputes usually happen."
                ),
                (
                    "More property coverage",
                    "Keep every rental and evidence trail organized in one account."
                )
            ]
        case .moveOutExport:
            return [
                (
                    "Move-out exports included",
                    "Export your before-and-after proof when deposit risk becomes real."
                ),
                (
                    "Unlimited exports",
                    "Regenerate reports whenever more photos, notes, or documents are added."
                ),
                (
                    "Case builder included",
                    "Use your move-out proof inside a stronger dispute workflow."
                ),
                (
                    "More property vaults",
                    "Keep the same protection system for future rentals too."
                )
            ]
        }
    }

    private func priceCaption(for package: Package, product: StoreProduct) -> String {
        let period = periodLabel(for: package)
        return "\(product.localizedPriceString) / \(period)"
    }

    /// Human period for price line; avoids "$9.99 / plan" when RevenueCat uses custom package types.
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

        let v = sub.value
        switch sub.unit {
        case .day:
            return v == 1 ? "day" : "\(v) days"
        case .week:
            return v == 1 ? "week" : "\(v) weeks"
        case .month:
            return v == 1 ? "month" : "\(v) months"
        case .year:
            return v == 1 ? "year" : "\(v) years"
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
        let raw = error.localizedDescription.lowercased()
        if raw.contains("cancel") {
            return "Purchase cancelled."
        }
        if raw.contains("not configured") || raw.contains("api key") {
            return "Subscriptions unavailable right now. Try again later."
        }
        if raw.contains("network") || raw.contains("offline") || raw.contains("internet") {
            return "No connection. Check your internet and try again."
        }
        return "Purchase didn’t go through. Try again."
    }
}
