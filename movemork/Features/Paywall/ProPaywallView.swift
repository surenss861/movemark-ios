//
//  ProPaywallView.swift
//  movemork
//
//  MoveMark — RevenueCat-backed Pro paywall: a light sheet — what Pro unlocks, App Store prices, one purchase
//  action, restore and legal. StoreKit's own purchase sheet stays native.
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
    @State private var showPurchaseSuccess = false
    @State private var purchaseSuccessWasReportPack = false

    /// Store product IDs — must match RevenueCat package products (App Store: monthly/yearly_subscription; Test Store mirror: testmonthly/testyearly).
    private static let monthlyProductIDs = ["monthly_subscription", "testmonthly"]
    private static let yearlyProductIDs = ["yearly_subscription", "testyearly"]
    private static let reportPackProductIDs = ["report_pack", "movemark_report_pack", "test_report_pack"]

    @Environment(SessionManager.self) private var sessionManager

    init(
        reason: PaywallReason,
        onClose: @escaping () -> Void,
        initialOfferingsFetchCompleted: Bool = false,
        showPurchaseSuccess: Bool = false,
        purchaseSuccessWasReportPack: Bool = false,
        restoreOutcomeMessage: String? = nil,
        localErrorMessage: String? = nil,
        toast: MMProofToastMessage? = nil
    ) {
        self.reason = reason
        self.onClose = onClose
        _initialOfferingsFetchCompleted = State(initialValue: initialOfferingsFetchCompleted)
        _showPurchaseSuccess = State(initialValue: showPurchaseSuccess)
        _purchaseSuccessWasReportPack = State(initialValue: purchaseSuccessWasReportPack)
        _restoreOutcomeMessage = State(initialValue: restoreOutcomeMessage)
        _localErrorMessage = State(initialValue: localErrorMessage)
        _proofToast = State(initialValue: toast)
        _proofToastVisible = State(initialValue: toast != nil)
    }

    var body: some View {
        NavigationStack {
            MMSheetScaffold(title: "MoveMark Pro") {
                header

                benefitsSection
                    .padding(.top, 24)

                if reason.prefersReportPackFirst {
                    reportPackSection
                        .padding(.top, 26)
                }

                plansLoadSection
                    .padding(.top, 26)

                purchaseSection

                restoreAndLegalSection
                    .padding(.top, 14)
            }
            .allowsHitTesting(!showPurchaseSuccess)
            .overlay {
                if showPurchaseSuccess {
                    purchaseSuccessOverlay
                }
            }
            .task {
                initialOfferingsFetchCompleted = false
                MoveMarkAnalytics.track(
                    .paywallViewed,
                    properties: ["reason": String(describing: reason)]
                )
                await subscriptionManager.refresh()
                initialOfferingsFetchCompleted = true
            }
            .mmLightToast(message: proofToast, isVisible: proofToastVisible)
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
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MMInk.text)
                    }
                    .accessibilityLabel("Close")
                    .disabled(subscriptionManager.isStoreKitBusy)
                }
            }
            .interactiveDismissDisabled(subscriptionManager.isStoreKitBusy || showPurchaseSuccess)
        }
    }

    private var purchaseSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MMInk.onLime)
                    .frame(width: 44, height: 44)
                    .background(MMInk.limeMark, in: Circle())

                Text(purchaseSuccessWasReportPack ? "Report Pack unlocked" : "Pro unlocked")
                    .mmFont(17, .semibold)
                    .foregroundStyle(MMInk.text)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(MMInk.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MMInk.cardStroke, lineWidth: 0.75))
        }
        .environment(\.colorScheme, .light)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(purchaseSuccessWasReportPack ? "Report Pack unlocked" : "Pro unlocked")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reason.headline)
                .mmFont(26, .semibold)
                .foregroundStyle(MMInk.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(sharedValueLine)
                .mmFont(15.5)
                .foregroundStyle(MMInk.text.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Text(reason.subheadline)
                .mmFont(14)
                .foregroundStyle(MMInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    private var sharedValueLine: String {
        MoveMarkGrowthCopy.paywallValueLine
    }

    private var benefitsSection: some View {
        MMGroup(title: benefitsTitle, footer: MoveMarkGrowthCopy.paywallSupportLine) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { index, item in
                if index > 0 { MMRowDivider(leading: 52) }
                benefitRow(item.title, item.subtitle)
            }
        }
    }

    private var planGroupTitle: String {
        reason == .reportPack ? "Or choose Pro" : (reason == .moveOutExport ? "Choose your protection plan" : "Choose your plan")
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if paywallPlansUnavailable {
            plansUnavailableRecoveryBlock
                .padding(.top, 14)
        } else {
            if let local = localErrorMessage, !displayPackages.isEmpty {
                MMNotice(message: paywallBannerMessage(local))
                    .padding(.top, 18)
            }

            if let selectedPackage {
                MMPrimaryButton(
                    title: primaryPurchaseButtonTitle(for: selectedPackage),
                    isLoading: subscriptionManager.isStoreKitBusy && !showPurchaseSuccess,
                    isDisabled: subscriptionManager.isStoreKitBusy
                        || subscriptionManager.isRefreshingOfferings
                        || showPurchaseSuccess,
                    action: { startPurchase(selectedPackage) }
                )
                .padding(.top, 20)
            }
        }
    }

    private var restoreAndLegalSection: some View {
        VStack(spacing: 6) {
            paywallRestoreSection

            Text("Auto-renews until cancelled. Manage or cancel in Settings › Apple ID › Subscriptions.")
                .mmFont(12.5)
                .foregroundStyle(MMInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            paywallLegalLinks
                .padding(.top, 4)
        }
    }

    /// Empty catalog after at least one paywall fetch finished — never show silent placeholders.
    private var paywallPlansUnavailable: Bool {
        displayPackages.isEmpty
            && !subscriptionManager.isRefreshingOfferings
            && initialOfferingsFetchCompleted
    }

    private var paywallRestoreSection: some View {
        VStack(spacing: 4) {
            MMSecondaryButton(
                title: subscriptionManager.isStoreKitBusy ? "Restoring purchases…" : "Restore purchases",
                isDisabled: subscriptionManager.isStoreKitBusy,
                action: { restorePurchases() }
            )

            Text("Already subscribed on this Apple ID? Restore before purchasing again.")
                .mmFont(12.5)
                .foregroundStyle(MMInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            if let restoreOutcomeMessage {
                MMNotice(message: restoreOutcomeMessage, tone: .info)
                    .padding(.top, 10)
            }
        }
    }

    private var plansUnavailableTechnicalDetail: String {
        if let local = localErrorMessage, !local.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return paywallBannerMessage(local)
        }
        let server = subscriptionManager.offeringsLoadErrorMessage ?? ""
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
            HStack(spacing: 18) {
                if let u = termsOfUseURL {
                    Button {
                        openURL(u)
                    } label: {
                        Text("Terms of Use").mmFont(13, .medium).foregroundStyle(MMInk.text).underline()
                    }
                    .buttonStyle(.plain)
                }
                if let p = privacyPolicyURL {
                    Button {
                        openURL(p)
                    } label: {
                        Text("Privacy Policy").mmFont(13, .medium).foregroundStyle(MMInk.text).underline()
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Legal")
        }
    }

    private var plansUnavailableRecoveryBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            MMPanel {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MMInk.warning)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plans didn’t load")
                            .mmFont(16, .semibold)
                            .foregroundStyle(MMInk.text)
                        Text("Try again in a minute. You can keep using Free for now.")
                            .mmFont(14)
                            .foregroundStyle(MMInk.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        #if DEBUG
                        Text(plansUnavailableTechnicalDetail)
                            .mmFont(12)
                            .foregroundStyle(MMInk.secondary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                        #endif
                    }
                }
                .accessibilityElement(children: .combine)
            }

            MMPrimaryButton(
                title: subscriptionManager.isRefreshingOfferings
                    ? "Trying…"
                    : MMNextBestActionMapper.paywallPlansUnavailable().title,
                isLoading: subscriptionManager.isRefreshingOfferings,
                isDisabled: subscriptionManager.isRefreshingOfferings || subscriptionManager.isStoreKitBusy,
                action: {
                    localErrorMessage = nil
                    restoreOutcomeMessage = nil
                    Task { @MainActor in
                        await subscriptionManager.refresh()
                    }
                }
            )
            .padding(.top, 18)

            MMSecondaryButton(
                title: "Continue on Free",
                isDisabled: subscriptionManager.isStoreKitBusy,
                action: { onClose() }
            )
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var plansLoadSection: some View {
        if !displayPackages.isEmpty {
            MMGroup(
                title: planGroupTitle,
                footer: "MoveMark Pro is an auto-renewing subscription (monthly or annual). Prices come from the App Store. Apple processes payment and renewal."
            ) {
                ForEach(Array(displayPackages.enumerated()), id: \.element.identifier) { index, package in
                    if index > 0 { MMRowDivider() }
                    pricingOption(package)
                }
            }
        } else if subscriptionManager.isRefreshingOfferings || !initialOfferingsFetchCompleted {
            MMGroup(title: planGroupTitle) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small).tint(MMInk.secondary)
                        Text("Loading plans…").mmFont(16).foregroundStyle(MMInk.text)
                    }
                    Text("Fetching prices from the App Store. This usually takes a few seconds.")
                        .mmFont(13)
                        .foregroundStyle(MMInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        } else {
            EmptyView()
        }
    }

    private func paywallBannerMessage(_ raw: String) -> String {
        SubscriptionManager.sanitizedPlansErrorMessage(raw)
    }

    private func primaryPurchaseButtonTitle(for package: Package) -> String {
        if showPurchaseSuccess {
            return purchaseSuccessWasReportPack ? "Report Pack unlocked" : "Pro unlocked"
        }
        if subscriptionManager.isStoreKitBusy { return "Starting…" }
        return continuePurchaseTitle(for: package)
    }

    private func continuePurchaseTitle(for package: Package) -> String {
        switch planKind(for: package) {
        case .monthly:
            return "Start Pro — Monthly"
        case .yearly:
            return "Start Pro — Yearly"
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
        let proOnly = raw.filter { !Self.isReportPackProduct($0.storeProduct.productIdentifier) }
        return Self.sortedPackagesForDisplay(proOnly)
    }

    private var reportPackPackages: [Package] {
        let raw = subscriptionManager.currentOffering?.availablePackages ?? []
        return raw.filter { Self.isReportPackProduct($0.storeProduct.productIdentifier) }
    }

    private static func isReportPackProduct(_ productID: String) -> Bool {
        reportPackProductIDs.contains(productID)
            || productID.localizedCaseInsensitiveContains("report_pack")
    }

    @ViewBuilder
    private var reportPackSection: some View {
        MMGroup(title: "Need one report only?", footer: "Report Pack unlocks one extra polished move-in PDF — ideal for a single rental moment. Move-out exports stay on Pro.") {
            if let pack = reportPackPackages.first {
                MMRow(
                    title: "Buy Report Pack",
                    subtitle: "One-time purchase, no subscription",
                    icon: "doc.text",
                    value: pack.storeProduct.localizedPriceString,
                    isDisabled: subscriptionManager.isStoreKitBusy || showPurchaseSuccess,
                    action: { startPurchase(pack, isReportPack: true) }
                )
            } else {
                #if DEBUG
                MMRow(
                    title: "Report Pack unavailable",
                    subtitle: "Add product IDs report_pack / movemark_report_pack in RevenueCat to enable one-time purchase here. Pro still unlocks unlimited reports.",
                    icon: "doc.text",
                    accessory: .none
                )
                #else
                MMRow(
                    title: "Report Pack isn’t available right now",
                    subtitle: "Pro still unlocks unlimited reports.",
                    icon: "doc.text",
                    accessory: .none
                )
                #endif
            }
        }
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
        return Button {
            selectedPackageID = package.identifier
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(isSelected ? MMInk.text : MMInk.secondary.opacity(0.55))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(planDisplayTitle(for: package))
                            .mmFont(16, .semibold)
                            .foregroundStyle(MMInk.text)
                        Spacer(minLength: 8)
                        Text(priceCaption(for: package, product: product))
                            .mmFont(15, .medium)
                            .foregroundStyle(MMInk.text)
                            .monospacedDigit()
                            .layoutPriority(1)
                    }

                    if let storeTitle = storeProductListingTitle(for: package, product: product) {
                        Text(storeTitle)
                            .mmFont(13)
                            .foregroundStyle(MMInk.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(planSubtitle(for: package))
                        .mmFont(13)
                        .foregroundStyle(MMInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MMLightPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "MoveMark Pro, \(planDisplayTitle(for: package)), \(priceCaption(for: package, product: product))"
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
        MMRow(title: title, subtitle: subtitle, icon: "checkmark", accessory: .none)
    }

    private var benefitsTitle: String {
        "What Pro unlocks"
    }

    private var benefits: [(title: String, subtitle: String)] {
        MoveMarkGrowthCopy.paywallBenefits + [
            ("Export history", "Reports and packets in one place."),
        ]
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

    private func startPurchase(_ package: Package, isReportPack: Bool = false) {
        guard !subscriptionManager.isStoreKitBusy, !showPurchaseSuccess else { return }

        localErrorMessage = nil
        restoreOutcomeMessage = nil
        MoveMarkAnalytics.track(
            .purchaseStarted,
            properties: [
                "product": package.storeProduct.productIdentifier,
                "report_pack": isReportPack ? "1" : "0",
            ]
        )

        Task { @MainActor in
            let completed = await subscriptionManager.purchase(package: package)
            guard completed else {
                if let message = subscriptionManager.lastPurchaseErrorMessage {
                    localErrorMessage = paywallBannerMessage(message)
                }
                return
            }

            if isReportPack || Self.isReportPackProduct(package.storeProduct.productIdentifier) {
                if let userId = sessionManager.userId {
                    subscriptionManager.addReportPackCredit(forUser: userId)
                }
                MoveMarkAnalytics.track(.purchaseCompleted, properties: ["product": "report_pack"])
                await completePurchaseSuccess(isReportPack: true)
                return
            }

            guard subscriptionManager.hasPro else {
                localErrorMessage = "Purchase finished, but Pro isn’t active yet. Try Restore purchases."
                return
            }

            MoveMarkAnalytics.track(.purchaseCompleted, properties: ["product": "pro"])
            await completePurchaseSuccess(isReportPack: false)
        }
    }

    private func restorePurchases() {
        guard !subscriptionManager.isStoreKitBusy, !showPurchaseSuccess else { return }

        localErrorMessage = nil
        restoreOutcomeMessage = nil

        Task { @MainActor in
            let restored = await subscriptionManager.restorePurchases(forUser: sessionManager.userId)
            if restored, subscriptionManager.hasPro {
                await completePurchaseSuccess(isReportPack: false)
            } else if restored, subscriptionManager.reportPackCredits(forUser: sessionManager.userId) > 0 {
                await completePurchaseSuccess(isReportPack: true)
            } else if let err = subscriptionManager.lastRestoreErrorMessage {
                restoreOutcomeMessage = err
            } else {
                restoreOutcomeMessage = "No active subscription or Report Pack was found for this Apple ID."
            }
        }
    }

    @MainActor
    private func completePurchaseSuccess(isReportPack: Bool = false) async {
        purchaseSuccessWasReportPack = isReportPack
        withAnimation(.easeOut(duration: 0.22)) {
            showPurchaseSuccess = true
        }
        MMHaptics.success()
        try? await Task.sleep(for: .milliseconds(750))
        onClose()
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
